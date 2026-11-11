import Foundation

/// A set of inharmonicity measurements across the keyboard for one piano.
/// Sparse measurements are filled by log-linear regression of ln(B) on the key
/// number, which tracks how B falls from the bass to the treble.
public struct InharmonicityProfile: Equatable, Codable, Sendable {
    public let measurements: [InharmonicityMeasurement]
    public let name: String?

    public init(measurements: [InharmonicityMeasurement], name: String? = nil) {
        self.measurements = measurements
        self.name = name
    }

    public var isEmpty: Bool { measurements.isEmpty }

    public var ordered: [InharmonicityMeasurement] {
        measurements.sorted { $0.midi < $1.midi }
    }

    /// Measurements with a positive coefficient and at least moderate
    /// confidence. The rest are treated as noise and ignored by the fit.
    public var trusted: [InharmonicityMeasurement] {
        measurements.filter { $0.b > 0 && $0.confidence >= 0.3 }
    }

    /// Fits ln(B) = intercept + slope * midi over the trusted measurements and
    /// evaluates it for every key in the range. Falls back to the default model
    /// when there is not enough data to fit a line.
    public func filledCoefficients(
        lowestMIDI: Int = 21,
        highestMIDI: Int = 108
    ) -> [Int: Double] {
        var result: [Int: Double] = [:]
        let points = trusted
        if points.count >= 2 {
            let n = Double(points.count)
            var sx = 0.0
            var sy = 0.0
            var sxx = 0.0
            var sxy = 0.0
            for m in points {
                let x = Double(m.midi)
                let y = log(m.b)
                sx += x
                sy += y
                sxx += x * x
                sxy += x * y
            }
            let denom = n * sxx - sx * sx
            if abs(denom) > 1e-9 {
                let slope = (n * sxy - sx * sy) / denom
                let intercept = (sxx * sy - sx * sxy) / denom
                for k in lowestMIDI...highestMIDI {
                    result[k] = Self.clamp(exp(intercept + slope * Double(k)))
                }
                return result
            }
        }
        for k in lowestMIDI...highestMIDI {
            result[k] = Self.clamp(PianoInharmonicityModel.b(forMIDI: k))
        }
        return result
    }

    /// Keeps a fitted coefficient inside physically plausible bounds so a bad
    /// extrapolation cannot produce an absurd stretch.
    private static func clamp(_ b: Double) -> Double {
        guard b.isFinite, b > 0 else { return 1e-4 }
        return min(0.05, max(1e-7, b))
    }
}
