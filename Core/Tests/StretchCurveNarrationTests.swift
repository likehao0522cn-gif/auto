import XCTest
@testable import TuneCore

final class StretchCurveNarrationTests: XCTestCase {

    // MARK: - Regions

    func testRegionsCoverTheWholeKeyboardWithoutOverlap() {
        let all = CurveRegion.allCases.flatMap { Array($0.midiRange) }
        XCTAssertEqual(Set(all).count, all.count, "regions must not overlap")
        XCTAssertEqual(all.min(), 21)
        XCTAssertEqual(all.max(), 108)
    }

    func testRegionTitlesAreDistinct() {
        let titles = CurveRegion.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    // MARK: - Region averages

    func testBassRegionIsNegativeOnTemplate() {
        let curve = StretchCurveBuilder.template()
        XCTAssertLessThan(StretchCurveNarration.regionCents(for: curve, region: .bass), -10)
    }

    func testTrebleRegionIsPositiveOnTemplate() {
        let curve = StretchCurveBuilder.template()
        XCTAssertGreaterThan(StretchCurveNarration.regionCents(for: curve, region: .treble), 10)
    }

    func testMiddleRegionIsNearlyZeroOnTemplate() {
        let curve = StretchCurveBuilder.template()
        XCTAssertEqual(StretchCurveNarration.regionCents(for: curve, region: .middle), 0, accuracy: 3)
    }

    func testRegionCentsOnEmptyCurveIsZero() {
        let empty = StretchCurve(cents: [:], source: "empty", isMeasured: false)
        XCTAssertEqual(StretchCurveNarration.regionCents(for: empty, region: .bass), 0)
    }

    // MARK: - Summary wording

    func testSummaryMentionsAllThreeRegions() {
        let curve = StretchCurveBuilder.template()
        let summary = StretchCurveNarration.summary(for: curve)
        XCTAssertTrue(summary.contains(CurveRegion.bass.title))
        XCTAssertTrue(summary.contains(CurveRegion.middle.title))
        XCTAssertTrue(summary.contains(CurveRegion.treble.title))
    }

    func testSummarySaysTemplateWhenNotMeasured() {
        let summary = StretchCurveNarration.summary(for: StretchCurveBuilder.template())
        XCTAssertTrue(summary.contains("\u{672A}\u{7ECF}\u{5B9E}\u{6D4B}"))
    }

    func testSummarySaysMeasuredWhenMeasured() {
        let curve = StretchCurve(cents: [69: 0], source: "m", isMeasured: true)
        let summary = StretchCurveNarration.summary(for: curve)
        XCTAssertTrue(summary.contains("\u{5B9E}\u{6D4B}"))
        XCTAssertFalse(summary.contains("\u{672A}\u{7ECF}\u{5B9E}\u{6D4B}"))
    }

    func testSummaryNeverUsesBareMinusSign() {
        // A minus sign reads badly and is easy to mishear; it must be spoken
        // as a word instead.
        let summary = StretchCurveNarration.summary(for: StretchCurveBuilder.template())
        XCTAssertFalse(summary.contains("-"))
    }

    func testSummaryContainsNoDigitsAttachedToLetters() {
        // Guards against readings like "C8-33" that run together in speech.
        let summary = StretchCurveNarration.summary(for: StretchCurveBuilder.template())
        XCTAssertFalse(summary.contains("\u{4F4E}-"))
        XCTAssertFalse(summary.contains("\u{9AD8}-"))
    }

    // MARK: - Single key

    func testKeyDescriptionForA4IsInTune() {
        let curve = StretchCurveBuilder.template()
        let text = StretchCurveNarration.keyDescription(for: curve, midi: 69)
        XCTAssertTrue(text.hasPrefix("A4"))
        XCTAssertTrue(text.contains("\u{51C6}"))
    }

    func testKeyDescriptionForLowBassSaysLow() {
        let curve = StretchCurveBuilder.template()
        let text = StretchCurveNarration.keyDescription(for: curve, midi: 21)
        XCTAssertTrue(text.hasPrefix("A0"))
        XCTAssertTrue(text.contains("\u{4F4E}"))
        XCTAssertTrue(text.contains("\u{97F3}\u{5206}"))
    }

    func testKeyDescriptionForHighTrebleSaysHigh() {
        let curve = StretchCurveBuilder.template()
        let text = StretchCurveNarration.keyDescription(for: curve, midi: 108)
        XCTAssertTrue(text.hasPrefix("C8"))
        XCTAssertTrue(text.contains("\u{9AD8}"))
    }

    func testKeyDescriptionAcceptsACustomName() {
        let curve = StretchCurveBuilder.template()
        let text = StretchCurveNarration.keyDescription(for: curve, midi: 69, noteName: "\u{6807}\u{51C6}\u{97F3}")
        XCTAssertTrue(text.hasPrefix("\u{6807}\u{51C6}\u{97F3}"))
    }

    func testKeyDescriptionForUnspecifiedKeyIsInTune() {
        // A curve that has no entry for a key falls back to zero.
        let curve = StretchCurve(cents: [:], source: "empty", isMeasured: false)
        let text = StretchCurveNarration.keyDescription(for: curve, midi: 69)
        XCTAssertTrue(text.contains("\u{51C6}"))
    }

    // MARK: - Region description

    func testRegionDescriptionNamesTheRegion() {
        let curve = StretchCurveBuilder.template()
        let text = StretchCurveNarration.regionDescription(for: curve, region: .treble)
        XCTAssertTrue(text.hasPrefix(CurveRegion.treble.title))
    }
}
