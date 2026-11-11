import Foundation

/// The Railsback curve: the average deviation of real piano tunings from equal
/// temperament, as a function of frequency.
///
/// O. L. Railsback measured this in 1941 and it has been the reference shape
/// for piano stretch tuning ever since: the bass is tuned flat, the treble is
/// tuned sharp, and the middle stays close to equal temperament. Commercial
/// tuning apps reproduce this same shape.
///
/// The anchors below are a digitised reading of the published average curve
/// (the version reproduced on Wikipedia as \"Railsback data (average)\"). They
/// are public reference data, not taken from any proprietary product.
public enum RailsbackTemplate {
    /// (frequency in Hz, deviation in cents) pairs, ascending by frequency.
    public static let anchors: [(hz: Double, cents: Double)] = [
        (27.50, -33.0),
        (32.70, -30.0),
        (41.20, -26.0),
        (55.00, -20.0),
        (65.41, -17.0),
        (82.41, -13.0),
        (110.00, -9.0),
        (146.83, -6.0),
        (196.00, -3.0),
        (261.63, -1.0),
        (329.63, -0.3),
        (440.00, 0.0),
        (523.25, 1.5),
        (659.26, 3.0),
        (880.00, 5.0),
        (1046.50, 7.0),
        (1318.51, 9.0),
        (1760.00, 12.5),
        (2093.00, 15.5),
        (2637.02, 19.0),
        (3520.00, 25.0),
        (4186.01, 29.5)
    ]

    /// Linearly interpolates the curve in log-frequency. Outside the anchor
    /// range the nearest end value is returned, so extrapolation never runs
    /// away.
    public static func cents(forFrequency frequency: Double) -> Double {
        guard let first = anchors.first, let last = anchors.last else { return 0 }
        guard frequency > 0 else { return 0 }
        if frequency <= first.hz { return first.cents }
        if frequency >= last.hz { return last.cents }
        for index in 0..<(anchors.count - 1) {
            let lower = anchors[index]
            let upper = anchors[index + 1]
            if frequency >= lower.hz && frequency <= upper.hz {
                let t = (log2(frequency) - log2(lower.hz)) / (log2(upper.hz) - log2(lower.hz))
                return lower.cents + t * (upper.cents - lower.cents)
            }
        }
        return last.cents
    }

    /// The expected stretch for a key.
    ///
    /// The curve is defined in key (pitch) space, not absolute frequency, so it
    /// does not move when the user changes the concert pitch. The lookup always
    /// uses the A4=440 frequency of the key; otherwise A4 would pick up a
    /// spurious stretch when concert A is not 440.
    public static func cents(forMIDI midi: Int) -> Double {
        cents(forFrequency: PitchMath.frequency(forMIDI: Double(midi), concertA: 440))
    }
}
