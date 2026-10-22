import Foundation

public struct TimeSignature: Identifiable, Hashable, Sendable, CustomStringConvertible {
    public let numerator: Int
    public let denominator: Int

    public init(numerator: Int, denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public var id: String { "\(numerator)/\(denominator)" }
    public var description: String { id }

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
}

public enum CountInBars: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case off = 0
    case one = 1
    case two = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .off: return "关闭"
        case .one: return "1 小节"
        case .two: return "2 小节"
        }
    }
}

public struct MetronomeConfiguration: Equatable, Sendable {
    public var bpm: Double
    public var timeSignature: TimeSignature
    public var accentMode: AccentMode
    public var subdivision: Subdivision
    public var countInBars: CountInBars

    public init(
        bpm: Double = 120,
        timeSignature: TimeSignature = TimeSignature(numerator: 4, denominator: 4),
        accentMode: AccentMode = .firstBeat,
        subdivision: Subdivision = .none,
        countInBars: CountInBars = .off
    ) {
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.accentMode = accentMode
        self.subdivision = subdivision
        self.countInBars = countInBars
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
    public private(set) var timestamps: [TimeInterval] = []
    public let resetInterval: TimeInterval
    public let maximumTapCount: Int

    public init(resetInterval: TimeInterval = 3, maximumTapCount: Int = 8) {
        self.resetInterval = resetInterval
        self.maximumTapCount = maximumTapCount
    }

    public mutating func record(at timestamp: TimeInterval) {
        if let last = timestamps.last, timestamp - last > resetInterval {
            timestamps.removeAll(keepingCapacity: true)
        } else if let last = timestamps.last, timestamp <= last {
            timestamps.removeAll(keepingCapacity: true)
        }

        timestamps.append(timestamp)
        if timestamps.count > maximumTapCount {
            timestamps.removeFirst(timestamps.count - maximumTapCount)
        }
    }

    public mutating func reset() {
        timestamps.removeAll(keepingCapacity: true)
    }

    public var intervals: [TimeInterval] {
        guard timestamps.count >= 2 else { return [] }
        return zip(timestamps.dropFirst(), timestamps).map { $0.0 - $0.1 }
    }

    public var bpm: Double? {
        let intervals = intervals.filter { $0 > 0.05 && $0 < 3 }
        guard !intervals.isEmpty else { return nil }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        guard average > 0 else { return nil }
        return 60.0 / average
    }

    public var hasEnoughTapsForInitialEstimate: Bool {
        timestamps.count >= 3
    }
}


