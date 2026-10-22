import XCTest
@testable import TuneCore

final class MetronomeTimingTests: XCTestCase {
    func testQuarterNoteBeatDuration() {
        let signature = TimeSignature(numerator: 4, denominator: 4)
        XCTAssertEqual(signature.beatDuration(atBPM: 120), 0.5, accuracy: 0.0001)
    }

    func testSixEightBeatDuration() {
        let signature = TimeSignature(numerator: 6, denominator: 8)
        XCTAssertEqual(signature.beatDuration(atBPM: 120), 0.25, accuracy: 0.0001)
        XCTAssertEqual(signature.barDuration(atBPM: 120), 1.5, accuracy: 0.0001)
    }

    func testTapTempo() {
        var estimator = TapTempoEstimator()
        estimator.record(at: 0)
        estimator.record(at: 0.5)
        estimator.record(at: 1.0)
        XCTAssertTrue(estimator.hasEnoughTapsForInitialEstimate)
        XCTAssertEqual(estimator.bpm ?? 0, 120, accuracy: 0.01)
    }

    func testTapTempoResetAfterPause() {
        var estimator = TapTempoEstimator()
        estimator.record(at: 0)
        estimator.record(at: 0.5)
        estimator.record(at: 5.0)
        XCTAssertEqual(estimator.timestamps.count, 1)
    }

    func testAccentPattern() {
        let config = MetronomeConfiguration(
            bpm: 120,
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            accentMode: .firstBeat,
            subdivision: .two,
            countInBars: .off
        )
        let clicks = MetronomePattern.clicks(for: config)
        XCTAssertEqual(clicks.count, 8)
        XCTAssertEqual(clicks.filter(\.isAccent).count, 1)
        XCTAssertEqual(clicks.first?.isAccent, true)
    }

    func testEveryBeatAccent() {
        let config = MetronomeConfiguration(
            bpm: 100,
            timeSignature: TimeSignature(numerator: 3, denominator: 4),
            accentMode: .everyBeat,
            subdivision: .none,
            countInBars: .off
        )
        let clicks = MetronomePattern.clicks(for: config)
        XCTAssertEqual(clicks.count, 3)
        XCTAssertTrue(clicks.allSatisfy(\.isAccent))
    }
}

