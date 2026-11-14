import XCTest
@testable import TuneCore

final class MetronomeTimerTests: XCTestCase {

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    func testStartsIdle() {
        let timer = MetronomeTimer(duration: 600)
        XCTAssertFalse(timer.isRunning)
        XCTAssertNil(timer.remaining(at: date(0)))
        XCTAssertFalse(timer.hasExpired(at: date(0)))
    }

    func testCountdownCountsDown() {
        var timer = MetronomeTimer(duration: 600)
        timer.start(from: date(0))
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: date(0)) ?? 0, 600, accuracy: 0.001)
        XCTAssertEqual(timer.remaining(at: date(300)) ?? 0, 300, accuracy: 0.001)
    }

    func testExpiresAtTheEnd() {
        var timer = MetronomeTimer(duration: 60)
        timer.start(from: date(0))
        XCTAssertFalse(timer.hasExpired(at: date(59)))
        XCTAssertTrue(timer.hasExpired(at: date(60)))
        XCTAssertTrue(timer.hasExpired(at: date(120)))
    }

    func testRemainingNeverGoesNegative() {
        var timer = MetronomeTimer(duration: 60)
        timer.start(from: date(0))
        XCTAssertEqual(timer.remaining(at: date(600)) ?? -1, 0, accuracy: 0.001)
    }

    func testProgressRunsZeroToOne() {
        var timer = MetronomeTimer(duration: 100)
        timer.start(from: date(0))
        XCTAssertEqual(timer.progress(at: date(0)), 0, accuracy: 0.001)
        XCTAssertEqual(timer.progress(at: date(50)), 0.5, accuracy: 0.001)
        XCTAssertEqual(timer.progress(at: date(100)), 1, accuracy: 0.001)
        XCTAssertEqual(timer.progress(at: date(200)), 1, accuracy: 0.001)
    }

    func testCancelStopsCountdown() {
        var timer = MetronomeTimer(duration: 600)
        timer.start(from: date(0))
        timer.cancel()
        XCTAssertFalse(timer.isRunning)
        XCTAssertNil(timer.remaining(at: date(10)))
    }

    // MARK: - Pause behaviour

    func testWallClockPauseKeepsCounting() {
        // Ten minutes at t=0; pause at 180s and resume at 300s. Because the
        // pause itself counts, only 300s should be left on resume.
        var timer = MetronomeTimer(duration: 600)
        timer.start(from: date(0))
        timer.pause(bankingElapsed: false, at: date(180))
        timer.start(from: date(300))
        XCTAssertEqual(timer.remaining(at: date(300)) ?? 0, 300, accuracy: 0.001)
        XCTAssertTrue(timer.hasExpired(at: date(600)))
    }

    func testPlayingTimePauseFreezesCountdown() {
        // Same sequence, but pausing freezes the clock: 420s should remain.
        var timer = MetronomeTimer(duration: 600)
        timer.start(from: date(0))
        timer.pause(bankingElapsed: true, at: date(180))
        timer.start(from: date(300))
        XCTAssertEqual(timer.remaining(at: date(300)) ?? 0, 420, accuracy: 0.001)
        XCTAssertFalse(timer.hasExpired(at: date(600)))
    }

    func testPlayingTimeAccumulatesAcrossSeveralPauses() {
        // Three stops of 100s each should still add up to 300s of real play.
        var timer = MetronomeTimer(duration: 600)
        timer.start(from: date(0))
        timer.pause(bankingElapsed: true, at: date(100))
        timer.start(from: date(200))
        timer.pause(bankingElapsed: true, at: date(300))
        timer.start(from: date(400))
        timer.pause(bankingElapsed: true, at: date(500))
        timer.start(from: date(600))
        XCTAssertEqual(timer.remaining(at: date(600)) ?? 0, 300, accuracy: 0.001)
    }

    func testRepeatedStartDoesNotReset() {
        // Calling start while already running must be a no-op, or a rebuild
        // of the audio engine would silently restart the countdown.
        var timer = MetronomeTimer(duration: 600)
        timer.start(from: date(0))
        timer.start(from: date(120))
        XCTAssertEqual(timer.remaining(at: date(120)) ?? 0, 480, accuracy: 0.001)
    }

    func testZeroDurationNeverRuns() {
        var timer = MetronomeTimer(duration: 0)
        timer.start(from: date(0))
        XCTAssertFalse(timer.isRunning)
    }

    func testSurvivesEncoding() throws {
        var timer = MetronomeTimer(duration: 900)
        timer.start(from: date(0))
        let data = try JSONEncoder().encode(timer)
        let decoded = try JSONDecoder().decode(MetronomeTimer.self, from: data)
        XCTAssertEqual(decoded, timer)
    }

    // MARK: - Presets and custom input

    func testPresetsAreOrderedAndPositive() {
        let presets = TimerDurations.presets
        XCTAssertFalse(presets.isEmpty)
        var previous: TimeInterval = 0
        for preset in presets {
            XCTAssertGreaterThan(preset.seconds, previous)
            XCTAssertFalse(preset.spokenTitle.isEmpty)
            previous = preset.seconds
        }
    }

    func testPresetsIncludeCommonBlocks() {
        let seconds = Set(TimerDurations.presets.map(\.seconds))
        XCTAssertTrue(seconds.contains(60))
        XCTAssertTrue(seconds.contains(600))
    }

    func testSpokenMinutes() {
        XCTAssertEqual(TimerDurations.spoken(minutes: 1), "1 \u{5206}\u{949F}")
        XCTAssertEqual(TimerDurations.spoken(minutes: 45), "45 \u{5206}\u{949F}")
        XCTAssertEqual(TimerDurations.spoken(minutes: 60), "1 \u{5C0F}\u{65F6}")
        XCTAssertEqual(TimerDurations.spoken(minutes: 90), "1 \u{5C0F}\u{65F6} 30 \u{5206}\u{949F}")
    }

    func testParsesCustomMinutes() {
        XCTAssertEqual(TimerDurations.parse(minutes: "15"), .success(15))
        XCTAssertEqual(TimerDurations.parse(minutes: " 7 "), .success(7))
    }

    func testRejectsBadCustomMinutes() {
        XCTAssertEqual(TimerDurations.parse(minutes: ""), .failure(.empty))
        XCTAssertEqual(TimerDurations.parse(minutes: "abc"), .failure(.notAnInteger))
        XCTAssertEqual(TimerDurations.parse(minutes: "0"), .failure(.outOfRange))
        XCTAssertEqual(TimerDurations.parse(minutes: "1000"), .failure(.outOfRange))
    }
}
