import Foundation

/// How a paused metronome affects the countdown.
public enum TimerPauseBehaviour: String, CaseIterable, Identifiable, Sendable {
    /// The clock keeps running while paused. Ten minutes set at ten past
    /// stops at twenty past, however much of it was spent paused.
    case wallClock
    /// Only playing time counts. Pausing freezes the countdown, so the user
    /// always gets the full duration of actual playing.
    case playingTime

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wallClock: return "暂停时继续计时"
        case .playingTime: return "只计算播放时间"
        }
    }

    public var spokenTitle: String {
        switch self {
        case .wallClock: return "暂停时继续计时，暂停期间也算在定时里"
        case .playingTime: return "只计算播放时间，暂停时定时也跟着暂停"
        }
    }
}

/// A countdown for the metronome: play for a set time, then stop.
///
/// The metronome runs in the background, so the countdown is stored as an
/// absolute end date rather than a tick count. A timer that counted ticks
/// would drift whenever the app was suspended, and a user who set ten minutes
/// would come back to a metronome that had run long past that.
public struct MetronomeTimer: Equatable, Codable, Sendable {
    /// How long the metronome should play.
    public let duration: TimeInterval
    /// When the current run should stop, or nil when no countdown is running.
    public private(set) var endDate: Date?
    /// How much time had been used up before the current run started. Only
    /// meaningful under the playing-time behaviour, where pausing banks it.
    public private(set) var elapsedBeforeRun: TimeInterval
    /// When the countdown was paused. Under the wall-clock behaviour the pause
    /// itself counts, so that stretch is subtracted when play resumes.
    public private(set) var pausedAt: Date?

    public init(duration: TimeInterval) {
        self.duration = max(0, duration)
        self.endDate = nil
        self.elapsedBeforeRun = 0
        self.pausedAt = nil
    }

    /// True while a countdown is active.
    public var isRunning: Bool { endDate != nil }

    /// Starts counting from a given moment, honouring time already banked.
    public mutating func start(from now: Date = Date()) {
        guard duration > 0 else { endDate = nil; return }
        if endDate != nil { return }
        let remaining = max(0, duration - elapsedBeforeRun)
        endDate = now.addingTimeInterval(remaining)
        pausedAt = nil
    }

    /// Stops counting without forgetting the configured duration or elapsed time.
    ///
    /// `bankingElapsed` remembers exactly how much has been used so far, which
    /// is what lets a resume continue rather than start over. Under the
    /// wall-clock behaviour the pause itself should count, so the elapsed time
    /// is left alone and the pause start is recorded instead.
    public mutating func pause(bankingElapsed: Bool, at now: Date = Date()) {
        guard let endDate else { return }
        if bankingElapsed {
            // Pausing freezes the clock: bank how much was used and drop the
            // deadline so time cannot pass while stopped.
            elapsedBeforeRun = min(duration, max(0, duration - endDate.timeIntervalSince(now)))
            self.endDate = nil
            pausedAt = nil
        } else {
            // The pause still counts, so the deadline is left exactly where it
            // is; resume needs to change nothing.
            pausedAt = now
        }
    }

    /// Clears the countdown and forgets any elapsed time.
    public mutating func cancel() {
        endDate = nil
        elapsedBeforeRun = 0
        pausedAt = nil
    }

    /// Seconds left, or nil when nothing is running. Never negative.
    public func remaining(at now: Date = Date()) -> TimeInterval? {
        guard let endDate else { return nil }
        return max(0, endDate.timeIntervalSince(now))
    }

    /// How long the next run would last, in seconds.
    ///
    /// While running this is the live remaining time; while stopped it is what
    /// would be left if play resumed now. Either way it is what the user should
    /// see, since it is the time the metronome still owes them.
    public func remainingOrPending(at now: Date = Date()) -> TimeInterval {
        if let remaining = remaining(at: now) { return remaining }
        return max(0, duration - elapsedBeforeRun)
    }

    /// True once the countdown has reached zero.
    public func hasExpired(at now: Date = Date()) -> Bool {
        guard let endDate else { return false }
        return now >= endDate
    }

    /// How far along the countdown is, 0 to 1.
    public func progress(at now: Date = Date()) -> Double {
        guard duration > 0, let remaining = remaining(at: now) else { return 0 }
        let used = duration - remaining + elapsedBeforeRun
        return min(1, max(0, used / duration))
    }
}
