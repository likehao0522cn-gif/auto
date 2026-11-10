import XCTest
@testable import TuneCore

final class InharmonicityTests: XCTestCase {

    // MARK: - Partial frequency model

    func testZeroInharmonicityGivesIdealHarmonics() {
        // With B = 0 the series must collapse to exact integer multiples.
        for n in 1...6 {
            let f = Inharmonicity.partialFrequency(fundamental: 220, partial: n, b: 0)
            XCTAssertEqual(f, 220 * Double(n), accuracy: 1e-9)
        }
    }

    func testPartialsAreRaisedByStiffness() {
        // Real strings sharpen: every partial above the first must sit above
        // its ideal harmonic position.
        let b = 0.0004
        let f1 = 110.0
        for n in 2...6 {
            let ideal = f1 * Double(n)
            let actual = Inharmonicity.partialFrequency(fundamental: f1, partial: n, b: b)
            XCTAssertGreaterThan(actual, ideal)
        }
    }

    func testHigherPartialsDeviateMore() {
        // The stretch grows with n^2, so the second partial is sharp by less
        // (in relative terms) than the sixth.
        let b = 0.0004
        let f1 = 110.0
        func relativeDeviation(_ n: Int) -> Double {
            let ideal = f1 * Double(n)
            let actual = Inharmonicity.partialFrequency(fundamental: f1, partial: n, b: b)
            return (actual - ideal) / ideal
        }
        XCTAssertLessThan(relativeDeviation(2), relativeDeviation(6))
    }

    // MARK: - Inverse (partial index)

    func testPartialIndexInvertsPartialFrequency() {
        // Locating a known partial frequency must return that partial number.
        let b = 0.00035
        let f1 = 261.625565
        for n in 1...6 {
            let f = Inharmonicity.partialFrequency(fundamental: f1, partial: n, b: b)
            let index = Inharmonicity.partialIndex(frequency: f, fundamental: f1, b: b)
            XCTAssertEqual(index, Double(n), accuracy: 1e-6)
        }
    }

    func testPartialIndexWithZeroInharmonicityIsLinear() {
        let index = Inharmonicity.partialIndex(frequency: 880, fundamental: 220, b: 0)
        XCTAssertEqual(index, 4, accuracy: 1e-9)
    }

    // MARK: - Recovering B from partials

    func testCoefficientRecoversKnownB() {
        // Generate partials from a known B and check we solve it back exactly.
        let b = 0.00021
        let f1 = 130.812783
        for n in 2...5 {
            let fn = Inharmonicity.partialFrequency(fundamental: f1, partial: n, b: b)
            let solved = Inharmonicity.coefficient(fundamental: f1, partialFrequency: fn, partial: n)
            XCTAssertNotNil(solved)
            XCTAssertEqual(solved ?? -1, b, accuracy: 1e-9)
        }
    }

    func testCoefficientRejectsPartialBelowHarmonic() {
        // A peak below the ideal harmonic position is not a physical string.
        let solved = Inharmonicity.coefficient(fundamental: 200, partialFrequency: 390, partial: 2)
        XCTAssertNil(solved)
    }

    func testCoefficientRejectsBadInput() {
        XCTAssertNil(Inharmonicity.coefficient(fundamental: 0, partialFrequency: 400, partial: 2))
        XCTAssertNil(Inharmonicity.coefficient(fundamental: 200, partialFrequency: 0, partial: 2))
        XCTAssertNil(Inharmonicity.coefficient(fundamental: 200, partialFrequency: 401, partial: 1))
    }

    func testEstimateRecoversKnownBFromCleanPartials() {
        let b = 0.0003
        let f1 = 98.0
        let partials = (1...4).map {
            Inharmonicity.partialFrequency(fundamental: f1, partial: $0, b: b)
        }
        let result = Inharmonicity.estimate(midi: 43, partials: partials)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.b ?? -1, b, accuracy: 1e-9)
        // Four agreeing partials with no spread should score high confidence.
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.9)
    }

    func testEstimateNeedsAtLeastTwoPartials() {
        XCTAssertNil(Inharmonicity.estimate(midi: 60, partials: [261.6]))
        XCTAssertNil(Inharmonicity.estimate(midi: 60, partials: []))
    }

    func testEstimateIgnoresOneWildPartial() {
        // Three good partials plus one corrupted one must still land close to
        // the true B, with reduced confidence.
        let b = 0.0004
        let f1 = 87.307057
        var partials = (1...4).map {
            Inharmonicity.partialFrequency(fundamental: f1, partial: $0, b: b)
        }
        partials[3] = partials[3] * 1.5
        let result = Inharmonicity.estimate(midi: 41, partials: partials)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.b ?? -1, b, accuracy: b * 0.25)
    }

    func testEstimateReturnsNilWhenNoPartialIsUsable() {
        // Every higher partial below its harmonic position: nothing to solve.
        let partials = [200.0, 390.0, 580.0]
        XCTAssertNil(Inharmonicity.estimate(midi: 60, partials: partials))
    }

    func testMeasurementRoundTripsThroughCodable() throws {
        let measurement = InharmonicityMeasurement(
            midi: 48,
            b: 0.00027,
            confidence: 0.83,
            partials: [130.8, 261.9, 393.4]
        )
        let data = try JSONEncoder().encode(measurement)
        let decoded = try JSONDecoder().decode(InharmonicityMeasurement.self, from: data)
        XCTAssertEqual(decoded, measurement)
    }
}
