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
    public let targetSampleRate: Double

    public init(
        minFrequency: Double = 27.5,
        maxFrequency: Double = 4200,
        threshold: Double = 0.15,
        targetSampleRate: Double = 11_025
    ) {
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.threshold = threshold
        self.targetSampleRate = targetSampleRate
    }

    public func detect(samples: [Float], sampleRate: Double) -> PitchEstimate {
        guard samples.count >= 256, sampleRate > 0, targetSampleRate > 0 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: 0)
        }

        let decimationFactor = max(1, Int(floor(sampleRate / targetSampleRate)))
        let effectiveSampleRate = sampleRate / Double(decimationFactor)
        let reduced = decimate(samples, factor: decimationFactor)
        guard reduced.count >= 256 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: 0)
        }

        let mean = reduced.reduce(0.0, +) / Double(reduced.count)
        var centered = [Double](repeating: 0, count: reduced.count)
        var sumSquares = 0.0
        for index in reduced.indices {
            let value = reduced[index] - mean
            centered[index] = value
            sumSquares += value * value
        }

        let rms = sqrt(sumSquares / Double(reduced.count))
        guard rms >= 0.0005 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let tauMin = max(2, Int(floor(effectiveSampleRate / maxFrequency)))
        var tauMax = min(
            centered.count / 2,
            Int(ceil(effectiveSampleRate / minFrequency))
        )
        guard tauMax > tauMin + 2 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        var windowLength = centered.count - tauMax
        if windowLength <= tauMax {
            tauMax = max(tauMin + 2, centered.count / 3)
            windowLength = centered.count - tauMax
        }
        guard windowLength > tauMax else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        var difference = [Double](repeating: 0, count: tauMax + 1)
        for tau in 1...tauMax {
            var sum = 0.0
            for index in 0..<windowLength {
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
        if tauMax >= tauMin + 2 {
            for tau in max(tauMin + 1, 2)...(tauMax - 1) {
                let isLocalMinimum = normalized[tau] <= normalized[tau - 1]
                    && normalized[tau] <= normalized[tau + 1]
                if isLocalMinimum && normalized[tau] < threshold {
                    candidate = tau
                    break
                }
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

        guard let tau = candidate, tau > tauMin, tau < tauMax else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
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

        guard refinedTau > 0 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let frequency = effectiveSampleRate / refinedTau
        guard frequency.isFinite,
              frequency >= minFrequency * 0.95,
              frequency <= maxFrequency * 1.05 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let confidence = max(0, min(1, 1 - y1))
        return PitchEstimate(frequency: frequency, confidence: confidence, rms: rms)
    }

    private func decimate(_ samples: [Float], factor: Int) -> [Double] {
        guard factor > 1 else {
            return samples.map(Double.init)
        }

        let outputCount = samples.count / factor
        var output = [Double](repeating: 0, count: outputCount)
        for outputIndex in 0..<outputCount {
            let start = outputIndex * factor
            var sum = 0.0
            for offset in 0..<factor {
                sum += Double(samples[start + offset])
            }
            output[outputIndex] = sum / Double(factor)
        }
        return output
    }
}