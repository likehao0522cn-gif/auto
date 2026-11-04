import Foundation

/// How tuning deviation is presented. The same value drives both the screen
/// text and the spoken text so the two can never drift apart.
public enum TuningDisplayUnit: String, CaseIterable, Identifiable, Sendable {
    case cents
    case hertz

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cents: return "音分"
        case .hertz: return "赫兹"
        }
    }

    public var spokenTitle: String {
        switch self {
        case .cents: return "音分，显示相对目标音的偏差"
        case .hertz: return "赫兹，显示实测频率"
        }
    }
}

public enum TuningDirection: Equatable, Sendable {
    case low
    case inTune
    case high
}

public struct TuningFeedback: Equatable, Sendable {
    public static let lowConfidenceThreshold = 0.7

    public let noteName: String
    public let cents: Double
    public let confidence: Double
    public let toleranceCents: Double
    /// Measured pitch, used when the user chooses hertz display.
    public let frequency: Double
    /// Target pitch for the reported note, used in hertz display.
    public let targetFrequency: Double

    public init(
        noteName: String,
        cents: Double,
        confidence: Double,
        toleranceCents: Double,
        frequency: Double = 0,
        targetFrequency: Double = 0
    ) {
        self.noteName = noteName
        self.cents = cents
        self.confidence = confidence
        self.toleranceCents = toleranceCents
        self.frequency = frequency
        self.targetFrequency = targetFrequency
    }

    public var isInTune: Bool {
        abs(cents) <= toleranceCents
    }

    public var isLowConfidence: Bool {
        confidence < Self.lowConfidenceThreshold
    }

    public var direction: TuningDirection {
        if isInTune { return .inTune }
        return cents > 0 ? .high : .low
    }

    /// Single source of truth for wording. Screen text and spoken text are
    /// both derived from this, so they can never drift apart.
    public func resultText(unit: TuningDisplayUnit) -> String {
        switch unit {
        case .cents:
            return isInTune ? "准" : PitchMath.formatCents(cents)
        case .hertz:
            return String(format: "%.1f 赫兹", frequency)
        }
    }

    public func displayText(unit: TuningDisplayUnit) -> String {
        var text = "\(noteName)，\(resultText(unit: unit))"
        if unit == .hertz, targetFrequency > 0 {
            text += "，目标 \(String(format: "%.1f", targetFrequency)) 赫兹"
        }
        if isLowConfidence {
            text += "，置信度低"
        }
        return text
    }

    public func fullSpokenText(unit: TuningDisplayUnit) -> String {
        var text = displayText(unit: unit)
        if isLowConfidence {
            text += "，请再弹一次"
        }
        return text
    }

    public func shortSpokenText(unit: TuningDisplayUnit) -> String {
        if isLowConfidence {
            return fullSpokenText(unit: unit)
        }
        return resultText(unit: unit)
    }

    public func shouldAnnounceFullResult(comparedTo previous: TuningFeedback?) -> Bool {
        guard let previous else { return true }
        return direction != previous.direction
            || noteName != previous.noteName
            || isLowConfidence
    }
}
