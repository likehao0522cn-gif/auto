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
        rms: Double,
        isPitchSteady: Bool = true,
        profile: DetectionProfile = DetectionProfile.profile(for: .chromatic)
    ) -> MultiplePitchEstimate {
        // Real instruments (erhu, low piano strings) have unstable partials and
        // beat effects. Calling those "multiple notes" is a false positive, so
        // only look for a second pitch once the primary reading is steady.
        guard isPitchSteady,
              let primaryFrequency,
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
        // 10 Hz instead of 20 Hz so a peak is not missed or shifted when a
        // partial sits between grid points.
        // Search a band around the fundamental. A real second note is usually
        // within a few octaves; scanning to 2 kHz let distant partials win.
        let lowerBound = max(55.0, primaryFrequency * 0.5)
        let upperBound = min(2_000.0, primaryFrequency * 4.0)
        let candidateFrequencies: [Double] = stride(
            from: lowerBound,
            through: max(lowerBound, upperBound),
            by: 10.0
        ).map { $0 }
        let independentCandidates: [Double] = candidateFrequencies.filter { (candidate: Double) -> Bool in
            let harmonicRatio = candidate / primaryFrequency
            if harmonicRatio >= 0.95 && harmonicRatio <= 1.05 {
                return false
            }
            // Exclude true sub-harmonics (about 1/2 or 1/3). A blanket
            // "<= 0.75" filter also removed a real lower note whenever YIN
            // happened to lock onto the higher of two notes, which is exactly
            // the two-note case the app is supposed to report.
            if harmonicRatio < 0.85 {
                var nearestSub = 0.5
                if abs(harmonicRatio - 1.0 / 3.0) < abs(harmonicRatio - 0.5) {
                    nearestSub = 1.0 / 3.0
                }
                if abs(harmonicRatio - nearestSub) < 0.08 {
                    return false
                }
            }
            let nearestHarmonic = (1...8).map { Double($0) }.min {
                abs(harmonicRatio - $0) < abs(harmonicRatio - $1)
            } ?? 2
            return abs(harmonicRatio - nearestHarmonic) > 0.10
        }
        let peaks = independentCandidates
            .filter { candidate -> Bool in
                let value = amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: candidate)
                let lower = amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: candidate - 10)
                let upper = amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: candidate + 10)
                return value > lower && value > upper
            }
            .map { frequency in
                (frequency, amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: frequency))
            }
        let secondStrongest = peaks.max { $0.1 < $1.1 }

        // Measured on synthetic piano/guitar-like signals: one struck note
        // leaves non-harmonic peaks under 5% of the fundamental, while two
        // genuine simultaneous notes exceed 45%. 30% sits safely between.
        // The family profile sets the base bar; very low notes get an extra
        // margin because their partials are densely packed.
        let baseRatio = profile.multiPitchRatio
        let requiredRatio = primaryFrequency < 120
            ? min(0.75, baseRatio + 0.20)
            : baseRatio
        guard let secondStrongest,
              secondStrongest.1 > fundamentalMagnitude * requiredRatio,
              secondStrongest.1 > 0.02 else {
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
