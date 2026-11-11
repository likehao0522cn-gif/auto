import XCTest
@testable import TuneCore

final class OverpullTests: XCTestCase {

    func testNoOverpullWhenAlreadyInTuneOrSharp() {
        XCTAssertEqual(Overpull.cents(forKey: 45, flatCents: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(Overpull.cents(forKey: 45, flatCents: -8), 0, accuracy: 1e-9)
    }

    func testNoOverpullForInvalidInput() {
        XCTAssertEqual(Overpull.cents(forKey: 45, flatCents: .nan), 0)
        XCTAssertEqual(Overpull.cents(forKey: 45, flatCents: .infinity), 0)
    }

    func testBassOverpullFraction() {
        // At the very lowest key the fraction is the bass fraction.
        XCTAssertEqual(Overpull.fraction(forKey: 21), 0.45, accuracy: 1e-9)
        XCTAssertEqual(Overpull.cents(forKey: 21, flatCents: 10), 4.5, accuracy: 1e-9)
    }

    func testTrebleOverpullFraction() {
        // At the very highest key the fraction is the treble fraction.
        XCTAssertEqual(Overpull.fraction(forKey: 108), 0.12, accuracy: 1e-9)
        XCTAssertEqual(Overpull.cents(forKey: 108, flatCents: 10), 1.2, accuracy: 1e-9)
    }

    func testOverpullDecreasesFromBassToTreble() {
        // The same flatness should produce less overpull as the key rises.
        let flat = 10.0
        let bass = Overpull.cents(forKey: 21, flatCents: flat)
        let middle = Overpull.cents(forKey: 69, flatCents: flat)
        let treble = Overpull.cents(forKey: 108, flatCents: flat)
        XCTAssertGreaterThan(bass, middle)
        XCTAssertGreaterThan(middle, treble)
    }

    func testOverpullGrowsWithFlatness() {
        let small = Overpull.cents(forKey: 45, flatCents: 5)
        let large = Overpull.cents(forKey: 45, flatCents: 20)
        XCTAssertGreaterThan(large, small)
    }

    func testOverpullIsCappedInTheBass() {
        // A huge pitch raise must not pull the lowest string arbitrarily far.
        XCTAssertEqual(Overpull.cents(forKey: 21, flatCents: 1000), 6.0, accuracy: 1e-9)
    }

    func testOverpullIsCappedInTheTreble() {
        XCTAssertEqual(Overpull.cents(forKey: 108, flatCents: 1000), 2.5, accuracy: 1e-9)
    }

    func testKeysOutsideRangeAreClamped() {
        // A key below the lowest behaves like the lowest; above the highest
        // behaves like the highest.
        XCTAssertEqual(Overpull.fraction(forKey: 0), Overpull.fraction(forKey: 21), accuracy: 1e-9)
        XCTAssertEqual(Overpull.fraction(forKey: 200), Overpull.fraction(forKey: 108), accuracy: 1e-9)
    }

    func testTargetFrequencyAddsOverpull() {
        // A4 target 440 with 10 cents flat should aim slightly above the target.
        let target = Overpull.targetFrequency(forKey: 69, stretchedTarget: 440, flatCents: 10)
        let pull = 1200 * log2(target / 440)
        XCTAssertEqual(pull, Overpull.cents(forKey: 69, flatCents: 10), accuracy: 1e-9)
        XCTAssertGreaterThan(target, 440)
    }

    func testTargetFrequencyWithNothingFlatIsTheTarget() {
        let target = Overpull.targetFrequency(forKey: 69, stretchedTarget: 440, flatCents: 0)
        XCTAssertEqual(target, 440, accuracy: 1e-9)
    }

    func testTargetFrequencyRejectsInvalidTarget() {
        XCTAssertEqual(Overpull.targetFrequency(forKey: 69, stretchedTarget: 0, flatCents: 10), 0)
    }

    func testOverpullCombinesWithStretchCurve() {
        // The overpull target should sit above the plain stretched target when
        // the string is flat, and equal it when the string is on pitch.
        let curve = StretchCurveBuilder.template()
        let stretched = curve.stretchedFrequency(forMIDI: 69)
        let flatTarget = Overpull.targetFrequency(forKey: 69, stretchedTarget: stretched, flatCents: 15)
        let onPitchTarget = Overpull.targetFrequency(forKey: 69, stretchedTarget: stretched, flatCents: 0)
        XCTAssertGreaterThan(flatTarget, stretched)
        XCTAssertEqual(onPitchTarget, stretched, accuracy: 1e-9)
        XCTAssertEqual(onPitchTarget, 440, accuracy: 1e-9)
    }
}
