import Foundation

/// A rough default inharmonicity model, used as the reference that measured
/// values are compared against.
///
/// Real piano strings get shorter, thinner and relatively stiffer from the bass
/// to the treble, so B falls by about two orders of magnitude across the
/// keyboard. This model is anchored at A4 and decays exponentially in both
/// directions, with a steeper slope in the bass because wound bass strings are
/// the most inharmonic:
///
///     B(k) = B0 * exp(-slope * (k - 69))
///
/// where the slope differs below and above A4.
///
/// The constants are a calculated starting point, not measured values. They are
/// chosen so the reference sits at a typical upright's order of magnitude. They
/// should be calibrated against real instruments before being relied on for
/// anything more precise than a starting curve.
public enum PianoInharmonicityModel {
    /// Reference inharmonicity at A4.
    public static let bAtA4: Double = 1.2e-4
    /// Decay per semitone below A4 (bass side).
    public static let bassSlope: Double = 0.018
    /// Decay per semitone above A4 (treble side).
    public static let trebleSlope: Double = 0.012
    /// The key the model is anchored at.
    public static let referenceMIDI = 69

    /// Reference B for a key.
    public static func b(forMIDI midi: Int) -> Double {
        let delta = Double(midi - referenceMIDI)
        let slope = delta < 0 ? bassSlope : trebleSlope
        let value = bAtA4 * exp(-slope * delta)
        return min(0.05, max(1e-7, value))
    }
}
