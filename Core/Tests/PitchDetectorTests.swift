import XCTest
@testable import TuneCore

final class PitchDetectorTests: XCTestCase {
    private let sampleRate = 44_100.0

    private func sine(frequency: Double, count: Int = 8_192, amplitude: Float = 0.5) -> [Float] {
        (0..<count).map { index in
            amplitude * Float(sin(2 * Double.pi * frequency * Double(index) / sampleRate))
        }
    }

    func testDetectsA4() {
        let detector = PitchDetector()
        let estimate = detector.detect(samples: sine(frequency: 440), sampleRate: sampleRate)
        XCTAssertNotNil(estimate.frequency)
        XCTAssertEqual(estimate.frequency ?? 0, 440, accuracy: 0.5)
        XCTAssertTrue(estimate.isReliable)
    }

    func testDetectsLowGuitarE() {
        let detector = PitchDetector()
        let estimate = detector.detect(samples: sine(frequency: 82.4069), sampleRate: sampleRate)
        XCTAssertNotNil(estimate.frequency)
        XCTAssertEqual(estimate.frequency ?? 0, 82.4069, accuracy: 0.15)
    }

    func testDetectsHighE() {
        let detector = PitchDetector()
        let estimate = detector.detect(samples: sine(frequency: 329.6276), sampleRate: sampleRate)
        XCTAssertNotNil(estimate.frequency)
        XCTAssertEqual(estimate.frequency ?? 0, 329.6276, accuracy: 0.4)
    }

    func testSilenceReturnsNoPitch() {
        let detector = PitchDetector()
        let estimate = detector.detect(samples: [Float](repeating: 0, count: 8_192), sampleRate: sampleRate)
        XCTAssertNil(estimate.frequency)
        XCTAssertFalse(estimate.isReliable)
    }

    func testDetectsPianoA0WithLongWindow() {
        let detector = PitchDetector()
        let estimate = detector.detect(
            samples: sine(frequency: 27.5, count: 16_384, amplitude: 0.6),
            sampleRate: sampleRate
        )
        XCTAssertNotNil(estimate.frequency)
        XCTAssertEqual(estimate.frequency ?? 0, 27.5, accuracy: 0.15)
    }
}
