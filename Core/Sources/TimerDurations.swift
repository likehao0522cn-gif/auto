import Foundation

/// A selectable countdown length.
///
/// Presets are small and spoken in words, because a blind user picks from
/// this list by listening rather than looking.
public struct TimerDurationOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let seconds: TimeInterval
    public let spokenTitle: String

    public init(id: String, seconds: TimeInterval, spokenTitle: String) {
        self.id = id
        self.seconds = seconds
        self.spokenTitle = spokenTitle
    }
}

public enum TimerDurations {
    /// Covers the usual practice blocks: a quick minute, the common five and
    /// ten, then longer stretches up to an hour.
    public static let presets: [TimerDurationOption] = [
        TimerDurationOption(id: "1m", seconds: 60, spokenTitle: "1 分钟"),
        TimerDurationOption(id: "2m", seconds: 120, spokenTitle: "2 分钟"),
        TimerDurationOption(id: "5m", seconds: 300, spokenTitle: "5 分钟"),
        TimerDurationOption(id: "10m", seconds: 600, spokenTitle: "10 分钟"),
        TimerDurationOption(id: "15m", seconds: 900, spokenTitle: "15 分钟"),
        TimerDurationOption(id: "20m", seconds: 1200, spokenTitle: "20 分钟"),
        TimerDurationOption(id: "30m", seconds: 1800, spokenTitle: "30 分钟"),
        TimerDurationOption(id: "45m", seconds: 2700, spokenTitle: "45 分钟"),
        TimerDurationOption(id: "1h", seconds: 3600, spokenTitle: "1 小时")
    ]

    /// Shortest and longest custom values accepted, in minutes.
    public static let minimumMinutes = 1
    public static let maximumMinutes = 999

    /// Turns a whole number of minutes into a spoken phrase. Whole hours read
    /// as "1 小时" rather than "1 小时 0 分钟".
    public static func spoken(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) 分钟" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分钟"
    }

    /// Parses a typed number of minutes.
    public static func parse(minutes text: String) -> Result<Int, BPMInputError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let minutes = Int(trimmed) else { return .failure(.notAnInteger) }
        guard (minimumMinutes...maximumMinutes).contains(minutes) else { return .failure(.outOfRange) }
        return .success(minutes)
    }
}
