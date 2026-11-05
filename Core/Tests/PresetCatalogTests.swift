import XCTest
@testable import TuneCore

final class PresetCatalogTests: XCTestCase {
    func testPresetList() {
        XCTAssertEqual(PresetCatalog.all.count, 9)
        // Piano leads because it is the most common use; the free-pitch mode
        // sits last as a fallback for instruments not listed here.
        XCTAssertEqual(PresetCatalog.all.map(\.id), [
            "piano", "guitar", "ukulele", "violin", "cello",
            "erhu", "guzheng", "pipa", "chromatic"
        ])
    }

    func testChromaticModeIsNamedForItsPurpose() {
        // "半音模式" was jargon; the label now says what the option does.
        XCTAssertEqual(PresetCatalog.chromatic.displayName, "任意音高")
    }

    func testGuitarStandardTuning() {
        let notes = PresetCatalog.guitar.strings.map(\.note.displayName)
        XCTAssertEqual(notes, ["E2", "A2", "D3", "G3", "B3", "E4"])
    }

    func testGuitarStringLabels() {
        let labels = PresetCatalog.guitar.strings.map(\.numberLabel)
        XCTAssertEqual(labels, ["六弦", "五弦", "四弦", "三弦", "二弦", "一弦"])
    }

    func testUkuleleStandardTuning() {
        let notes = PresetCatalog.ukulele.strings.map(\.note.displayName)
        XCTAssertEqual(notes, ["G4", "C4", "E4", "A4"])
    }

    func testErhuTuning() {
        XCTAssertEqual(PresetCatalog.erhu.strings.map(\.note.displayName), ["D4", "A4"])
    }

    func testGuzhengRange() {
        XCTAssertEqual(PresetCatalog.guzheng.strings.count, 21)
        XCTAssertEqual(PresetCatalog.guzheng.strings.first?.note.displayName, "D2")
        XCTAssertEqual(PresetCatalog.guzheng.strings.last?.note.displayName, "D6")
    }

    func testPipaTuning() {
        XCTAssertEqual(PresetCatalog.pipa.strings.map(\.note.displayName), ["A2", "D3", "E3", "A3"])
    }

    func testPianoPresetUsesAutomaticDetection() {
        XCTAssertTrue(PresetCatalog.piano.isPiano)
        XCTAssertEqual(PresetCatalog.piano.defaultMode, .automatic)
    }
}
