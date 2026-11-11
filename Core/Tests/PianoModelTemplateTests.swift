import XCTest
@testable import TuneCore

final class PianoModelTemplateTests: XCTestCase {

    func testAllTemplatesHaveDistinctIdentifiers() {
        let ids = PianoModelTemplate.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertFalse(ids.isEmpty)
    }

    func testAllTemplatesHaveSpokenDescriptions() {
        // A blind user relies entirely on the spoken description, so it must
        // exist and be distinct for every template.
        let spoken = PianoModelTemplate.all.map(\.spokenDescription)
        XCTAssertTrue(spoken.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(Set(spoken).count, spoken.count)
    }

    func testLookupByID() {
        XCTAssertEqual(PianoModelTemplate.template(withID: "grand")?.displayName, "\u{4E09}\u{89D2}\u{7434}")
        XCTAssertNil(PianoModelTemplate.template(withID: "missing"))
    }

    func testSmallUprightIsMoreInharmonicThanGrand() {
        // Shorter strings are stiffer, so a small upright must have a larger B
        // than a grand at every key.
        let small = PianoModelTemplate.smallUpright
        let grand = PianoModelTemplate.grand
        for midi in [21, 45, 69, 93, 108] {
            XCTAssertGreaterThan(small.b(forMIDI: midi), grand.b(forMIDI: midi))
        }
    }

    func testInharmonicityFallsFromBassToTreble() {
        for model in PianoModelTemplate.all {
            XCTAssertGreaterThan(model.b(forMIDI: 21), model.b(forMIDI: 69))
            XCTAssertGreaterThan(model.b(forMIDI: 69), model.b(forMIDI: 108))
        }
    }

    func testTemplateInharmonicityIsClamped() {
        for model in PianoModelTemplate.all {
            for midi in 21...108 {
                let b = model.b(forMIDI: midi)
                XCTAssertGreaterThan(b, 0)
                XCTAssertLessThanOrEqual(b, 0.05)
            }
        }
    }

    // MARK: - Curves built from templates

    func testTemplateCurveCoversFullRangeAndIsNotMeasured() {
        let curve = StretchCurveBuilder.template(for: .grand)
        XCTAssertEqual(curve.lowestMIDI, 21)
        XCTAssertEqual(curve.highestMIDI, 108)
        XCTAssertEqual(curve.cents.count, 88)
        XCTAssertFalse(curve.isMeasured)
        XCTAssertEqual(curve.source, "\u{4E09}\u{89D2}\u{7434}")
    }

    func testTemplateCurvesAnchoredAtA4() {
        // The template scales the Railsback shape, whose zero point is A4, so
        // A4 must stay at zero for every model.
        for model in PianoModelTemplate.all {
            let curve = StretchCurveBuilder.template(for: model)
            XCTAssertEqual(curve.cents(forMIDI: 69), 0, accuracy: 1e-9)
        }
    }

    func testTemplateCurveStaysMonotonic() {
        for model in PianoModelTemplate.all {
            let curve = StretchCurveBuilder.template(for: model)
            var previous = -Double.infinity
            for midi in 21...108 {
                let value = curve.cents(forMIDI: midi)
                XCTAssertGreaterThanOrEqual(value, previous - 1e-9, "non-monotonic at \(midi) for \(model.id)")
                previous = value
            }
        }
    }

    func testSmallUprightStretchesWiderThanGrand() {
        // The whole point of the templates: a small upright needs a wider
        // stretch than a grand at both ends of the keyboard.
        let small = StretchCurveBuilder.template(for: .smallUpright)
        let grand = StretchCurveBuilder.template(for: .grand)
        XCTAssertLessThan(small.cents(forMIDI: 21), grand.cents(forMIDI: 21))
        XCTAssertGreaterThan(small.cents(forMIDI: 108), grand.cents(forMIDI: 108))
    }

    func testTemplateCurveStretchStaysWithinPlausibleBounds() {
        for model in PianoModelTemplate.all {
            let curve = StretchCurveBuilder.template(for: model)
            for midi in 21...108 {
                let value = curve.cents(forMIDI: midi)
                XCTAssertGreaterThan(value, -45)
                XCTAssertLessThan(value, 45)
            }
        }
    }
}
