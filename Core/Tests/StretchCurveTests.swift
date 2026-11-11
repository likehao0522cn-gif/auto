import XCTest
@testable import TuneCore

final class StretchCurveTests: XCTestCase {

    // MARK: - Railsback template

    func testA4HasNoStretch() {
        XCTAssertEqual(RailsbackTemplate.cents(forMIDI: 69), 0, accuracy: 0.01)
    }

    func testBassIsFlat() {
        // The lowest key should be tuned well below equal temperament.
        XCTAssertLessThan(RailsbackTemplate.cents(forMIDI: 21), -25)
    }

    func testTrebleIsSharp() {
        // The highest key should be tuned well above equal temperament.
        XCTAssertGreaterThan(RailsbackTemplate.cents(forMIDI: 108), 20)
    }

    func testCurveIsMonotonic() {
        // A real stretch curve never doubles back.
        var previous = -Double.infinity
        for midi in 21...108 {
            let value = RailsbackTemplate.cents(forMIDI: midi)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-9, "non-monotonic at \(midi)")
            previous = value
        }
    }

    func testCurveStaysWithinPlausibleBounds() {
        // No key should need an absurd stretch.
        for midi in 21...108 {
            let value = RailsbackTemplate.cents(forMIDI: midi)
            XCTAssertGreaterThan(value, -40)
            XCTAssertLessThan(value, 40)
        }
    }

    func testOutOfRangeFrequenciesAreClamped() {
        XCTAssertEqual(RailsbackTemplate.cents(forFrequency: 5), -33, accuracy: 0.01)
        XCTAssertEqual(RailsbackTemplate.cents(forFrequency: 40000), 29.5, accuracy: 0.01)
    }

    func testTemplateAnchorIsIndependentOfConcertPitch() {
        // The stretch curve is defined in key space, so A4 is always the zero
        // point no matter what concert pitch the user selects.
        XCTAssertEqual(RailsbackTemplate.cents(forMIDI: 69), 0, accuracy: 1e-9)
        let curve = StretchCurveBuilder.template()
        XCTAssertEqual(curve.cents(forMIDI: 69), 0, accuracy: 1e-9)
    }

    // MARK: - Template curve

    func testTemplateCoversFullRange() {
        let curve = StretchCurveBuilder.template()
        XCTAssertEqual(curve.lowestMIDI, 21)
        XCTAssertEqual(curve.highestMIDI, 108)
        XCTAssertEqual(curve.cents.count, 88)
        XCTAssertFalse(curve.isMeasured)
    }

    func testTemplateMiddleIsNearZero() {
        let curve = StretchCurveBuilder.template()
        XCTAssertEqual(curve.cents(forMIDI: 69), 0, accuracy: 0.01)
        XCTAssertLessThan(abs(curve.cents(forMIDI: 60)), 3)
    }

    // MARK: - Stretched frequency

    func testStretchedFrequencyMatchesCents() {
        // The stretched frequency must be the ideal frequency shifted by exactly
        // the curve's cents value.
        let curve = StretchCurveBuilder.template()
        for midi in [21, 45, 69, 93, 108] {
            let ideal = PitchMath.frequency(forMIDI: Double(midi))
            let stretched = curve.stretchedFrequency(forMIDI: midi)
            let cents = 1200 * log2(stretched / ideal)
            XCTAssertEqual(cents, curve.cents(forMIDI: midi), accuracy: 1e-6)
        }
    }

    func testStretchedFrequencyAtA4IsUnchanged() {
        let curve = StretchCurveBuilder.template()
        XCTAssertEqual(curve.stretchedFrequency(forMIDI: 69), 440, accuracy: 0.001)
    }

    func testStretchedFrequencyRespectsConcertPitch() {
        let curve = StretchCurveBuilder.template()
        // At A4 the stretch is zero, so the stretched frequency is just the
        // chosen concert pitch.
        XCTAssertEqual(curve.stretchedFrequency(forMIDI: 69, concertA: 442), 442, accuracy: 0.001)
    }

    // MARK: - Measured curve

    func testMeasuredFallsBackToTemplateWithoutData() {
        let empty = InharmonicityProfile(measurements: [])
        let curve = StretchCurveBuilder.measured(profile: empty)
        XCTAssertFalse(curve.isMeasured)
        XCTAssertEqual(curve.cents(forMIDI: 69), 0, accuracy: 0.01)
    }

    func testMeasuredCurveStaysMonotonic() {
        // A stiff bass and soft treble should still produce a clean curve.
        let measurements = [
            InharmonicityMeasurement(midi: 33, b: 4.0e-4, confidence: 0.9, partials: []),
            InharmonicityMeasurement(midi: 45, b: 2.0e-4, confidence: 0.9, partials: []),
            InharmonicityMeasurement(midi: 57, b: 1.4e-4, confidence: 0.9, partials: []),
            InharmonicityMeasurement(midi: 69, b: 1.2e-4, confidence: 0.9, partials: []),
            InharmonicityMeasurement(midi: 81, b: 9.0e-5, confidence: 0.9, partials: []),
            InharmonicityMeasurement(midi: 93, b: 6.0e-5, confidence: 0.9, partials: [])
        ]
        let curve = StretchCurveBuilder.measured(profile: InharmonicityProfile(measurements: measurements))
        XCTAssertTrue(curve.isMeasured)
        var previous = -Double.infinity
        for midi in 21...108 {
            let value = curve.cents(forMIDI: midi)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-9, "non-monotonic at \(midi)")
            previous = value
        }
    }

    func testStifferPianoGetsMoreStretch() {
        // Halving B everywhere should reduce the stretch; doubling it should
        // increase it. The stiffness scale isolates that behaviour.
        let reference = PianoInharmonicityModel.b(forMIDI: 33)
        let soft = StretchCurveBuilder.stiffnessScale(forKey: 33, b: reference * 0.5)
        let stiff = StretchCurveBuilder.stiffnessScale(forKey: 33, b: reference * 2.0)
        XCTAssertLessThan(soft, stiff)
        XCTAssertEqual(StretchCurveBuilder.stiffnessScale(forKey: 33, b: reference), 1, accuracy: 1e-9)
    }

    func testStiffnessScaleIsBounded() {
        // Even absurd input must not blow up the curve.
        XCTAssertLessThanOrEqual(StretchCurveBuilder.stiffnessScale(forKey: 33, b: 1.0), 1.6)
        XCTAssertGreaterThanOrEqual(StretchCurveBuilder.stiffnessScale(forKey: 33, b: 1e-9), 0.6)
    }

    // MARK: - Codable

    func testCurveRoundTripsThroughCodable() throws {
        let curve = StretchCurveBuilder.template()
        let data = try JSONEncoder().encode(curve)
        let decoded = try JSONDecoder().decode(StretchCurve.self, from: data)
        XCTAssertEqual(decoded, curve)
    }
}
