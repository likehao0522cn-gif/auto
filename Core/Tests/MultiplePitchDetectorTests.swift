import XCTest
@testable import TuneCore

final class MultiplePitchDetectorTests: XCTestCase {
    private let sampleRate = 44_100.0

    private func sine(_ frequency: Double, count: Int = 4_096) -> [Float] {
        (0..<count).map { index in
            Float(sin(2 * Double.pi * frequency * Double(index) / sampleRate) * 0.4)
        }
    }

    func testSingleSineIsNotMultiplePitches() {
        let samples = sine(440)
        let result = MultiplePitchDetector.detect(
            samples: samples,
            sampleRate: sampleRate,
            primaryFrequency: 440,
            primaryConfidence: 0.95,
            rms: 0.28
        )

        XCTAssertFalse(result.isMultiplePitches)
    }

    func testHarmonicRichToneIsNotMultiplePitches() {
        let samples = (0..<4_096).map { index in
            let time = Double(index) / sampleRate
            return Float(
                sin(2 * Double.pi * 220 * time) * 0.25
                + sin(2 * Double.pi * 440 * time) * 0.2
                + sin(2 * Double.pi * 660 * time) * 0.15
            )
        }
        let result = MultiplePitchDetector.detect(
            samples: samples,
            sampleRate: sampleRate,
            primaryFrequency: 220,
            primaryConfidence: 0.9,
            rms: 0.3
        )

        XCTAssertFalse(result.isMultiplePitches)
    }

    func testHarmonicOfPrimaryIsNotMultiplePitches() {
        let samples = (0..<4_096).map { index in
            let time = Double(index) / sampleRate
            return Float(
                sin(2 * Double.pi * 220 * time) * 0.3
                + sin(2 * Double.pi * 440 * time) * 0.3
            )
        }
        let result = MultiplePitchDetector.detect(
            samples: samples,
            sampleRate: sampleRate,
            primaryFrequency: 220,
            primaryConfidence: 0.9,
            rms: 0.3
        )

        XCTAssertFalse(result.isMultiplePitches)
    }

    func testTwoIndependentSinesAreReportedAsMultiplePitches() {
        let samples = (0..<4_096).map { index in
            let time = Double(index) / sampleRate
            return Float(
                sin(2 * Double.pi * 220 * time) * 0.3
                + sin(2 * Double.pi * 311 * time) * 0.3
            )
        }
        let result = MultiplePitchDetector.detect(
            samples: samples,
            sampleRate: sampleRate,
            primaryFrequency: 220,
            primaryConfidence: 0.9,
            rms: 0.3
        )

        XCTAssertTrue(result.isMultiplePitches)
    }

    func testLowConfidenceIsNotReportedAsMultiplePitches() {
        let result = MultiplePitchDetector.detect(
            samples: sine(440),
            sampleRate: sampleRate,
            primaryFrequency: 440,
            primaryConfidence: 0.2,
            rms: 0.3
        )

        XCTAssertFalse(result.isMultiplePitches)
    }

    func testDetectionIsFastEnoughForStableResultUse() {
        let samples = (0..<4_096).map { index in
            let time = Double(index) / sampleRate
            return Float(
                sin(2 * Double.pi * 220 * time) * 0.3
                + sin(2 * Double.pi * 311 * time) * 0.3
            )
        }

        let start = Date()
        _ = MultiplePitchDetector.detect(
            samples: samples,
            sampleRate: sampleRate,
            primaryFrequency: 220,
            primaryConfidence: 0.9,
            rms: 0.3
        )
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0)
    }
}
