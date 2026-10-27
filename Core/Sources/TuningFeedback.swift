import Foundation

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

    public init(
        noteName: String,
        cents: Double,
        confidence: Double,
        toleranceCents: Double
    ) {
        self.noteName = noteName
        self.cents = cents
        self.confidence = confidence
        self.toleranceCents = toleranceCents
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

    public var displayText: String {
        var text = isInTune
            ? "\(noteName)，准"
            : "\(noteName)，\(PitchMath.formatCents(cents))"
        if isLowConfidence {
            text += "，置信度低"
        }
        return text
    }

    public var fullSpokenText: String {
        var text = "\(noteName)，\(PitchMath.formatCents(cents))"
        if isLowConfidence {
            text += "，置信度低，请再弹一次"
        }
        return text
    }

    public var shortSpokenText: String {
        if isLowConfidence {
            return fullSpokenText
        }
        return PitchMath.formatCents(cents)
    }

    public func shouldAnnounceFullResult(comparedTo previous: TuningFeedback?) -> Bool {
        guard let previous else { return true }
        return direction != previous.direction
            || noteName != previous.noteName
            || isLowConfidence
    }
}
