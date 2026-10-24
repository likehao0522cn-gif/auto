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

    public init(
        minFrequency: Double = 27.5,
        maxFrequency: Double = 4200,
        threshold: Double = 0.15
    ) {
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.threshold = threshold
    }

    public func detect(samples: [Float], sampleRate: Double) -> PitchEstimate {
        guard samples.count >= 256, sampleRate > 0 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: 0)
        }

        let mono = downmix(samples)
        let centered = centeredSamples(mono)
        let rms = rootMeanSquare(centered)
        guard rms >= 0.0005 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let candidates = [
            detectBand(
                centered: centered,
                sampleRate: sampleRate,
                minFrequency: max(minFrequency, 630),
                maxFrequency: maxFrequency,
                sampleStep: 4,
                minimumWindow: 512
            ),
            detectBand(
                centered: centered,
                sampleRate: sampleRate,
                minFrequency: max(minFrequency, 55),
                maxFrequency: min(maxFrequency, 1300),
                sampleStep: 2,
                minimumWindow: 512
            ),
            detectBand(
                centered: centered,
                sampleRate: sampleRate,
                minFrequency: minFrequency,
                maxFrequency: min(maxFrequency, 700),
                sampleStep: 4,
                minimumWindow: 1_024
            )
        ].compactMap { $0 }

        guard let best = candidates.max(by: { $0.confidence < $1.confidence }) else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        return PitchEstimate(frequency: best.frequency, confidence: best.confidence, rms: rms)
    }

    private struct Candidate {
        let frequency: Double
        let confidence: Double
    }

    private func detectBand(
        centered: [Double],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double,
        sampleStep: Int,
        minimumWindow: Int
    ) -> Candidate? {
        guard sampleRate > 0, minFrequency > 0, maxFrequency > minFrequency else {
            return nil
        }

        let tauMin = max(2, Int(floor(sampleRate / maxFrequency)))
        let tauMax = min(
            centered.count / 2,
            Int(ceil(sampleRate / minFrequency))
        )
        guard tauMax > tauMin + 2 else { return nil }

        let availableWindow = centered.count - tauMax
        guard availableWindow > tauMax else { return nil }
        let windowLength = min(availableWindow, max(minimumWindow, tauMax * 3))
        guard windowLength > 0 else { return nil }

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
        for tau in max(tauMin + 1, 2)...(tauMax - 1) {
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
            guard bestValue < 0.35 else { return nil }
            candidate = min(bestTau, tauMax - 1)
        }

        guard let tau = candidate, tau > tauMin, tau < tauMax else {
            return nil
        }

        let y0 = normalized[tau - 1]
        let y1 = normalized[tau]
        let y2 = normalized[tau + 1]
        let denominator = 2 * (y0 - 2 * y1 + y2)
        var refinedTau = Double(tau)
        if abs(denominator) > 1e-12 {
            let offset = (y0 - y2) / denominator
            refinedTau += max(-1, min(1, offset))
        }
        guard refinedTau > 0 else { return nil }

        let frequency = sampleRate / refinedTau
        guard frequency.isFinite,
              frequency >= minFrequency * 0.95,
              frequency <= maxFrequency * 1.05 else {
            return nil
        }

        return Candidate(
            frequency: frequency,
            confidence: max(0, min(1, 1 - y1))
        )
    }

    private func downmix(_ samples: [Float]) -> [Double] {
        samples.map(Double.init)
    }

    private func centeredSamples(_ samples: [Double]) -> [Double] {
        guard !samples.isEmpty else { return [] }
        var mean = 0.0
        for value in samples {
            mean += value
        }
        mean /= Double(samples.count)
        return samples.map { $0 - mean }
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