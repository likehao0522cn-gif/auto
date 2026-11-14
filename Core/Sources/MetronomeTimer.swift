import Foundation

/// A countdown for the metronome: play for a set time, then stop.
///
/// The metronome runs in the background, so the countdown is stored as an
/// absolute end date rather than a tick count. A timer that counted ticks
/// would drift whenever the app was suspended, and a user who set ten minutes
/// would come back to a metronome that had run long past that.
public struct MetronomeTimer: Equatable, Codable, Sendable {
    /// How long the metronome should play.
    public let duration: TimeInterval
    /// When the current run should stop, or nil when no timer is running.
    public private(set) var endDate: Date?

    public init(duration: TimeInterval) {
        self.duration = max(0, duration)
        self.endDate = nil
    }

    /// True while a countdown is active.
    public var isRunning: Bool { endDate != nil }

    /// Starts the countdown from a given moment.
    public mutating func start(from now: Date = Date()) {
        guard duration > 0 else { endDate = nil; return }
        endDate = now.addingTimeInterval(duration)
    }

    public mutating func cancel() {
        endDate = nil
    }

    /// Seconds left, or nil when nothing is running. Never negative.
    public func remaining(at now: Date = Date()) -> TimeInterval? {
        guard let endDate else { return nil }
        return max(0, endDate.timeIntervalSince(now))
    }

    /// True once the countdown has reached zero.
    public func hasExpired(at now: Date = Date()) -> Bool {
        guard let endDate else { return false }
        return now >= endDate
    }

    /// How far along the countdown is, 0 to 1.
    public func progress(at now: Date = Date()) -> Double {
        guard duration > 0, let remaining = remaining(at: now) else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }
}
