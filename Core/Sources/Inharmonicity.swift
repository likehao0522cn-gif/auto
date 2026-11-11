import Foundation

/// Result of measuring the inharmonicity coefficient B for a single piano
/// string (one key). The coefficient describes how far the string's partials
/// deviate from exact integer multiples because of string stiffness:
///
///     f_n = f1 * n * sqrt((1 + B * n^2) / (1 + B))
///
/// A larger B means a stiffer, shorter, thicker string (the bass). The value
/// is dimensionless and typically between 1e-5 (treble) and 1e-3 (deep bass).
public struct InharmonicityMeasurement: Equatable, Codable, Sendable {
    /// MIDI note number of the key this measurement belongs to.
    public let midi: Int
    /// The inharmonicity coefficient B.
    public let b: Double
    /// How confident the measurement is, 0...1. Low values come from weak or
    /// unclear partial peaks and should not be trusted.
    public let confidence: Double
    /// Frequencies of the partials that were actually observed, in Hz, starting
    /// with the fundamental. Kept for diagnostics and re-derivation.
    public let partials: [Double]

    public init(midi: Int, b: Double, confidence: Double, partials: [Double]) {
        self.midi = midi
        self.b = b
        self.confidence = confidence
        self.partials = partials
    }
}

/// Pure functions for inharmonicity. Kept free of UI and audio so it can be
/// unit tested on any platform.
public enum Inharmonicity {

    /// The frequency of the n-th partial of a string with fundamental f1 and
    /// inharmonicity B:
    ///
    ///     f_n = f1 * n * sqrt((1 + B * n^2) / (1 + B))
    ///
    /// With B = 0 this reduces to f1 * n (the ideal harmonic series).
    public static func partialFrequency(
        fundamental f1: Double,
        partial n: Int,
        b: Double
    ) -> Double {
        guard f1 > 0, n > 0, b >= 0 else { return 0 }
        let n2 = Double(n) * Double(n)
        return f1 * Double(n) * ((1 + b * n2) / (1 + b)).squareRoot()
    }

    /// Inverse of `partialFrequency`: which (fractional) partial number a given
    /// frequency corresponds to, for a string with fundamental f1 and
    /// inharmonicity B. Used to locate a measured peak inside the series.
    public static func partialIndex(
        frequency f: Double,
        fundamental f1: Double,
        b: Double
    ) -> Double {
        guard f > 0, f1 > 0 else { return 0 }
        guard b > 0 else { return f / f1 }
        // Solve B * n^4 + n^2 - x^2 * (1 + B) = 0 for the partial number n,
        // where x = f / f1. Let y = n^2; the positive root is
        //   y = (-1 + sqrt(1 + 4B(1+B)x^2)) / (2B).
        let x = f / f1
        let discriminant = 1 + 4 * b * x * x * (1 + b)
        let y = (-1 + discriminant.squareRoot()) / (2 * b)
        return y > 0 ? y.squareRoot() : 0
    }

    /// Solves B from a measured fundamental and one higher partial. Returns nil
    /// when the inputs cannot produce a sensible positive B (for example a peak
    /// below the harmonic position, which means the peak was misidentified).
    ///
    /// From f_n = f1 * n * sqrt((1 + B n^2)/(1 + B)):
    ///     x = f_n / (n * f1)
    ///     B = (x^2 - 1) / (n^2 - x^2)
    public static func coefficient(
        fundamental f1: Double,
        partialFrequency fn: Double,
        partial n: Int
    ) -> Double? {
        guard f1 > 0, fn > 0, n >= 2 else { return nil }
        let x = fn / (Double(n) * f1)
        let numerator = x * x - 1
        let denominator = Double(n) * Double(n) - x * x
        // The denominator turns negative once the observed partial sits above
        // its ideal position by more than the model allows; that is a sign of a
        // misidentified peak, not a physical string.
        guard denominator > 0, numerator >= 0 else { return nil }
        let b = numerator / denominator
        guard b.isFinite, b >= 0, b < 1 else { return nil }
        return b
    }

