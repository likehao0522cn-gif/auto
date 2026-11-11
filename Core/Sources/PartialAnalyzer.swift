import Foundation

/// Finds the individual partials of a single plucked or struck string inside a
/// recorded buffer, then turns them into an inharmonicity estimate.
///
/// A full FFT is overkill here: we already know roughly where each partial
/// should be, so a Goertzel evaluation at a small set of nearby frequencies
/// (a local scan plus a parabolic refine) is both cheaper and more accurate.
/// Scanning in log-frequency means the search is equally fine in cents at every
/// partial, which is what matters for pitch work.
public enum PartialAnalyzer {

    /// Frequencies of the first few partials of a string, in Hz, plus how
    /// strong each one was. An empty list means nothing usable was found.
    public struct Result: Equatable, Sendable {
        public let partials: [Double]
        public let strengths: [Double]
        public init(partials: [Double], strengths: [Double]) {
            self.partials = partials
            self.strengths = strengths
        }
    }

    /// How many partials to look for. Enough for a robust coefficient without
    /// chasing weak, noisy upper partials.
    public static let maximumPartial = 4

    /// Search window around each expected partial, in cents. Generous enough
    /// to cover a mistuned string but tight enough not to jump to a neighbour.
    public static let searchWindowCents: Double = 80

    /// Number of steps in the coarse scan. 161 steps over ±80 cents is about
    /// one step per cent.
    public static let scanSteps: Int = 160

    /// Measures the partials of a string whose fundamental is near `expectedF1`.
    /// `b` is an initial guess for the inharmonicity, used only to place the
    /// search windows for the upper partials.
    public static func measure(
        samples: [Float],
        sampleRate: Double,
        expectedF1: Double,
        initialB: Double = 0
    ) -> Result {
        guard samples.count >= 512, sampleRate > 0, expectedF1 > 0 else {
            return Result(partials: [], strengths: [])
        }

        let centered = centered(samples)
        let maxFrequency = sampleRate / 2
        var partials: [Double] = []
        var strengths: [Double] = []

        for n in 1...maximumPartial {
            let guess: Double
            if n == 1 {
                guess = expectedF1
            } else {
                guess = Inharmonicity.partialFrequency(fundamental: expectedF1, partial: n, b: max(0, initialB))
            }
            guard guess > 0, guess * 2 < maxFrequency else { break }

            let coarse = scan(centered, sampleRate: sampleRate, around: guess)
            guard coarse.strength > 0 else { break }
            let refined = refine(centered, sampleRate: sampleRate, at: coarse.frequency)
            partials.append(refined)
            strengths.append(coarse.strength)
        }

        return Result(partials: partials, strengths: strengths)
    }

    /// Local log-frequency scan for the strongest component near a guess.
    static func scan(
        _ samples: [Double],
        sampleRate: Double,
        around guess: Double
    ) -> (frequency: Double, strength: Double) {
        var bestFrequency = guess
        var bestStrength = -Double.infinity
        let span = searchWindowCents
        let steps = max(1, scanSteps)
        for index in 0...steps {
            let cents = -span + 2 * span * Double(index) / Double(steps)
            let frequency = guess * pow(2, cents / 1200)
            let strength = goertzel(samples, sampleRate: sampleRate, frequency: frequency)
            if strength > bestStrength {
                bestStrength = strength
                bestFrequency = frequency
            }
        }
        return (bestFrequency, bestStrength)
    }

    /// Parabolic refine around a peak, in log-frequency, for sub-cent accuracy.
    static func refine(
        _ samples: [Double],
        sampleRate: Double,
        at frequency: Double
    ) -> Double {
        let stepCents = 2.0
        let lower = frequency * pow(2, -stepCents / 1200)
        let center = frequency
        let upper = frequency * pow(2, stepCents / 1200)
        let y1 = goertzel(samples, sampleRate: sampleRate, frequency: lower)
        let y2 = goertzel(samples, sampleRate: sampleRate, frequency: center)
        let y3 = goertzel(samples, sampleRate: sampleRate, frequency: upper)
        let denominator = y1 - 2 * y2 + y3
        guard abs(denominator) > 1e-12 else { return frequency }
        let offset = 0.5 * (y1 - y3) / denominator
        return frequency * pow(2, offset * stepCents / 1200)
    }

    /// Goertzel magnitude at a single frequency. Cheap: one multiply-add per
    /// sample and no FFT buffer.
    static func goertzel(_ samples: [Double], sampleRate: Double, frequency: Double) -> Double {
        let n = samples.count
        guard n > 0, sampleRate > 0, frequency > 0 else { return 0 }
        let omega = 2 * Double.pi * frequency / sampleRate
        let coefficient = 2 * cos(omega)
        var s1 = 0.0
        var s2 = 0.0
        for sample in samples {
            let s0 = sample + coefficient * s1 - s2
            s2 = s1
            s1 = s0
        }
        let power = s1 * s1 + s2 * s2 - coefficient * s1 * s2
        return power > 0 ? power.squareRoot() / Double(n) : 0
    }

    /// Removes the DC offset and applies a Hann window.
    ///
    /// The window matters more than it looks. A plain rectangular window leaks
    /// energy between neighbouring bins, which biases every peak by a fraction
    /// of a cent toward lower frequency. The coefficient is so sensitive to a
    /// partial's frequency that even that small bias inflated B by 30 to 100
    /// percent in testing. With a Hann window the same measurements land within
    /// about one percent of the true value.
    private static func centered(_ samples: [Float]) -> [Double] {
        guard !samples.isEmpty else { return [] }
        var mean = 0.0
        for value in samples { mean += Double(value) }
        mean /= Double(samples.count)

        let count = samples.count
        var windowed = [Double](repeating: 0, count: count)
        let denominator = Double(max(1, count - 1))
        for index in 0..<count {
            let hann = 0.5 - 0.5 * cos(2 * Double.pi * Double(index) / denominator)
            windowed[index] = (Double(samples[index]) - mean) * hann
        }
        return windowed
    }
}
