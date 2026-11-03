import AVFoundation
import UIKit

@MainActor
final class SpeechFeedback: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var voiceOverFinishTask: Task<Void, Never>?
    private var currentUtterance: AVSpeechUtterance?
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
        // VoiceOver announcements never touch the synthesizer, so an active
        // announcement must also count as "speaking" or the new one is posted
        // too early and its opening words get dropped.
        let wasSpeaking = synthesizer.isSpeaking || voiceOverFinishTask != nil
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
            speakWithVoiceOver(text, interrupting: wasSpeaking)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        // AVSpeechUtterance.rate is 0...1; keep the scale explicit so
        // higher user settings actually produce faster speech.
        utterance.rate = Float(min(1.0, max(0.0, settings.rate)))
        utterance.pitchMultiplier = Float(settings.pitch)
        utterance.volume = Float(settings.volume)
        // Stopping and immediately speaking can clip the first syllables.
        // Give the synthesizer one run-loop turn to finish cancelling.
        currentUtterance = utterance
        if wasSpeaking {
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.synthesizer.speak(utterance)
            }
        } else {
            synthesizer.speak(utterance)
        }
    }

    func speakWithVoiceOver(_ text: String, interrupting: Bool = false) {
        voiceOverFinishTask?.cancel()
        guard !text.isEmpty else {
            onFinish?()
            return
        }
        let announcement = NSAttributedString(
            string: text,
            attributes: [
                .accessibilitySpeechQueueAnnouncement: false,
                .accessibilitySpeechLanguage: "zh-CN"
            ]
        )
        if interrupting {
            // VoiceOver needs a moment to cancel the previous announcement;
            // posting immediately can drop the new utterance's opening words.
            let voiceOverText = text
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(60))
                guard let self else { return }
                UIAccessibility.post(
                    notification: .announcement,
                    argument: NSAttributedString(
                        string: voiceOverText,
                        attributes: [
                            .accessibilitySpeechQueueAnnouncement: false,
                            .accessibilitySpeechLanguage: "zh-CN"
                        ]
                    )
                )
                self.startVoiceOverFinishTimer(for: voiceOverText)
            }
            return
        }
        UIAccessibility.post(notification: .announcement, argument: announcement)
        startVoiceOverFinishTimer(for: text)
    }

    private func startVoiceOverFinishTimer(for text: String) {
        let estimatedDuration = min(5.0, 0.7 + Double(text.count) * 0.06)
        voiceOverFinishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(estimatedDuration))
            guard !Task.isCancelled, let self else { return }
            self.voiceOverFinishTask = nil
            self.onFinish?()
        }
    }

    func stop() {
        voiceOverFinishTask?.cancel()
        voiceOverFinishTask = nil
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // A superseded utterance must not clear the state of the newer one.
        guard utterance === currentUtterance else { return }
        currentUtterance = nil
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Cancellation is expected during interruption. Only clear the slot if
        // this was still the active utterance, and never report completion:
        // the caller already moved on to the newer result.
        if utterance === currentUtterance {
            currentUtterance = nil
        }
    }
}