    /// Estimates B from the first few partial frequencies of one string.
    ///
    /// Uses every usable pair (fundamental, n-th partial) for n = 2, 3, 4 and
    /// returns a spread-filtered mean. Confidence reflects how many partials
    /// were usable and how tightly the individual estimates agree.
    public static func estimate(
        midi: Int,
        partials: [Double],
        toleranceRatio: Double = 0.5
    ) -> InharmonicityMeasurement? {
        guard partials.count >= 2 else { return nil }
        let f1 = partials[0]
        guard f1 > 0 else { return nil }

        var estimates: [Double] = []
        for n in 2...min(4, partials.count) {
            let fn = partials[n - 1]
            guard fn > 0 else { continue }
            if let b = coefficient(fundamental: f1, partialFrequency: fn, partial: n) {
                estimates.append(b)
            }
        }
        guard !estimates.isEmpty else { return nil }

        let sorted = estimates.sorted()
        let median = sorted[sorted.count / 2]

        // Reject individual estimates that disagree with the median by more
        // than toleranceRatio (relative). This drops a peak that was really a
        // different string's partial or a noise spike.
        let kept = estimates.filter { estimate in
            guard median > 0 else { return true }
            return abs(estimate - median) / median <= toleranceRatio
        }
        let consensus = kept.isEmpty ? estimates : kept

        let mean = consensus.reduce(0, +) / Double(consensus.count)

        // Confidence: more agreeing partials and a tighter spread both help.
        let spread = consensus.count > 1 ? relativeSpread(consensus) : toleranceRatio
        let countScore = min(1.0, Double(consensus.count) / 3.0)
        let spreadScore = max(0.0, 1.0 - spread / toleranceRatio)
        let confidence = min(1.0, max(0.0, 0.5 * countScore + 0.5 * spreadScore))

        return InharmonicityMeasurement(
            midi: midi,
            b: mean,
            confidence: confidence,
            partials: partials
        )
    }

    /// Measures B for one string from recorded audio.
    ///
    /// This is the entry point the tuner uses: it finds the partials first,
    /// then folds them into the same estimator the rest of the code uses. The
    /// confidence combines the estimator's own agreement score with how strong
    /// the upper partials were compared with the fundamental, because a string
    /// whose upper partials are barely above the noise floor cannot give a
    /// trustworthy coefficient.
    public static func measure(
        midi: Int,
        samples: [Float],
        sampleRate: Double,
        expectedF1: Double,
        initialB: Double = 0
    ) -> InharmonicityMeasurement? {
        let analyzed = PartialAnalyzer.measure(
            samples: samples,
            sampleRate: sampleRate,
            expectedF1: expectedF1,
            initialB: initialB
        )
        guard analyzed.partials.count >= 3 else { return nil }
        guard let estimate = estimate(midi: midi, partials: analyzed.partials) else { return nil }

        // Strength of the upper partials relative to the fundamental. A very
        // weak second partial makes B unreliable even when the numbers look
        // self-consistent, so it pulls the confidence down.
        let fundamentalStrength = analyzed.strengths.first ?? 0
        let upperStrengths = analyzed.strengths.dropFirst()
        let strengthRatio: Double
        if fundamentalStrength > 0, let maxUpper = upperStrengths.max() {
            strengthRatio = min(1.0, maxUpper / fundamentalStrength)
        } else {
            strengthRatio = 0
        }
        let confidence = min(1.0, estimate.confidence * (0.5 + 0.5 * strengthRatio))
        return InharmonicityMeasurement(
            midi: midi,
            b: estimate.b,
            confidence: confidence,
            partials: analyzed.partials
        )
    }

    /// (max - min) / mean, for a set of positive values. Zero means perfect
    /// agreement.
    private static func relativeSpread(_ values: [Double]) -> Double {
        guard let min = values.min(), let max = values.max() else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        return (max - min) / mean
    }
}
