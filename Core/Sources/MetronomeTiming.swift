import Foundation

public enum MetronomeTempo {
    public static let minimumBPM = 20
    public static let maximumBPM = 300
    public static let validBPMRange: ClosedRange<Double> = 20...300

    public static func clampedBPM(_ bpm: Double) -> Double {
        min(validBPMRange.upperBound, max(validBPMRange.lowerBound, bpm.rounded()))
    }
}

public enum BPMInputError: Error, Equatable, Sendable {
    case empty
    case notAnInteger
    case outOfRange
}

public enum BPMInput {
    public static func parse(_ text: String) -> Result<Int, BPMInputError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let bpm = Int(trimmed) else { return .failure(.notAnInteger) }
        guard (MetronomeTempo.minimumBPM...MetronomeTempo.maximumBPM).contains(bpm) else {
            return .failure(.outOfRange)
        }
        return .success(bpm)
    }
}

public struct TimeSignature: Identifiable, Hashable, Sendable, CustomStringConvertible {
    public let numerator: Int
    public let denominator: Int

    public init(numerator: Int, denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public var id: String { "\(numerator)/\(denominator)" }
    public var description: String { id }

    /// Short spoken title used by VoiceOver. Keep this concise; detailed meter
    /// explanations belong in help text rather than every picker option.
    public var spokenTitle: String {
        "\(id) 拍"
    }

    /// Label used when VoiceOver moves focus to the time-signature selector.
    public var accessibilityTitle: String {
        "\(id) 拍"
    }

    public func beatDuration(atBPM bpm: Double) -> TimeInterval {
        guard bpm > 0 else { return 0 }
        return (60.0 / bpm) * (4.0 / Double(denominator))
    }

    public func barDuration(atBPM bpm: Double) -> TimeInterval {
        beatDuration(atBPM: bpm) * Double(numerator)
    }

    public static let presets: [TimeSignature] = [
        TimeSignature(numerator: 1, denominator: 4),
        TimeSignature(numerator: 2, denominator: 4),
        TimeSignature(numerator: 3, denominator: 4),
        TimeSignature(numerator: 4, denominator: 4),
        TimeSignature(numerator: 5, denominator: 4),
        TimeSignature(numerator: 6, denominator: 8),
        TimeSignature(numerator: 7, denominator: 8),
        TimeSignature(numerator: 9, denominator: 8),
        TimeSignature(numerator: 12, denominator: 8)
    ]
}

public enum AccentMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case firstBeat
    case everyBeat

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .firstBeat: return "第一拍重音"
        case .everyBeat: return "每拍重音"
        }
    }

    public var spokenTitle: String {
        switch self {
        case .firstBeat: return "仅第一拍重音，用来区分小节开头"
        case .everyBeat: return "每一拍都重音，所有拍声音一样"
        }
    }
}

public enum Subdivision: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case none = 1
    case two = 2
    case three = 3
    case four = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .none: return "无"
        case .two: return "二连"
        case .three: return "三连"
        case .four: return "四连"
        }
    }

    public var spokenTitle: String {
        switch self {
        case .none: return "不细分，每拍只响一次"
        case .two: return "二连，每拍平均分成两次"
        case .three: return "三连，每拍平均分成三次"
        case .four: return "四连，每拍平均分成四次"
        }
    }
}

public struct MetronomeConfiguration: Equatable, Sendable {
    public var bpm: Double
    public var timeSignature: TimeSignature
    public var accentMode: AccentMode
    public var subdivision: Subdivision

    public init(
        bpm: Double = 120,
        timeSignature: TimeSignature = TimeSignature(numerator: 4, denominator: 4),
        accentMode: AccentMode = .firstBeat,
        subdivision: Subdivision = .none
    ) {
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.accentMode = accentMode
        self.subdivision = subdivision
    }

    public var beatDuration: TimeInterval {
        timeSignature.beatDuration(atBPM: bpm)
    }

    public var barDuration: TimeInterval {
        timeSignature.barDuration(atBPM: bpm)
    }
}

public struct MetronomeClick: Equatable, Sendable {
    public let time: TimeInterval
    public let isAccent: Bool

    public init(time: TimeInterval, isAccent: Bool) {
        self.time = time
        self.isAccent = isAccent
    }
}

public enum MetronomePattern {
    public static func clicks(for configuration: MetronomeConfiguration) -> [MetronomeClick] {
        let beatDuration = configuration.beatDuration
        guard beatDuration > 0 else { return [] }

        var clicks: [MetronomeClick] = []
        let subdivisionCount = configuration.subdivision.rawValue
        let divisionsPerBeat = max(1, subdivisionCount)

        for beat in 0..<configuration.timeSignature.numerator {
            let beatTime = Double(beat) * beatDuration
            let isAccent: Bool
            switch configuration.accentMode {
            case .firstBeat:
                isAccent = beat == 0
            case .everyBeat:
                isAccent = true
            }
            clicks.append(MetronomeClick(time: beatTime, isAccent: isAccent))

            if divisionsPerBeat > 1 {
                for division in 1..<divisionsPerBeat {
                    let time = beatTime + beatDuration * Double(division) / Double(divisionsPerBeat)
                    clicks.append(MetronomeClick(time: time, isAccent: false))
                }
            }
        }

        return clicks.sorted { $0.time < $1.time }
    }
}

