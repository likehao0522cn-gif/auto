import Foundation

/// A named starting profile for a class of piano, used before anything has
/// been measured on the actual instrument.
///
/// Pianos differ mostly by string length. Short strings are stiffer, so their
/// partials run sharper and they need a wider stretch. Concert grands have
/// long strings, less inharmonicity and a narrower stretch. This is why two
/// pianos tuned to the same reference do not end up with the same curve.
///
/// The values here are an order-of-magnitude starting point chosen from the
/// published relationship between piano size and inharmonicity. They are not
/// measurements of any specific instrument, and they should be replaced by a
/// measured profile as soon as the user measures a few strings.
public struct PianoModelTemplate: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    /// Spoken description for VoiceOver. Must stand on its own, because the
    /// user cannot see the size of the piano drawn next to the name.
    public let spokenDescription: String
    /// Inharmonicity at A4 for this class of piano.
    public let bAtA4: Double
    /// Decay per semitone below A4.
    public let bassSlope: Double
    /// Decay per semitone above A4.
    public let trebleSlope: Double

    public init(
        id: String,
        displayName: String,
        spokenDescription: String,
        bAtA4: Double,
        bassSlope: Double,
        trebleSlope: Double
    ) {
        self.id = id
        self.displayName = displayName
        self.spokenDescription = spokenDescription
        self.bAtA4 = bAtA4
        self.bassSlope = bassSlope
        self.trebleSlope = trebleSlope
    }

    /// Inharmonicity for a key under this template.
    public func b(forMIDI midi: Int) -> Double {
        let delta = Double(midi - PianoInharmonicityModel.referenceMIDI)
        let slope = delta < 0 ? bassSlope : trebleSlope
        let value = bAtA4 * exp(-slope * delta)
        return min(0.05, max(1e-7, value))
    }
}

extension PianoModelTemplate {
    /// Small upright: the shortest strings, the stiffest partials, the widest
    /// stretch.
    public static let smallUpright = PianoModelTemplate(
        id: "upright-small",
        displayName: "小型立式琴",
        spokenDescription: "小型立式钢琴，琴弦较短，需要较宽的拉伸曲线",
        bAtA4: 2.4e-4,
        bassSlope: 0.020,
        trebleSlope: 0.014
    )

    /// Large upright, close to the reference model.
    public static let largeUpright = PianoModelTemplate(
        id: "upright-large",
        displayName: "大型立式琴",
        spokenDescription: "大型立式钢琴，拉伸曲线宽度接近通用参考",
        bAtA4: 1.6e-4,
        bassSlope: 0.018,
        trebleSlope: 0.012
    )

    /// Grand: long strings, lower inharmonicity, narrower stretch.
    public static let grand = PianoModelTemplate(
        id: "grand",
        displayName: "三角琴",
        spokenDescription: "三角钢琴，琴弦较长，拉伸曲线较窄",
        bAtA4: 9.0e-5,
        bassSlope: 0.015,
        trebleSlope: 0.010
    )

    /// All templates in a stable order, smallest first.
    public static let all: [PianoModelTemplate] = [smallUpright, largeUpright, grand]

    public static func template(withID id: String) -> PianoModelTemplate? {
        all.first { $0.id == id }
    }
}
