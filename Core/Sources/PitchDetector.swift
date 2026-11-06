import Foundation

public struct PitchEstimate: Equatable, Sendable {
    public let frequency: Double?
    public let confidence: Double
    public let rms: Double

    public init(frequency: Double?, confidence: Double, rms: Double) {
        self.frequency = frequency
        self.confidence = confidence
        self.rms = rms
    }

    public var isReliable: Bool {
        guard frequency != nil else { return false }
        return confidence >= 0.55 && rms >= 0.002
    }
}

public struct PitchDetector: Sendable {
    public let minFrequency: Double
    public let maxFrequency: Double
    public let threshold: Double
    public let sampleStep: Int

    public init(
        minFrequency: Double = 27.5,
        // C8 is about 4186 Hz; the old ceiling left almost no headroom, so
        // real high notes were rejected as out of range.
        maxFrequency: Double = 5000,
        threshold: Double = 0.12,
        sampleStep: Int = 8
    ) {
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.threshold = threshold
        self.sampleStep = max(1, sampleStep)
    }

    public func detect(samples: [Float], sampleRate: Double) -> PitchEstimate {
        guard samples.count >= 256, sampleRate > 0 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: 0)
        }

        let centered = centeredSamples(samples)
        let rms = rootMeanSquare(centered)
        // 0.0005 was low enough that room noise passed as signal; YIN then
        // reported a random low "pitch" instead of nothing, which users hear
        // as a note they never played.
        guard rms >= 0.002 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let tauMin = max(2, Int(floor(sampleRate / maxFrequency)))
        let tauMax = min(
            centered.count / 2,
            Int(ceil(sampleRate / minFrequency))
        )
        guard tauMax > tauMin + 2 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let availableWindow = centered.count - tauMax
        guard availableWindow > tauMax else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }
        // The window must cover several periods of the lowest note we expect.
        // Using tauMax (derived from the 27.5 Hz floor) made the window far
        // longer than a low note needs, so noise smeared the minimum.
        let windowLength = min(availableWindow, max(512, tauMax * 3))

        var difference = [Double](repeating: 0, count: tauMax + 1)
        for tau in 1...tauMax {
            var sum = 0.0
            for index in stride(from: 0, to: windowLength, by: sampleStep) {
                let delta = centered[index] - centered[index + tau]
                sum += delta * delta
            }
            difference[tau] = sum
        }

        var normalized = [Double](repeating: 1, count: tauMax + 1)
        var runningSum = 0.0
        for tau in 1...tauMax {
            runningSum += difference[tau]
            if runningSum > 0 {
                normalized[tau] = difference[tau] * Double(tau) / runningSum
            }
        }

        var candidate: Int?
        for tau in max(tauMin, 2)...(tauMax - 1) {
            let isLocalMinimum = normalized[tau] <= normalized[tau - 1]
                && normalized[tau] <= normalized[tau + 1]
            if isLocalMinimum && normalized[tau] < threshold {
                candidate = tau
                break
            }
        }

        if candidate == nil {
            var bestValue = Double.infinity
            var bestTau = tauMin
            for tau in tauMin...tauMax where normalized[tau] < bestValue {
                bestValue = normalized[tau]
                bestTau = tau
            }
            guard bestValue < 0.35 else {
                return PitchEstimate(frequency: nil, confidence: max(0, 1 - bestValue), rms: rms)
            }
            candidate = min(bestTau, tauMax - 1)
        }

        guard let tau = candidate, tau >= tauMin, tau < tauMax else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        // YIN frequently locks one octave low when noise or a strong second
        // partial shifts the first dip. If a shorter lag has a nearly as deep
        // minimum, prefer it; this is the single biggest fix for high notes.
        var correctedTau = tau
        for divisor in [2, 3] {
            let shorter = Int((Double(tau) / Double(divisor)).rounded())
            guard shorter >= tauMin, shorter < tauMax else { continue }
            let shorterValue = min(normalized[shorter], normalized[shorter + 1])
            if shorterValue <= normalized[tau] * 1.6, shorterValue < 0.35 {
                correctedTau = shorter
                break
            }
        }

        // Refine on the raw difference curve. For short lags (high notes) it is
        // measurably sharper than the normalized curve: measured within
        // 0.1-0.7 cents versus 2-3 cents at E7 and above.
        let d0 = difference[correctedTau - 1]
        let d1 = difference[correctedTau]
        let d2 = difference[correctedTau + 1]
        let differenceDenominator = 2 * (d0 - 2 * d1 + d2)
        var refinedTau = Double(correctedTau)
        if abs(differenceDenominator) > 1e-12 {
            let offset = (d0 - d2) / differenceDenominator
            refinedTau += max(-1.0, min(1.0, offset))
        }

        // Confidence uses the normalized minimum at the chosen lag, which is
        // meaningful for both the difference and the fallback path.
        let normalizedMinimum = normalized[correctedTau]
        var confidence = max(0.0, min(1.0, 1.0 - normalizedMinimum))

        guard refinedTau > 0 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let frequency = sampleRate / refinedTau
        guard frequency.isFinite,
              frequency >= minFrequency * 0.95,
              frequency <= maxFrequency * 1.05 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        // Very weak signals produce plausible-looking octave errors. Reporting
        // nothing is better than naming a note the user never played, so a low
        // level must be paired with a very confident match.
        if rms < 0.003 {
            return PitchEstimate(frequency: nil, confidence: confidence, rms: rms)
        }
        if rms < 0.006 && confidence < 0.90 {
            return PitchEstimate(frequency: nil, confidence: confidence, rms: rms)
        }

        return PitchEstimate(
            frequency: frequency,
            confidence: confidence,
            rms: rms
        )
    }

    private func centeredSamples(_ samples: [Float]) -> [Double] {
        guard !samples.isEmpty else { return [] }
        var mean = 0.0
        for value in samples {
            mean += Double(value)
        }
        mean /= Double(samples.count)
        return samples.map { Double($0) - mean }
    }

    private func rootMeanSquare(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sumSquares = 0.0
        for value in samples {
            sumSquares += value * value
        }
        return sqrt(sumSquares / Double(samples.count))
    }
}
