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

    func testTapTempoPublishesFirstResultAfterFourTapsThenEveryFourTaps() {
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
        XCTAssertFalse(estimator.shouldPublishResult)

        estimator.record(at: 2.5)
        XCTAssertFalse(estimator.shouldPublishResult)
        estimator.record(at: 3.0)
        XCTAssertFalse(estimator.shouldPublishResult)
        estimator.record(at: 3.5)
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

    func testAccentPattern() {
        let config = MetronomeConfiguration(
            bpm: 120,
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            accentMode: .firstBeat,
            subdivision: .two
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
            subdivision: .none
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
        XCTAssertEqual(TimeSignature(numerator: 4, denominator: 4).accessibilityTitle, "4/4 拍")
        XCTAssertEqual(TimeSignature(numerator: 6, denominator: 8).accessibilityTitle, "6/8 拍")

        let accentTitles = AccentMode.allCases.map(\.spokenTitle)
        XCTAssertEqual(Set(accentTitles).count, accentTitles.count)
        XCTAssertNotEqual(accentTitles[0], accentTitles[1])

        let subdivisionTitles = Subdivision.allCases.map(\.spokenTitle)
        XCTAssertEqual(Set(subdivisionTitles).count, subdivisionTitles.count)

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
    // MARK: - Robust tap tempo

    func testTapTempoIgnoresPauseBetweenGroups() {
        // Four taps, a long pause, then four more taps. The pause must not be
        // treated as a very slow beat; the estimate should stay near 120.
        var estimator = TapTempoEstimator()
        for beat in 0..<4 {
            estimator.record(at: Double(beat) * 0.5)
        }
        let pausedStart = 1.5 + 1.2
        for beat in 0..<4 {
            estimator.record(at: pausedStart + Double(beat) * 0.5)
        }
        XCTAssertEqual(estimator.bpm ?? 0, 120, accuracy: 6)
    }

    func testTapTempoDoesNotHalveOnOneMissedBeat() {
        // A single doubled gap must be discarded, not averaged in, so the
        // tempo never collapses toward half speed.
        var estimator = TapTempoEstimator()
        var time = 0.0
        for beat in 0..<12 {
            estimator.record(at: time)
            // Skip one beat in the middle to simulate a dropped tap.
            time += (beat == 6 ? 1.0 : 0.5)
        }
        let bpm = estimator.bpm ?? 0
        XCTAssertEqual(bpm, 120, accuracy: 6)
    }

    func testTapTempoIgnoresDoubleTap() {
        // A stray double hit must not pull the estimate up.
        var estimator = TapTempoEstimator()
        var time = 0.0
        for beat in 0..<12 {
            estimator.record(at: time)
            if beat == 6 {
                estimator.record(at: time + 0.05)
            }
            time += 0.5
        }
        XCTAssertEqual(estimator.bpm ?? 0, 120, accuracy: 6)
    }

    func testTapTempoNeedsThreeReliableIntervalsBeforeReporting() {
        // Three taps give only two intervals; the estimate stays nil until the
        // fourth tap supplies a third clean interval.
        var estimator = TapTempoEstimator()
        estimator.record(at: 0)
        estimator.record(at: 0.5)
        estimator.record(at: 1.0)
        XCTAssertNil(estimator.bpm)
        estimator.record(at: 1.5)
        XCTAssertNotNil(estimator.bpm)
        XCTAssertEqual(estimator.bpm ?? 0, 120, accuracy: 0.01)
    }

    func testTapTempoMedianIsRobustToJitter() {
        // One late tap among several should barely move the median estimate.
        var estimator = TapTempoEstimator()
        let times: [TimeInterval] = [0, 0.5, 1.0, 1.75, 2.25, 2.75, 3.25]
        for time in times {
            estimator.record(at: time)
        }
        XCTAssertEqual(estimator.bpm ?? 0, 120, accuracy: 12)
    }

    func testTapTempoReliableIntervalCountGrowsWithCleanTaps() {
        var estimator = TapTempoEstimator()
        for beat in 0..<5 {
            estimator.record(at: Double(beat) * 0.5)
        }
        XCTAssertEqual(estimator.reliableIntervalCount, 4)
    }


    func testTripletSubdivisionProducesTwelveClicksInFourFour() {
        let config = MetronomeConfiguration(
            bpm: 90,
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            accentMode: .firstBeat,
            subdivision: .three
        )
        let clicks = MetronomePattern.clicks(for: config)
        XCTAssertEqual(clicks.count, 12)
        XCTAssertEqual(clicks.filter(\.isAccent).count, 1)
    }
}

