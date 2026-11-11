import Foundation

/// Which part of the keyboard a stretch value belongs to. Used to describe a
/// curve in words, because a blind user cannot read the plotted line.
public enum CurveRegion: String, CaseIterable, Identifiable, Sendable {
    case bass
    case middle
    case treble

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bass: return "低音区"
        case .middle: return "中音区"
        case .treble: return "高音区"
        }
    }

    /// Inclusive MIDI range for the region. The splits follow the usual piano
    /// sections: bass through B2, middle C3 through B5, treble C6 upward.
    public var midiRange: ClosedRange<Int> {
        switch self {
        case .bass: return 21...47
        case .middle: return 48...83
        case .treble: return 84...108
        }
    }
}

/// Turns a stretch curve into speech.
///
/// A curve is a line on a chart. For a blind user that is unusable, so every
/// curve must have a spoken form. The wording here is deliberately short and
/// concrete: how far the bass sits below standard, how far the treble sits
/// above it, and whether the middle is close to standard. Numbers are spoken
/// as “low 33 cents” rather than “minus 33”, because a bare minus sign reads
/// poorly and is easy to mishear.
public enum StretchCurveNarration {

    /// One-line summary of the whole curve, suitable for the first time a
    /// screen is opened or a curve is selected.
    public static func summary(for curve: StretchCurve) -> String {
        let bass = regionCents(for: curve, region: .bass)
        let middle = regionCents(for: curve, region: .middle)
        let treble = regionCents(for: curve, region: .treble)
        var parts: [String] = []
        parts.append(describe(bass, subject: "低音区"))
        parts.append(describe(middle, subject: "中音区"))
        parts.append(describe(treble, subject: "高音区"))
        var text = parts.joined(separator: "，")
        if curve.isMeasured {
            text += "。依据实测"
        } else {
            text += "。通用模板，未经实测"
        }
        return text
    }

    /// Description of one region on its own.
    public static func regionDescription(for curve: StretchCurve, region: CurveRegion) -> String {
        describe(regionCents(for: curve, region: region), subject: region.title)
    }

    /// Description of a single key, for stepping through the curve key by key.
    public static func keyDescription(
        for curve: StretchCurve,
        midi: Int,
        noteName: String? = nil
    ) -> String {
        let name = noteName ?? Note(midi: midi).displayName
        let cents = curve.cents(forMIDI: midi)
        return "\(name)，\(spokenCents(cents))"
    }

    /// Rounded, region-averaged deviation in cents.
    public static func regionCents(for curve: StretchCurve, region: CurveRegion) -> Double {
        let values = region.midiRange.compactMap { key -> Double? in
            curve.cents[key].map { $0 }
        }
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return total / Double(values.count)
    }

    /// Builds a phrase such as “low 33 cents” or “close to standard”.
    private static func describe(_ cents: Double, subject: String) -> String {
        let rounded = Int(cents.rounded())
        if abs(rounded) <= 1 {
            return "\(subject)接近标准"
        }
        if rounded < 0 {
            return "\(subject)低 \(abs(rounded)) 音分"
        }
        return "\(subject)高 \(rounded) 音分"
    }

    /// Spoken form of a single deviation.
    private static func spokenCents(_ cents: Double) -> String {
        let rounded = Int(cents.rounded())
        if rounded == 0 {
            return "准"
        }
        if rounded < 0 {
            return "比标准低 \(abs(rounded)) 音分"
        }
        return "比标准高 \(rounded) 音分"
    }
}
