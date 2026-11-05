import Foundation

/// Acoustic families that need different pitch-detection behaviour.
///
/// The detector thresholds cannot be identical for every instrument: a bowed
/// erhu has a weak, drifting fundamental and heavy bow noise, a piano has
/// stretched partials and strong decay, and a plucked guitar sits between them.
/// Grouping instruments by how they actually sound lets one tuner behave
/// sensibly for each without writing a separate algorithm per instrument.
public enum AcousticFamily: String, Hashable, Sendable {
    /// Struck strings with stretched, inharmonic partials and fast decay.
    case piano
    /// Plucked strings; clean attack, moderate harmonics.
    case plucked
    /// Bowed strings; weak fundamental, continuous bow noise, vibrato.
    case bowed
    /// Free measurement of any single tone.
    case chromatic

    public var title: String {
        switch self {
        case .piano: return "钢琴"
        case .plucked: return "弹拨弦乐"
        case .bowed: return "弓弦乐"
        case .chromatic: return "半音"
        }
    }
}

/// Detection thresholds tuned per acoustic family.
public struct DetectionProfile: Equatable, Sendable {
    /// How strong a competing peak must be, relative to the fundamental,
    /// before the app calls it a second note.
    public let multiPitchRatio: Double
    /// Minimum confidence before a reading is trusted.
    public let minimumConfidence: Double
    /// Frame-to-frame spread allowed before the reading is considered steady.
    public let maximumRelativeSpread: Double
    /// Multiplier applied to the rolling noise floor for the detection gate.
    public let noiseFloorMultiplier: Double

    public init(
        multiPitchRatio: Double,
        minimumConfidence: Double,
        maximumRelativeSpread: Double,
        noiseFloorMultiplier: Double
    ) {
        self.multiPitchRatio = multiPitchRatio
        self.minimumConfidence = minimumConfidence
        self.maximumRelativeSpread = maximumRelativeSpread
        self.noiseFloorMultiplier = noiseFloorMultiplier
    }

    public static func profile(for family: AcousticFamily) -> DetectionProfile {
        switch family {
        case .piano:
            // Stretched partials and long decay; a genuine second key is loud,
            // so the bar stays high while confidence can be a little lower.
            return DetectionProfile(
                multiPitchRatio: 0.45,
                minimumConfidence: 0.55,
                maximumRelativeSpread: 0.04,
                noiseFloorMultiplier: 2.2
            )
        case .plucked:
            // Clean attack with rich but harmonic content.
            return DetectionProfile(
                multiPitchRatio: 0.40,
                minimumConfidence: 0.58,
                maximumRelativeSpread: 0.035,
                noiseFloorMultiplier: 2.5
            )
        case .bowed:
            // Bowed strings are the hardest case: the fundamental is often not
            // the loudest partial and the bow adds broadband noise. Requiring
            // a very strong competing peak avoids constant false "two notes".
            return DetectionProfile(
                multiPitchRatio: 0.65,
                minimumConfidence: 0.50,
                maximumRelativeSpread: 0.06,
                noiseFloorMultiplier: 3.0
            )
        case .chromatic:
            // Free measurement: prefer accuracy over convenience.
            return DetectionProfile(
                multiPitchRatio: 0.30,
                minimumConfidence: 0.62,
                maximumRelativeSpread: 0.03,
                noiseFloorMultiplier: 2.5
            )
        }
    }
}
