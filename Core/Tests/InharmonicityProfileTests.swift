import XCTest
@testable import TuneCore

final class InharmonicityProfileTests: XCTestCase {

    private func measurement(_ midi: Int, _ b: Double, confidence: Double = 0.9) -> InharmonicityMeasurement {
        InharmonicityMeasurement(midi: midi, b: b, confidence: confidence, partials: [])
    }

    func testEmptyProfileHasNoTrustedMeasurements() {
        XCTAssertTrue(InharmonicityProfile(measurements: []).trusted.isEmpty)
    }

    func testLowConfidenceMeasurementsAreNotTrusted() {
        let profile = InharmonicityProfile(measurements: [
            measurement(33, 4e-4, confidence: 0.1),
            measurement(45, 2e-4, confidence: 0.9)
        ])
        XCTAssertEqual(profile.trusted.count, 1)
        XCTAssertEqual(profile.trusted.first?.midi, 45)
    }

    func testNonPositiveCoefficientsAreNotTrusted() {
        let profile = InharmonicityProfile(measurements: [
            measurement(33, 0),
            measurement(45, -1e-4)
        ])
        XCTAssertTrue(profile.trusted.isEmpty)
    }

    func testOrderedSortsByKey() {
        let profile = InharmonicityProfile(measurements: [
            measurement(69, 1.2e-4),
            measurement(33, 4e-4),
            measurement(45, 2e-4)
        ])
        XCTAssertEqual(profile.ordered.map(\.midi), [33, 45, 69])
    }

    func testFilledCoefficientsCoverFullRange() {
        let profile = InharmonicityProfile(measurements: [
            measurement(33, 4e-4),
            measurement(69, 1.2e-4),
            measurement(93, 6e-5)
        ])
        let filled = profile.filledCoefficients()
        XCTAssertEqual(filled.count, 88)
        XCTAssertNotNil(filled[21])
        XCTAssertNotNil(filled[108])
    }

    func testFilledCoefficientsDecreaseFromBassToTreble() {
        // ln(B) is linear in the key number, so the fill must fall from the
        // bass to the treble when the measurements do.
        let profile = InharmonicityProfile(measurements: [
            measurement(33, 4e-4),
            measurement(69, 1.2e-4),
            measurement(93, 6e-5)
        ])
        let filled = profile.filledCoefficients()
        XCTAssertGreaterThan(filled[33] ?? 0, filled[69] ?? 0)
        XCTAssertGreaterThan(filled[69] ?? 0, filled[93] ?? 0)
    }

    func testFilledCoefficientsFallBackWithTooFewMeasurements() {
        // One measurement cannot define a line; the model fills the rest.
        let profile = InharmonicityProfile(measurements: [measurement(69, 1.2e-4)])
        let filled = profile.filledCoefficients()
        XCTAssertEqual(filled[69] ?? 0, PianoInharmonicityModel.b(forMIDI: 69), accuracy: 1e-9)
    }

    func testFilledCoefficientsAreClampedToPlausibleRange() {
        let profile = InharmonicityProfile(measurements: [
            measurement(33, 0.5),
            measurement(69, 0.5)
        ])
        let filled = profile.filledCoefficients()
        for (_, value) in filled {
            XCTAssertLessThanOrEqual(value, 0.05)
            XCTAssertGreaterThanOrEqual(value, 1e-7)
        }
    }

    func testProfileRoundTripsThroughCodable() throws {
        let profile = InharmonicityProfile(
            measurements: [measurement(69, 1.2e-4)],
            name: "测试琴"
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(InharmonicityProfile.self, from: data)
        XCTAssertEqual(decoded, profile)
    }
}
