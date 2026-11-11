import Foundation

/// A stretch curve: for each piano key, how many cents above (positive) or
/// below (negative) equal temperament that key should be tuned.
///
/// Equal temperament alone cannot tune a piano well, because string stiffness
/// makes each string's partials run sharp. The standard fix is to tune
/// stretched octaves: the bass ends up flat, the treble sharp, the middle near
/// zero. That is the shape of the well known Railsback curve.
public struct StretchCurve: Equatable, Codable, Sendable {
    /// Deviation from equal temperament in cents, keyed by MIDI note number.
    public let cents: [Int: Double]
    /// Short label describing where the curve came from.
    public let source: String
    /// True when the curve was adjusted with this piano's measured
    /// inharmonicity rather than being a generic template.
    public let isMeasured: Bool

    public init(cents: [Int: Double], source: String, isMeasured: Bool) {
        self.cents = cents
        self.source = source
        self.isMeasured = isMeasured
    }

    public func cents(forMIDI midi: Int) -> Double { cents[midi] ?? 0 }

    public var lowestMIDI: Int? { cents.keys.min() }
    public var highestMIDI: Int? { cents.keys.max() }

    /// The stretch deviation applied to the ideal frequency of a key.
    public func stretchedFrequency(
        forMIDI midi: Int,
        concertA: Double = 440
    ) -> Double {
        let ideal = PitchMath.frequency(forMIDI: Double(midi), concertA: concertA)
        return ideal * pow(2, cents(forMIDI: midi) / 1200)
    }
}

/// Builds stretch curves.
///
/// The tuning philosophy here is deliberately conservative:
///
///  - Without measurements, use the published Railsback average shape.
///  - With measurements, keep that shape but scale it by how this piano's
///    inharmonicity compares to the reference, section by section. A piano with
///    stiffer strings needs more stretch; one with softer strings needs less.
///
/// This reproduces what a professional tuner does in practice. It is also why
/// the curve stays smooth and monotonic instead of following raw partial
/// alignment, which on its own produces far too little stretch in the treble
/// (real tuners stretch the top octaves well beyond the pure 4:2 alignment).
public enum StretchCurveBuilder {

    public static let lowestMIDI = 21
    public static let highestMIDI = 108

    /// Builds a curve from a measured inharmonicity profile. Falls back to the
    /// generic template when there is nothing usable to measure.
    public static func measured(
        profile: InharmonicityProfile,
        name: String? = nil
    ) -> StretchCurve {
        guard !profile.trusted.isEmpty else { return template() }

        let b = profile.filledCoefficients(
            lowestMIDI: lowestMIDI,
            highestMIDI: highestMIDI
        )

        var cents: [Int: Double] = [:]
        for key in lowestMIDI...highestMIDI {
            let base = RailsbackTemplate.cents(forMIDI: key)
            let scale = stiffnessScale(forKey: key, b: b[key] ?? PianoInharmonicityModel.b(forMIDI: key))
            cents[key] = base * scale
        }
        return StretchCurve(
            cents: cents,
            source: name ?? profile.name ?? "实测",
            isMeasured: true
        )
    }

    /// Generic curve used before anything is measured.
    public static func template() -> StretchCurve {
        var cents: [Int: Double] = [:]
        for key in lowestMIDI...highestMIDI {
            cents[key] = RailsbackTemplate.cents(forMIDI: key)
        }
        return StretchCurve(cents: cents, source: "Railsback 通用模板", isMeasured: false)
    }
    /// Curve for a named class of piano, before anything is measured on the
    /// actual instrument. The Railsback shape is kept, but its width is scaled
    /// by how much this class of piano's inharmonicity differs from the
    /// reference, so a small upright gets a wider curve and a grand a narrower
    /// one.
    public static func template(for model: PianoModelTemplate) -> StretchCurve {
        var cents: [Int: Double] = [:]
        for key in lowestMIDI...highestMIDI {
            let base = RailsbackTemplate.cents(forMIDI: key)
            let scale = stiffnessScale(forKey: key, b: model.b(forMIDI: key))
            cents[key] = base * scale
        }
        return StretchCurve(cents: cents, source: model.displayName, isMeasured: false)
    }

    /// How much more or less this piano's stretch should be than the reference,
    /// based on how its measured inharmonicity compares with the default model
    /// at the same key. The effect is damped and bounded so a single bad
    /// measurement cannot distort the whole curve.
    static func stiffnessScale(forKey key: Int, b: Double) -> Double {
        let reference = PianoInharmonicityModel.b(forMIDI: key)
        guard reference > 0, b > 0 else { return 1 }
        // A factor of 2 in B becomes about 1.15x in stretch: stiff strings need
        // more stretch, but not proportionally so, because the treble stretch a
        // tuner applies is only partly a function of the top strings' own
        // inharmonicity.
        let ratio = b / reference
        let scale = pow(ratio, 0.2)
        return min(1.6, max(0.6, scale))
    }

}
