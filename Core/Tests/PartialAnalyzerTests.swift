import XCTest
@testable import TuneCore

final class PartialAnalyzerTests: XCTestCase {

    /// Synthesises a plucked string with the given fundamental and
    /// inharmonicity, using a few decaying partials plus a little noise.
    private func makeString(
        fundamental: Double,
        b: Double,
        sampleRate: Double = 48000,
        seconds: Double = 0.35,
        seed: UInt64 = 1
    ) -> [Float] {
        let count = Int(sampleRate * seconds)
        var samples = [Double](repeating: 0, count: count)
        let amplitudes = [1.0, 0.6, 0.4, 0.25, 0.15]
        for n in 1...5 {
            let frequency = Inharmonicity.partialFrequency(
                fundamental: fundamental,
                partial: n,
                b: b
            )
            for index in 0..<count {
                let phase = 2 * Double.pi * frequency * Double(index) / sampleRate
                samples[index] += amplitudes[n - 1] * sin(phase)
            }
        }
        var state = seed
        for index in 0..<count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let noise = Double(state >> 33) / Double(UInt32.max) * 2 - 1
            samples[index] += 0.02 * noise
        }
        return samples.map { Float($0) }
    }

    func testFindsFundamental() {
        let samples = makeString(fundamental: 220, b: 1.5e-4)
        let result = PartialAnalyzer.measure(samples: samples, sampleRate: 48000, expectedF1: 220)
        XCTAssertGreaterThanOrEqual(result.partials.count, 3)
        XCTAssertEqual(result.partials.first ?? 0, 220, accuracy: 1.0)
    }

    func testPartialErrorsAreTiny() {
        // The Hann window must keep every partial within a cent or so; a raw
        // rectangular window would push the estimate off by tens of percent in
        // the derived coefficient.
        for (fundamental, b) in [(110.0, 3.0e-4), (220.0, 1.5e-4), (440.0, 8.0e-5)] {
            let samples = makeString(fundamental: fundamental, b: b)
            let result = PartialAnalyzer.measure(
                samples: samples, sampleRate: 48000, expectedF1: fundamental, initialB: b
            )
            for (index, measured) in result.partials.enumerated() {
                let n = index + 1
                let ideal = Inharmonicity.partialFrequency(fundamental: fundamental, partial: n, b: b)
                let cents = 1200 * log2(measured / ideal)
                XCTAssertEqual(cents, 0, accuracy: 2.0, "partial \(n) of \(fundamental) Hz")
            }
        }
    }

    func testRecoveredCoefficientIsClose() {
        // With the window applied, the coefficient should land within about a
        // tenth of the true value.
        for (fundamental, b) in [(110.0, 3.0e-4), (220.0, 1.5e-4)] {
            let samples = makeString(fundamental: fundamental, b: b)
            let measurement = Inharmonicity.measure(
                midi: 60, samples: samples, sampleRate: 48000, expectedF1: fundamental, initialB: b
            )
            XCTAssertNotNil(measurement)
            XCTAssertEqual(measurement?.b ?? 0, b, accuracy: b * 0.15, "\(fundamental) Hz")
        }
    }

    func testMeasurementCarriesPartialsAndConfidence() {
        let samples = makeString(fundamental: 220, b: 1.5e-4)
        let measurement = Inharmonicity.measure(
            midi: 57, samples: samples, sampleRate: 48000, expectedF1: 220, initialB: 1.5e-4
        )
        XCTAssertEqual(measurement?.midi, 57)
        XCTAssertGreaterThanOrEqual(measurement?.partials.count ?? 0, 3)
        XCTAssertGreaterThan(measurement?.confidence ?? 0, 0.3)
        XCTAssertLessThanOrEqual(measurement?.confidence ?? 1, 1.0)
    }

    func testTooFewSamplesReturnsNothing() {
        let result = PartialAnalyzer.measure(
            samples: [0, 0, 0], sampleRate: 48000, expectedF1: 220
        )
        XCTAssertTrue(result.partials.isEmpty)
    }

    func testInvalidInputReturnsNothing() {
        let silence = [Float](repeating: 0, count: 4096)
        XCTAssertTrue(PartialAnalyzer.measure(samples: silence, sampleRate: 48000, expectedF1: 0).partials.isEmpty)
        XCTAssertTrue(PartialAnalyzer.measure(samples: silence, sampleRate: 0, expectedF1: 220).partials.isEmpty)
    }

    func testGoertzelRejectsInvalidParameters() {
        XCTAssertEqual(PartialAnalyzer.goertzel([], sampleRate: 48000, frequency: 440), 0)
        XCTAssertEqual(PartialAnalyzer.goertzel([1, 2, 3], sampleRate: 0, frequency: 440), 0)
        XCTAssertEqual(PartialAnalyzer.goertzel([1, 2, 3], sampleRate: 48000, frequency: 0), 0)
    }

    func testGoertzelIsLargerAtTheTone() {
        // A 440 Hz tone must score higher at 440 than far off.
        let samples = (0..<48000).map { Float(sin(2 * Double.pi * 440 * Double($0) / 48000)) }
        let onTone = PartialAnalyzer.goertzel(samples.map { Double($0) }, sampleRate: 48000, frequency: 440)
        let offTone = PartialAnalyzer.goertzel(samples.map { Double($0) }, sampleRate: 48000, frequency: 415)
        XCTAssertGreaterThan(onTone, offTone * 4)
    }
}
