import Foundation

public struct MultiplePitchEstimate: Equatable, Sendable {
    public let isMultiplePitches: Bool
    public let strongestFrequency: Double?
    public let strongestConfidence: Double

    public init(
        isMultiplePitches: Bool,
        strongestFrequency: Double?,
        strongestConfidence: Double
    ) {
        self.isMultiplePitches = isMultiplePitches
        self.strongestFrequency = strongestFrequency
        self.strongestConfidence = strongestConfidence
    }
}

public enum MultiplePitchDetector {
    public static func detect(
        samples: [Float],
        sampleRate: Double,
        primaryFrequency: Double?,
        primaryConfidence: Double,
        rms: Double
    ) -> MultiplePitchEstimate {
        guard let primaryFrequency,
              primaryConfidence >= 0.55,
              rms >= 0.002,
              samples.count >= 2_048 else {
            return MultiplePitchEstimate(
                isMultiplePitches: false,
                strongestFrequency: primaryFrequency,
                strongestConfidence: primaryConfidence
            )
        }

        let analysisSamples = Array(samples.prefix(4_096))
        let fundamentalMagnitude = amplitude(
            samples: analysisSamples,
            sampleRate: sampleRate,
            frequency: primaryFrequency
        )
        guard fundamentalMagnitude > 1e-4 else {
            return MultiplePitchEstimate(
                isMultiplePitches: false,
                strongestFrequency: primaryFrequency,
                strongestConfidence: primaryConfidence
            )
        }
        let candidateFrequencies: [Double] = Array(stride(from: 55.0, through: 2_000.0, by: 20.0))
        let independentCandidates: [Double] = candidateFrequencies.filter { (candidate: Double) -> Bool in
                let harmonicRatio = candidate / primaryFrequency
            if harmonicRatio >= 0.95 && harmonicRatio <= 1.05 {
                return false
            }
                let nearestHarmonic = (1...8).map { Double($0) }.min {
                    abs(harmonicRatio - $0) < abs(harmonicRatio - $1)
                } ?? 2
                return abs(harmonicRatio - nearestHarmonic) > 0.06
        }
        let peaks = independentCandidates
            .filter { candidate -> Bool in
                let value = amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: candidate)
                let lower = amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: candidate - 20)
                let upper = amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: candidate + 20)
                return value > lower && value > upper
            }
            .map { frequency in
                (frequency, amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: frequency))
            }
        let secondStrongest = peaks.max { $0.1 < $1.1 }

        guard let secondStrongest,
              secondStrongest.1 > fundamentalMagnitude * 0.5 else {
            return MultiplePitchEstimate(
                isMultiplePitches: false,
                strongestFrequency: primaryFrequency,
                strongestConfidence: primaryConfidence
            )
        }

        return MultiplePitchEstimate(
            isMultiplePitches: true,
            strongestFrequency: primaryFrequency,
            strongestConfidence: primaryConfidence
        )
    }

    private static func amplitude(
        samples: [Float],
        sampleRate: Double,
        frequency: Double
    ) -> Double {
        guard frequency > 0, frequency < sampleRate / 2 else { return 0 }
        let omega = 2 * Double.pi * frequency / sampleRate
        let coefficient = 2 * cos(omega)
        var s0 = 0.0
        var s1 = 0.0
        var s2 = 0.0
        for sample in samples {
            s0 = Double(sample) + coefficient * s1 - s2
            s2 = s1
            s1 = s0
        }
        return 2 * sqrt(max(0, s1 * s1 + s2 * s2 - coefficient * s1 * s2)) / Double(samples.count)
    }
}
