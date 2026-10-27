import XCTest
@testable import TuneCore

final class TuningFeedbackTests: XCTestCase {
    func testInTuneUsesSingleDirection() {
        let feedback = TuningFeedback(
            noteName: "A4",
            cents: 2,
            confidence: 0.95,
            toleranceCents: 3
        )

        XCTAssertEqual(feedback.direction, .inTune)
        XCTAssertEqual(feedback.displayText, "A4，准")
    }

    func testHighAndLowDirections() {
        let high = TuningFeedback(noteName: "A4", cents: 12, confidence: 0.9, toleranceCents: 3)
        let low = TuningFeedback(noteName: "A4", cents: -12, confidence: 0.9, toleranceCents: 3)

        XCTAssertEqual(high.direction, .high)
        XCTAssertEqual(low.direction, .low)
        XCTAssertTrue(high.displayText.contains("高 12 音分"))
        XCTAssertTrue(low.displayText.contains("低 12 音分"))
    }

    func testLowConfidenceIsSpokenAsFullResult() {
        let feedback = TuningFeedback(
            noteName: "A4",
            cents: 8,
            confidence: 0.55,
            toleranceCents: 3
        )

        XCTAssertTrue(feedback.isLowConfidence)
        XCTAssertTrue(feedback.shortSpokenText.contains("请再弹一次"))
        XCTAssertTrue(feedback.displayText.contains("置信度低"))
    }

    func testDirectionAndNoteChangesRequireFullResult() {
        let previous = TuningFeedback(noteName: "A4", cents: 8, confidence: 0.9, toleranceCents: 3)
        let sameDirection = TuningFeedback(noteName: "A4", cents: 14, confidence: 0.9, toleranceCents: 3)
        let directionChange = TuningFeedback(noteName: "A4", cents: -2, confidence: 0.9, toleranceCents: 3)
        let noteChange = TuningFeedback(noteName: "A#4", cents: 8, confidence: 0.9, toleranceCents: 3)

        XCTAssertFalse(sameDirection.shouldAnnounceFullResult(comparedTo: previous))
        XCTAssertTrue(directionChange.shouldAnnounceFullResult(comparedTo: previous))
        XCTAssertTrue(noteChange.shouldAnnounceFullResult(comparedTo: previous))
    }
}
