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
        XCTAssertEqual(feedback.displayText(unit: .cents), "A4， 准")
    }

    func testHighAndLowDirections() {
        let high = TuningFeedback(noteName: "A4", cents: 12, confidence: 0.9, toleranceCents: 3)
        let low = TuningFeedback(noteName: "A4", cents: -12, confidence: 0.9, toleranceCents: 3)

        XCTAssertEqual(high.direction, .high)
        XCTAssertEqual(low.direction, .low)
        XCTAssertTrue(high.displayText(unit: .cents).contains("高 12 音分"))
        XCTAssertTrue(low.displayText(unit: .cents).contains("低 12 音分"))
    }

    func testLowConfidenceIsSpokenAsFullResult() {
        let feedback = TuningFeedback(
            noteName: "A4",
            cents: 8,
            confidence: 0.55,
            toleranceCents: 3
        )

        XCTAssertTrue(feedback.isLowConfidence)
        XCTAssertTrue(feedback.shortSpokenText(unit: .cents).contains("请再弹一次"))
        XCTAssertTrue(feedback.displayText(unit: .cents).contains("置信度低"))
    }

    func testHertzModeShowsMeasuredFrequencyAndTarget() {
        let feedback = TuningFeedback(
            noteName: "A4",
            cents: -12,
            confidence: 0.9,
            toleranceCents: 3,
            frequency: 436.5,
            targetFrequency: 440.0
        )

        let text = feedback.displayText(unit: .hertz)
        XCTAssertTrue(text.contains("436.5 赫兹"))
        XCTAssertTrue(text.contains("440.0 赫兹"))
    }

    func testSpokenAndDisplayedTextShareTheSameUnit() {
        let feedback = TuningFeedback(
            noteName: "A4",
            cents: -12,
            confidence: 0.9,
            toleranceCents: 3,
            frequency: 436.5,
            targetFrequency: 440.0
        )

        // The spoken text is derived from the displayed text, so the two must
        // agree on which unit is being reported.
        XCTAssertTrue(feedback.fullSpokenText(unit: .hertz).contains("赫兹"))
        XCTAssertFalse(feedback.fullSpokenText(unit: .hertz).contains("音分"))
        XCTAssertTrue(feedback.fullSpokenText(unit: .cents).contains("音分"))
    }

    func testResultLineSeparatesNoteNameFromValue() {
        let feedback = TuningFeedback(
            noteName: "C7",
            cents: 12,
            confidence: 0.9,
            toleranceCents: 3,
            frequency: 2_093.0,
            targetFrequency: 2_093.0
        )

        // A space after the comma stops Chinese TTS from running the octave
        // digit straight into the frequency.
        let text = feedback.displayText(unit: .hertz)
        XCTAssertTrue(text.hasPrefix("C7， 2"), text)
    }

    func testFullSpokenTextAcceptsSpeechSafeName() {
        let feedback = TuningFeedback(
            noteName: "C#4",
            cents: -5,
            confidence: 0.9,
            toleranceCents: 3
        )

        let spoken = feedback.fullSpokenText(unit: .cents, name: "升C四")
        XCTAssertTrue(spoken.hasPrefix("升C四， "), spoken)
        // The display form keeps the compact ASCII name.
        XCTAssertTrue(feedback.displayText(unit: .cents).hasPrefix("C#4， "))
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
