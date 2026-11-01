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
        estimator.record(at: 1.5)
        estimator.record(at: 2.0)
        XCTAssertTrue(estimator.hasEnoughTapsForInitialEstimate)
        XCTAssertEqual(estimator.bpm ?? 0, 120, accuracy: 0.01)
    }

    func testTapTempoResetAfterPause() {
        var estimator = TapTempoEstimator()
        estimator.record(at: 0)
        estimator.record(at: 0.5)
        estimator.record(at: 5.0)
        XCTAssertEqual(estimator.timestamps.count, 1)
        XCTAssertEqual(estimator.tapCount, 1)
        XCTAssertFalse(estimator.shouldPublishResult)
    }

    func testTapTempoPublishesFirstResultAfterFourTapsThenEveryTap() {
        var estimator = TapTempoEstimator()
        estimator.record(at: 0)
        estimator.record(at: 0.5)
        estimator.record(at: 1.0)
        estimator.record(at: 1.5)
        XCTAssertTrue(estimator.hasEnoughTapsForInitialEstimate)
        XCTAssertTrue(estimator.shouldPublishResult)
        estimator.markResultPublished()
        XCTAssertEqual(estimator.bpm ?? 0, 120, accuracy: 0.01)

        estimator.record(at: 2.0)
        XCTAssertTrue(estimator.shouldPublishResult)
        estimator.markResultPublished()
        XCTAssertEqual(estimator.bpm ?? 0, 120, accuracy: 0.01)

        estimator.record(at: 2.5)
        XCTAssertTrue(estimator.shouldPublishResult)
        estimator.markResultPublished()
        XCTAssertEqual(estimator.bpm ?? 0, 120, accuracy: 0.01)
    }

    func testTapTempoKeepsOnlyEightIntervals() {
        var estimator = TapTempoEstimator()
        for index in 0...10 {
            estimator.record(at: Double(index) * 0.5)
        }
        XCTAssertEqual(estimator.tapCount, 11)
        XCTAssertEqual(estimator.timestamps.count, 9)
        XCTAssertEqual(estimator.intervals.count, 8)
    }

    func testTapTempoWaitsForFourTapsBeforePublishing() {
        var estimator = TapTempoEstimator()
        estimator.record(at: 0)
        estimator.record(at: 0.5)
        estimator.record(at: 1.0)
        XCTAssertFalse(estimator.hasEnoughTapsForInitialEstimate)
        XCTAssertFalse(estimator.shouldPublishResult)
        estimator.record(at: 1.5)
        XCTAssertTrue(estimator.hasEnoughTapsForInitialEstimate)
        XCTAssertTrue(estimator.shouldPublishResult)
    }

    func testTapTempoSmoothingUsesFirstValueThenMovesGradually() {
        let initial = TapTempoSmoothing.next(previousBPM: nil, rawBPM: 120)
        XCTAssertEqual(initial, 120, accuracy: 0.0001)

        let next = TapTempoSmoothing.next(previousBPM: 120, rawBPM: 160)
        XCTAssertEqual(next, 134, accuracy: 0.0001)

        let held = TapTempoSmoothing.next(previousBPM: 134, rawBPM: 134)
        XCTAssertEqual(held, 134, accuracy: 0.0001)
    }

    func testTapTempoSmoothingFactorIsClamped() {
        XCTAssertEqual(
            TapTempoSmoothing.next(previousBPM: 100, rawBPM: 200, factor: 0),
            100,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            TapTempoSmoothing.next(previousBPM: 100, rawBPM: 200, factor: 2),
            200,
            accuracy: 0.0001
        )
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

    func testBPMInputAcceptsWholeNumbersAtRangeBoundaries() {
        XCTAssertEqual(BPMInput.parse("20"), .success(20))
        XCTAssertEqual(BPMInput.parse("300"), .success(300))
        XCTAssertEqual(BPMInput.parse(" 120 "), .success(120))
    }

    func testBPMInputRejectsEmptyText() {
        XCTAssertEqual(BPMInput.parse("   "), .failure(.empty))
    }

    func testBPMInputRejectsNonIntegerText() {
        XCTAssertEqual(BPMInput.parse("120.5"), .failure(.notAnInteger))
        XCTAssertEqual(BPMInput.parse("快一些"), .failure(.notAnInteger))
    }

    func testBPMInputRejectsOutOfRangeValues() {
        XCTAssertEqual(BPMInput.parse("19"), .failure(.outOfRange))
        XCTAssertEqual(BPMInput.parse("301"), .failure(.outOfRange))
    }

    func testMetronomeOptionsHaveDistinctSpokenDescriptions() {
        let spokenTitles = TimeSignature.presets.map(\.spokenTitle)
        XCTAssertEqual(Set(spokenTitles).count, spokenTitles.count)
        XCTAssertTrue(spokenTitles.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(TimeSignature(numerator: 4, denominator: 4).spokenTitle, "4/4 拍")
        XCTAssertEqual(TimeSignature(numerator: 6, denominator: 8).spokenTitle, "6/8 拍")

        let accentTitles = AccentMode.allCases.map(\.spokenTitle)
        XCTAssertEqual(Set(accentTitles).count, accentTitles.count)
        XCTAssertNotEqual(accentTitles[0], accentTitles[1])

        let subdivisionTitles = Subdivision.allCases.map(\.spokenTitle)
        XCTAssertEqual(Set(subdivisionTitles).count, subdivisionTitles.count)

        let countInTitles = CountInBars.allCases.map(\.spokenTitle)
        XCTAssertEqual(Set(countInTitles).count, countInTitles.count)
    }

    func testMetronomeTempoClampsAndRoundsBPM() {
        XCTAssertEqual(MetronomeTempo.clampedBPM(19), 20)
        XCTAssertEqual(MetronomeTempo.clampedBPM(120.6), 121)
        XCTAssertEqual(MetronomeTempo.clampedBPM(301), 300)
    }

    func testTapTempoClampsToValidRange() {
        var estimator = TapTempoEstimator()
        estimator.record(at: 0)
        estimator.record(at: 0.1)
        estimator.record(at: 0.2)
        estimator.record(at: 0.3)
        estimator.record(at: 0.4)
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

