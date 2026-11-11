import Foundation

/// Overpull: how far past the target a string should be pulled during a pitch
/// raise, so that it settles back onto the target instead of landing flat.
///
/// When a piano is raised toward pitch, the added tension is shared by the
/// plate, the soundboard and the bridges. The structure gives a little, so a
/// string pulled exactly to its target ends up slightly flat once the rest of
/// the piano has caught up. Pulling past the target by a fraction of the
/// remaining error compensates for that. The fraction is larger in the bass,
/// where the strings and soundboard deflect more, and smaller in the treble.
///
/// The model is deliberately conservative and bounded. Over-pulling a string
/// too far is worse than under-pulling it, because it stresses the string and
/// forces a second correction.
public enum Overpull {

    /// The lowest and highest keys this model is intended for.
    public static let lowestMIDI = 21
    public static let highestMIDI = 108

    /// Fraction of the remaining flatness that is added as overpull at the
    /// bottom of the keyboard. Wound bass strings move the soundboard the
    /// most, so they get the largest compensation.
    public static let bassFraction: Double = 0.45

    /// Fraction of the remaining flatness added as overpull at the top of the
    /// keyboard. Short treble strings barely move the structure, so the
    /// compensation is small.
    public static let trebleFraction: Double = 0.12

    /// Hard cap on overpull in the bass, in cents. This keeps a large pitch
    /// raise from putting excessive tension on the lowest strings.
    public static let bassMaximumCents: Double = 6.0

    /// Hard cap on overpull in the treble, in cents.
    public static let trebleMaximumCents: Double = 2.5

    /// How much of the remaining flatness to compensate for at a key, blended
    /// linearly from the bass fraction to the treble fraction.
    public static func fraction(forKey key: Int) -> Double {
        let t = normalizedPosition(forKey: key)
        return bassFraction * (1 - t) + trebleFraction * t
    }

    /// The most overpull allowed at a key, in cents.
    public static func maximumCents(forKey key: Int) -> Double {
        let t = normalizedPosition(forKey: key)
        return bassMaximumCents * (1 - t) + trebleMaximumCents * t
    }

    /// Overpull for one key, in cents.
    ///
    /// - Parameters:
    ///   - key: the MIDI note being tuned.
    ///   - flatCents: how far flat the string is right now, in cents. A value
    ///     at or below zero means the string is not flat, so no overpull is
    ///     applied; a pitch drop is never pre-compensated by pulling down.
    /// - Returns: cents to add beyond the target, between 0 and the key's cap.
    public static func cents(forKey key: Int, flatCents: Double) -> Double {
        guard flatCents > 0, flatCents.isFinite else { return 0 }
        let raw = flatCents * fraction(forKey: key)
        return min(raw, maximumCents(forKey: key))
    }

    /// The frequency to aim for while tuning: the stretched target plus the
    /// overpull, expressed as a frequency.
    ///
    /// - Parameters:
    ///   - key: the MIDI note being tuned.
    ///   - stretchedTarget: the curve-adjusted target frequency in Hz.
    ///   - flatCents: how far flat the string is right now, in cents.
    public static func targetFrequency(
        forKey key: Int,
        stretchedTarget: Double,
        flatCents: Double
    ) -> Double {
        guard stretchedTarget > 0 else { return 0 }
        let pull = cents(forKey: key, flatCents: flatCents)
        return stretchedTarget * pow(2, pull / 1200)
    }

    /// Position of a key on the keyboard, 0 at the lowest key and 1 at the
    /// highest. Keys outside the range are clamped to the ends.
    private static func normalizedPosition(forKey key: Int) -> Double {
        let clamped = min(highestMIDI, max(lowestMIDI, key))
        let span = Double(highestMIDI - lowestMIDI)
        guard span > 0 else { return 0 }
        return Double(clamped - lowestMIDI) / span
    }
}
