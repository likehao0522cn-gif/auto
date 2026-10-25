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
        XCTAssertTrue(clicks.first?.isAccent ?? false)
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

    func testBPMLimitsAreRepresentedByConfiguration() {
        let slow = MetronomeConfiguration(bpm: 20)
        let fast = MetronomeConfiguration(bpm: 300)
        XCTAssertEqual(slow.beatDuration, 3, accuracy: 0.0001)
        XCTAssertEqual(fast.beatDuration, 0.2, accuracy: 0.0001)
    }

    func testTapTempoClampsToValidRange() {
        var estimator = TapTempoEstimator()
        estimator.record(at: 0)
        estimator.record(at: 0.1)
        estimator.record(at: 0.2)
        XCTAssertGreaterThan(estimator.bpm ?? 0, 300)
    }


    func testCountInOffProducesNoClicks() {
        let config = MetronomeConfiguration(countInBars: .off)
        XCTAssertTrue(MetronomePattern.countInClicks(for: config).isEmpty)
    }

    func testCountInClicksForOneBar() {
        let config = MetronomeConfiguration(
            bpm: 120,
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            accentMode: .firstBeat,
            subdivision: .none,
            countInBars: .one
        )
        let clicks = MetronomePattern.countInClicks(for: config)
        XCTAssertEqual(clicks.count, 4)
        XCTAssertEqual(clicks.first?.time ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(clicks.last?.time ?? -1, 1.5, accuracy: 0.0001)
    }

    func testCountInClicksForTwoBars() {
        let config = MetronomeConfiguration(
            bpm: 100,
            timeSignature: TimeSignature(numerator: 3, denominator: 4),
            accentMode: .firstBeat,
            subdivision: .none,
            countInBars: .two
        )
        let clicks = MetronomePattern.countInClicks(for: config)
        XCTAssertEqual(clicks.count, 6)
        XCTAssertEqual(clicks.filter(\.isAccent).count, 2)
    }

    func testTripletSubdivisionProducesTwelveClicksInFourFour() {
        let config = MetronomeConfiguration(
            bpm: 90,
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            accentMode: .firstBeat,
            subdivision: .three,
            countInBars: .off
        )
        let clicks = MetronomePattern.clicks(for: config)
        XCTAssertEqual(clicks.count, 12)
        XCTAssertEqual(clicks.filter(\.isAccent).count, 1)
    }
}

