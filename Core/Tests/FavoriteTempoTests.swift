import XCTest
@testable import TuneCore

final class FavoriteTempoTests: XCTestCase {
    private func tempo(_ bpm: Int, uses: Int = 0, seconds: Double = 0, manual: Bool = true) -> FavoriteTempo {
        FavoriteTempo(bpm: bpm, useCount: uses, totalPlaySeconds: seconds, isManual: manual)
    }

    func testSortsBySpeedAscending() {
        let list = [tempo(140), tempo(90), tempo(200)]
        let sorted = FavoriteTempoRules.sorted(list, by: .speedAscending)
        XCTAssertEqual(sorted.map(\.bpm), [90, 140, 200])
    }

    func testSortsByUseCountDescendingThenSpeed() {
        let list = [
            tempo(120, uses: 3),
            tempo(90, uses: 9),
            tempo(200, uses: 9)
        ]
        let sorted = FavoriteTempoRules.sorted(list, by: .useCountDescending)
        XCTAssertEqual(sorted.map(\.bpm), [90, 200, 120])
    }

    func testSortsByPlayTimeDescendingThenSpeed() {
        let list = [
            tempo(120, seconds: 60),
            tempo(96, seconds: 600),
            tempo(180, seconds: 600)
        ]
        let sorted = FavoriteTempoRules.sorted(list, by: .playTimeDescending)
        XCTAssertEqual(sorted.map(\.bpm), [96, 180, 120])
    }

    func testAutomaticPromotionNeedsBothCountAndTime() {
        XCTAssertFalse(FavoriteTempoRules.qualifiesForAutomaticAdd(tempo(120, uses: 5, seconds: 60)))
        XCTAssertFalse(FavoriteTempoRules.qualifiesForAutomaticAdd(tempo(120, uses: 2, seconds: 600)))
        XCTAssertFalse(FavoriteTempoRules.qualifiesForAutomaticAdd(tempo(120, uses: 4, seconds: 119)))
        XCTAssertTrue(FavoriteTempoRules.qualifiesForAutomaticAdd(tempo(120, uses: 5, seconds: 120)))
        XCTAssertTrue(FavoriteTempoRules.qualifiesForAutomaticAdd(tempo(120, uses: 12, seconds: 900)))
    }

    func testCapacityIsTen() {
        XCTAssertEqual(FavoriteTempoRules.capacity, 10)
    }

    func testPlayMinutesRoundsFromSeconds() {
        XCTAssertEqual(tempo(120, seconds: 29).playMinutes, 0)
        XCTAssertEqual(tempo(120, seconds: 90).playMinutes, 2)
        XCTAssertEqual(tempo(120, seconds: 149).playMinutes, 2)
    }
}
