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

        // A low fundamental needs a longer analysis window to separate its
        // partials. 4096 samples covered only ~4 cycles at 45 Hz, which made
        // ordinary harmonics look like independent peaks.
        let requiredSamples = Int((sampleRate / max(primaryFrequency, 1)) * 12)
        let analysisCount = min(samples.count, max(4_096, requiredSamples))
        let analysisSamples = Array(samples.prefix(analysisCount))
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
        // A fixed 10 Hz grid is too coarse for bass notes: at 55 Hz it is a
        // 6% step, which quantises a real B1 onto a G1 harmonic. Scale the step
        // with the fundamental so low notes get the resolution they need.
        let step = max(2.0, min(10.0, primaryFrequency * 0.02))
        let candidateFrequencies: [Double] = stride(
            from: lowerBound,
            through: max(lowerBound, upperBound),
            by: step
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
                let lower = amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: candidate - step)
                let upper = amplitude(samples: analysisSamples, sampleRate: sampleRate, frequency: candidate + step)
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
        // Low strings leak a lot of energy between harmonics; require a much
        // stronger competing peak there before calling it a second note.
        let baseRatio = profile.multiPitchRatio
        let requiredRatio: Double
        if primaryFrequency < 90 {
            requiredRatio = min(0.85, baseRatio + 0.35)
        } else if primaryFrequency < 120 {
            requiredRatio = min(0.80, baseRatio + 0.25)
        } else if primaryFrequency < 200 {
            requiredRatio = min(0.70, baseRatio + 0.12)
        } else {
            requiredRatio = baseRatio
        }
        // A single stray partial has no harmonic series of its own. A real
        // second note does, so require the candidate to be supported by its own
        // second partial before reporting two notes.
        let supportedCandidate = peaks.first { candidate in
            candidate.1 > fundamentalMagnitude * requiredRatio
                && candidate.1 > 0.02
                && hasHarmonicSupport(
                    samples: analysisSamples,
                    sampleRate: sampleRate,
                    frequency: candidate.0,
                    magnitude: candidate.1
                )
        }

        guard supportedCandidate != nil,
              let secondStrongest = supportedCandidate,
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

    /// Whether a peak is the fundamental of a distinct note rather than a lone
    /// partial. Checked by looking for the peak's own second or third partial.
    private static func hasHarmonicSupport(
        samples: [Float],
        sampleRate: Double,
        frequency: Double,
        magnitude: Double
    ) -> Bool {
        for multiple in [2.0, 3.0] {
            let target = frequency * multiple
            guard target < sampleRate / 2 else { break }
            var best = 0.0
            // Allow for stretched tuning by scanning a small ratio band.
            for offset in stride(from: -0.03, through: 0.03, by: 0.01) {
                best = max(best, amplitude(
                    samples: samples,
                    sampleRate: sampleRate,
                    frequency: target * (1 + offset)
                ))
            }
            if best >= magnitude * 0.25 {
                return true
            }
        }
        return false
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
