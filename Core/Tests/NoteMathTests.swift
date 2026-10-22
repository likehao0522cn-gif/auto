import XCTest
@testable import TuneCore

final class NoteMathTests: XCTestCase {
    func testConcertA() {
        XCTAssertEqual(PitchMath.frequency(forMIDI: 69), 440, accuracy: 0.0001)
    }

    func testMiddleC() {
        XCTAssertEqual(PitchMath.frequency(forMIDI: 60), 261.625565, accuracy: 0.001)
    }

    func testFrequencyToMIDI() {
        XCTAssertEqual(PitchMath.midi(forFrequency: 440) ?? 0, 69, accuracy: 0.0001)
    }

    func testNearestNote() {
        let result = PitchMath.nearestNote(to: 440)
        XCTAssertEqual(result?.note.displayName, "A4")
        XCTAssertEqual(result?.cents ?? 999, 0, accuracy: 0.01)
    }

    func testNearestNoteFlatSide() {
        let result = PitchMath.nearestNote(to: 430)
        XCTAssertEqual(result?.note.displayName, "A4")
        XCTAssertLessThan(result?.cents ?? 0, 0)
    }

    func testNoteDisplay() {
        XCTAssertEqual(Note(midi: 60).displayName, "C4")
        XCTAssertEqual(Note(midi: 69).displayName, "A4")
        XCTAssertEqual(Note(midi: 40).displayName, "E2")
    }

    func testCentsAtSemitoneBoundary() {
        let target = PitchMath.frequency(forMIDI: 70)
        let cents = PitchMath.cents(from: target, to: 440)
        XCTAssertEqual(cents ?? 0, 100, accuracy: 0.001)
    }
}
