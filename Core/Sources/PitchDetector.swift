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
    public let highFrequencyThreshold: Double

    public init(
        minFrequency: Double = 27.5,
        maxFrequency: Double = 4200,
        threshold: Double = 0.15,
        targetSampleRate: Double = 9_000,
        highFrequencyThreshold: Double = 700
    ) {
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.threshold = threshold
        self.targetSampleRate = targetSampleRate
        self.highFrequencyThreshold = highFrequencyThreshold
    }

    public func detect(samples: [Float], sampleRate: Double) -> PitchEstimate {
        guard samples.count >= 256, sampleRate > 0, targetSampleRate > 0 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: 0)
        }

        let coarseFactor = max(1, Int(floor(sampleRate / targetSampleRate)))
        let coarseRate = sampleRate / Double(coarseFactor)
        let coarseSamples = decimate(samples, factor: coarseFactor)
        guard coarseSamples.count >= 256 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: 0)
        }

        let coarseCentered = centeredSamples(coarseSamples)
        let rms = rootMeanSquare(coarseCentered)
        guard rms >= 0.0005 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let coarseTauMin = max(2, Int(floor(coarseRate / maxFrequency)))
        let coarseTauMax = min(
            coarseCentered.count / 2,
            Int(ceil(coarseRate / minFrequency))
        )
        guard let coarse = estimateFrequency(
            in: coarseCentered,
            sampleRate: coarseRate,
            tauMin: coarseTauMin,
            tauMax: coarseTauMax,
            windowLimit: nil
        ) else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        guard coarse.frequency >= highFrequencyThreshold, coarseFactor > 1 else {
            return PitchEstimate(frequency: coarse.frequency, confidence: coarse.confidence, rms: rms)
        }

        let highFactor = max(1, Int(floor(sampleRate / 32_000)))
        let highRate = sampleRate / Double(highFactor)
        let highSamples = decimate(samples, factor: highFactor)
        let highCentered = centeredSamples(highSamples)
        let highTauMin = max(2, Int(floor(highRate / (maxFrequency * 1.05))))
        let highTauMax = min(
            highCentered.count / 2,
            Int(ceil(highRate / (highFrequencyThreshold * 0.9)))
        )

        if let high = estimateFrequency(
            in: highCentered,
            sampleRate: highRate,
            tauMin: highTauMin,
            tauMax: highTauMax,
            windowLimit: 4_096
        ), high.frequency >= highFrequencyThreshold, high.confidence >= 0.55 {
            return PitchEstimate(frequency: high.frequency, confidence: high.confidence, rms: rms)
        }

        return PitchEstimate(frequency: coarse.frequency, confidence: coarse.confidence, rms: rms)
    }

    private func estimateFrequency(
        in centered: [Double],
        sampleRate: Double,
        tauMin: Int,
        tauMax: Int,
        windowLimit: Int?
    ) -> (frequency: Double, confidence: Double)? {
        guard centered.count >= 128, sampleRate > 0, tauMax > tauMin + 2 else {
            return nil
        }

        let availableWindow = centered.count - tauMax
        guard availableWindow > tauMax else { return nil }
        let windowLength = min(availableWindow, windowLimit ?? availableWindow)

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

        return (frequency, max(0, min(1, 1 - y1)))
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

    private func decimate(_ samples: [Float], factor: Int) -> [Double] {
        guard factor > 1 else {
            return samples.map(Double.init)
        }

        let outputCount = samples.count / factor
        var output = [Double](repeating: 0, count: outputCount)
        let divisor = Double(factor)
        for outputIndex in 0..<outputCount {
            let start = outputIndex * factor
            var sum = 0.0
            for offset in 0..<factor {
                sum += Double(samples[start + offset])
            }
            output[outputIndex] = sum / divisor
        }
        return output
    }
}