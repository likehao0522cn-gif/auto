import XCTest
@testable import TuneCore

final class DetectionProfileTests: XCTestCase {
    func testBowedRequiresStrongerSecondPeakThanChromatic() {
        let bowed = DetectionProfile.profile(for: .bowed)
        let chromatic = DetectionProfile.profile(for: .chromatic)
        XCTAssertGreaterThan(bowed.multiPitchRatio, chromatic.multiPitchRatio)
    }

    func testBowedAllowsMoreFrameSpread() {
        // Vibrato on a bowed string moves the pitch continuously, so a tighter
        // spread would treat every frame as unsteady and never report a note.
        let bowed = DetectionProfile.profile(for: .bowed)
        let plucked = DetectionProfile.profile(for: .plucked)
        XCTAssertGreaterThan(bowed.maximumRelativeSpread, plucked.maximumRelativeSpread)
    }

    func testBowedNeedsLessConfidenceThanPlucked() {
        let bowed = DetectionProfile.profile(for: .bowed)
        let plucked = DetectionProfile.profile(for: .plucked)
        XCTAssertLessThan(bowed.minimumConfidence, plucked.minimumConfidence)
    }

    func testBowedHasHighestNoiseFloorMultiplier() {
        let profiles = [
            DetectionProfile.profile(for: .piano),
            DetectionProfile.profile(for: .plucked),
            DetectionProfile.profile(for: .bowed),
            DetectionProfile.profile(for: .chromatic)
        ]
        let highest = profiles.map(\.noiseFloorMultiplier).max() ?? 0
        XCTAssertEqual(highest, DetectionProfile.profile(for: .bowed).noiseFloorMultiplier)
    }

    func testChromaticIsStrictestOnSecondPeaks() {
        let ratios = [
            DetectionProfile.profile(for: .piano).multiPitchRatio,
            DetectionProfile.profile(for: .plucked).multiPitchRatio,
            DetectionProfile.profile(for: .bowed).multiPitchRatio,
            DetectionProfile.profile(for: .chromatic).multiPitchRatio
        ]
        XCTAssertEqual(ratios.min(), DetectionProfile.profile(for: .chromatic).multiPitchRatio)
    }

    func testErhuUsesBowedFamily() {
        let erhu = PresetCatalog.preset(withID: "erhu")
        XCTAssertEqual(erhu?.acousticFamily, .bowed)
    }

    func testGuitarUsesPluckedFamily() {
        let guitar = PresetCatalog.preset(withID: "guitar")
        XCTAssertEqual(guitar?.acousticFamily, .plucked)
    }

    func testPianoAndChromaticMapDirectly() {
        XCTAssertEqual(PresetCatalog.preset(withID: "piano")?.acousticFamily, .piano)
        XCTAssertEqual(PresetCatalog.preset(withID: "chromatic")?.acousticFamily, .chromatic)
    }

    func testEveryPresetHasAProfile() {
        for preset in PresetCatalog.all {
            let profile = DetectionProfile.profile(for: preset.acousticFamily)
            XCTAssertGreaterThan(profile.multiPitchRatio, 0)
            XCTAssertLessThanOrEqual(profile.multiPitchRatio, 1)
            XCTAssertGreaterThan(profile.minimumConfidence, 0)
            XCTAssertLessThanOrEqual(profile.minimumConfidence, 1)
            XCTAssertGreaterThan(profile.maximumRelativeSpread, 0)
            XCTAssertGreaterThan(profile.noiseFloorMultiplier, 0)
        }
    }
}
