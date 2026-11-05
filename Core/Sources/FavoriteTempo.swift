import Foundation

/// A tempo the user relies on often, with the statistics that decide whether
/// it should be offered automatically.
public struct FavoriteTempo: Codable, Equatable, Identifiable, Sendable {
    /// Tempo in beats per minute. Whole numbers only, matching the UI.
    public let bpm: Int
    /// How many times the metronome was started at this tempo.
    public var useCount: Int
    /// Total seconds the metronome actually ran at this tempo.
    public var totalPlaySeconds: Double
    /// True when the user added it explicitly; automatic additions are false.
    public var isManual: Bool

    public var id: Int { bpm }

    public init(
        bpm: Int,
        useCount: Int = 0,
        totalPlaySeconds: Double = 0,
        isManual: Bool = true
    ) {
        self.bpm = bpm
        self.useCount = useCount
        self.totalPlaySeconds = totalPlaySeconds
        self.isManual = isManual
    }

    /// Rounded minutes, used in spoken descriptions.
    public var playMinutes: Int {
        Int((totalPlaySeconds / 60).rounded())
    }
}

/// Ordering options offered in settings. Each yields a stable, predictable
/// list so VoiceOver users can learn where a tempo sits.
public enum FavoriteTempoSort: String, CaseIterable, Identifiable, Sendable {
    case speedAscending
    case useCountDescending
    case playTimeDescending

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .speedAscending: return "按速度从小到大"
        case .useCountDescending: return "按使用次数从多到少"
        case .playTimeDescending: return "按使用时间从多到少"
        }
    }

    public var spokenTitle: String {
        switch self {
        case .speedAscending: return "按速度值从小到大排列"
        case .useCountDescending: return "按使用次数从多到少排列"
        case .playTimeDescending: return "按累计播放时间从多到少排列"
        }
    }
}

/// Pure rules for the favorite tempo list: capacity, automatic promotion and
/// ordering. Kept free of persistence so it can be unit tested directly.
public enum FavoriteTempoRules {
    /// The list is meant to stay scannable, especially with VoiceOver.
    public static let capacity = 10

    /// Automatic promotion needs sustained use, not a single experiment.
    public static let automaticUseCountThreshold = 5
    public static let automaticPlaySecondsThreshold: Double = 120

    public static func sorted(
        _ tempos: [FavoriteTempo],
        by order: FavoriteTempoSort
    ) -> [FavoriteTempo] {
        switch order {
        case .speedAscending:
            return tempos.sorted { $0.bpm < $1.bpm }
        case .useCountDescending:
            return tempos.sorted {
                if $0.useCount != $1.useCount { return $0.useCount > $1.useCount }
                return $0.bpm < $1.bpm
            }
        case .playTimeDescending:
            return tempos.sorted {
                if $0.totalPlaySeconds != $1.totalPlaySeconds {
                    return $0.totalPlaySeconds > $1.totalPlaySeconds
                }
                return $0.bpm < $1.bpm
            }
        }
    }

    /// Whether a tempo has earned a place automatically.
    public static func qualifiesForAutomaticAdd(_ tempo: FavoriteTempo) -> Bool {
        tempo.useCount >= automaticUseCountThreshold
            && tempo.totalPlaySeconds >= automaticPlaySecondsThreshold
    }
}
