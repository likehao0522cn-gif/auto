import AVFoundation
import UIKit

@MainActor
final class SpeechFeedback: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var voiceOverFinishTask: Task<Void, Never>?
    var onFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(
        _ text: String,
        language: String = "zh-CN",
        settings: SpeechSettings? = nil
    ) {
        let settings = settings ?? SpeechSettings.load()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        voiceOverFinishTask?.cancel()
        voiceOverFinishTask = nil
        let shouldUseVoiceOver: Bool
        switch settings.outputMode {
        case .appVoice:
            shouldUseVoiceOver = false
        case .automatic:
            shouldUseVoiceOver = UIAccessibility.isVoiceOverRunning
        case .voiceOver:
            shouldUseVoiceOver = UIAccessibility.isVoiceOverRunning
        }
        if shouldUseVoiceOver {
            speakWithVoiceOver(text)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = Float(settings.rate)
        utterance.pitchMultiplier = Float(settings.pitch)
        utterance.volume = Float(settings.volume)
        synthesizer.speak(utterance)
    }

    func speakWithVoiceOver(_ text: String) {
        voiceOverFinishTask?.cancel()
        guard !text.isEmpty else {
            onFinish?()
            return
        }
        UIAccessibility.post(notification: .announcement, argument: text)
        let estimatedDuration = min(5.0, 0.7 + Double(text.count) * 0.06)
        voiceOverFinishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(estimatedDuration))
            guard !Task.isCancelled else { return }
            self?.onFinish?()
        }
    }

    func stop() {
        voiceOverFinishTask?.cancel()
        voiceOverFinishTask = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