public struct TapTempoEstimator: Sendable {
    // MARK: - Tuning constants

    /// Absolute plausibility window for one interval. Outside it the value is
    /// noise rather than a beat: too short is a bouncing or double tap, too
    /// long means the user stopped tapping.
    private static let minimumPlausibleInterval: TimeInterval = 0.05
    private static let maximumPlausibleInterval: TimeInterval = 3.0

    /// Gaps below this fraction of the median are rejected. A gap under 60% of
    /// the beat is either a stray double hit or jitter, so it must not pollute
    /// the estimate. 0.6 is the tighter of the jitter floor (0.55) and the
    /// double-hit floor (0.6), so it covers both.
    private static let minimumIntervalRatio: Double = 0.6

    /// Gaps above this fraction of the median are rejected. A dropped tap
    /// roughly doubles the gap and a pause between groups is even longer, so
    /// both land above 1.6 and are discarded. This is what stops a missed beat
    /// from halving the reported tempo, and what stops a pause between groups
    /// of taps from dragging the average down.
    private static let maximumIntervalRatio: Double = 1.6

    /// A tempo is only reported once this many clean intervals exist. Four
    /// taps produce three intervals, so the first result appears on the fourth
    /// tap, but it is already robust because the intervals have been filtered.
    private static let minimumReliableIntervalCount = 3

    public private(set) var timestamps: [TimeInterval] = []
    public private(set) var tapCount: Int = 0
    public let resetInterval: TimeInterval
    public let maximumIntervalCount: Int
    public let groupSize: Int
    public let maximumTapCount: Int
    private var lastPublishedTapCount: Int = 0

    public init(
        resetInterval: TimeInterval = 3,
        maximumIntervalCount: Int = 8,
        groupSize: Int = 4
    ) {
        self.resetInterval = resetInterval
        self.maximumIntervalCount = max(2, maximumIntervalCount)
        self.groupSize = max(2, groupSize)
        self.maximumTapCount = self.maximumIntervalCount + 1
    }

    @discardableResult
    public mutating func record(at timestamp: TimeInterval) -> Bool {
        var restarted = false

        if let last = timestamps.last, timestamp - last > resetInterval {
            reset()
            restarted = true
        } else if let last = timestamps.last, timestamp <= last {
            reset()
            restarted = true
        }

        timestamps.append(timestamp)
        tapCount += 1

        if timestamps.count > maximumTapCount {
            timestamps.removeFirst(timestamps.count - maximumTapCount)
        }

        return restarted
    }

    public mutating func reset() {
        timestamps.removeAll(keepingCapacity: true)
        tapCount = 0
        lastPublishedTapCount = 0
    }

    public var intervals: [TimeInterval] {
        guard timestamps.count >= 2 else { return [] }
        return zip(timestamps.dropFirst(), timestamps).map { $0.0 - $0.1 }
    }

    /// Intervals that are individually plausible, before outlier rejection.
    private var plausibleIntervals: [TimeInterval] {
        intervals.filter {
            $0 > Self.minimumPlausibleInterval && $0 < Self.maximumPlausibleInterval
        }
    }

    /// Intervals kept after discarding double hits, dropped beats and pauses.
    ///
    /// A median defines the centre, and only intervals close to that centre
    /// survive. The median is used instead of the mean because a single long
    /// pause or a single dropped beat must not move the reference point.
    public var reliableIntervals: [TimeInterval] {
        let candidates = plausibleIntervals
        guard !candidates.isEmpty else { return [] }
        guard let center = Self.median(of: candidates), center > 0 else { return [] }
        return candidates.filter { Self.isReliable($0, around: center) }
    }

    /// Robust tempo estimate, or nil until enough clean intervals exist.
    ///
    /// The centre of the retained intervals is again the median, so the result
    /// does not drift with the occasional slow or fast tap.
    public var bpm: Double? {
        let reliable = reliableIntervals
        guard reliable.count >= Self.minimumReliableIntervalCount else { return nil }
        guard let center = Self.median(of: reliable), center > 0 else { return nil }
        return 60.0 / center
    }

    /// How many clean intervals the current estimate is based on.
    public var reliableIntervalCount: Int { reliableIntervals.count }

    public var hasEnoughTapsForInitialEstimate: Bool {
        tapCount >= groupSize
    }

    public var shouldPublishResult: Bool {
        hasEnoughTapsForInitialEstimate && tapCount - lastPublishedTapCount >= groupSize
    }

    public mutating func markResultPublished() {
        lastPublishedTapCount = tapCount
    }

    /// True when the interval sits within the accepted band around the centre.
    private static func isReliable(_ interval: TimeInterval, around center: TimeInterval) -> Bool {
        guard center > 0 else { return false }
        let ratio = interval / center
        return ratio >= minimumIntervalRatio && ratio <= maximumIntervalRatio
    }

    /// Median of a list, averaging the two middle values for an even count.
    private static func median(of values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 {
            return sorted[middle]
        }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }
}
