import AVFoundation
import Foundation
import TuneCore

/// Curve-based tuning for a piano, one key at a time.
///
/// Unlike the general tuner, the target here is not equal temperament: it is
/// the selected stretch curve's frequency for the key, optionally pushed past
/// the target by the overpull amount when the string is flat. The user plays a
/// string, the app reports how far off it is, and the estimate is spoken in
/// words.
@MainActor
final class PianoTuningViewModel: ObservableObject {
    /// How a key currently reads.
    enum Verdict: Equatable {
        case waiting
        case tooFlat(Double)   // cents below target
        case tooSharp(Double)  // cents above target
        case inTune(Double)    // cents, within tolerance
        case uncertain
    }

    @Published private(set) var verdict: Verdict = .waiting
    @Published private(set) var isListening = false
    @Published private(set) var errorMessage: String?
    @Published var selectedMIDI: Int = 69
    @Published var useOverpull: Bool = true

    /// Tolerance in cents for calling a string in tune.
    var toleranceCents: Double = 3

    private let audioEngine = TunerAudioEngine()
    private let speech = SpeechFeedback()
    private var lastSpokenVerdict: String?
    private var lastSoundAt: Date?

    /// True while our own voice is playing. The phone's speaker leaks straight
    /// back into the microphone, and at that point the analyser would happily
    /// report our announcement as if it were a piano string. While this is set,
    /// only a much louder frame counts as a string, and nothing is spoken again
    /// until the current sentence ends.
    private var isSpeaking = false

    var noteName: String { Note(midi: selectedMIDI).displayName }

    var canStart: Bool { !isListening }

    /// Frequency of the key under the curve, before any overpull.
    func targetFrequency(curve: StretchCurve, concertA: Double = 440) -> Double {
        curve.stretchedFrequency(forMIDI: selectedMIDI, concertA: concertA)
    }

    /// Frequency to aim for right now: the curve target plus overpull when the
    /// string is flat and overpull is enabled.
    func aimingFrequency(curve: StretchCurve, concertA: Double = 440) -> Double {
        let target = targetFrequency(curve: curve, concertA: concertA)
        guard useOverpull else { return target }
        let flatCents = flatnessCents(from: verdict)
        guard flatCents > 0 else { return target }
        return Overpull.targetFrequency(forKey: selectedMIDI, stretchedTarget: target, flatCents: flatCents)
    }

    func start(curve: StretchCurve, settings: SpeechSettings) {
        guard !isListening else { return }
        errorMessage = nil
        verdict = .waiting
        do {
            speech.onFinish = { [weak self] in
                self?.finishSpeaking(settings: settings)
            }
            try audioEngine.start { [weak self] estimate, _, _ in
                self?.handle(estimate: estimate, curve: curve)
            }
            isListening = true
            speak("开始调律 \(noteName)", settings: settings)
        } catch {
            isListening = false
            errorMessage = TunerAudioEngineError.chineseMessage(for: error)
            speech.speak("麦克风无法开启", settings: settings)
        }
    }

    func stop(settings: SpeechSettings) {
        speech.stop()
        audioEngine.stop()
        isListening = false
        isSpeaking = false
        lastSpokenVerdict = nil
        lastSoundAt = nil
        verdict = .waiting
        let _ = settings
    }

    /// Spoken form of the current verdict.
    func spokenVerdict() -> String {
        switch verdict {
        case .waiting:
            return "等待弹奏 \(noteName)"
        case .inTune:
            return "\(noteName) 准了"
        case .tooFlat(let cents):
            return "\(noteName) 偏低 \(Int(cents.rounded())) 音分"
        case .tooSharp(let cents):
            return "\(noteName) 偏高 \(Int(cents.rounded())) 音分"
        case .uncertain:
            return "信号不清，请再弹一次"
        }
    }

    /// Minimum level to treat a frame as a struck string.
    private static let quietThreshold: Double = 0.006

    /// While our own voice is playing, only a much louder sound can be a real
    /// string. The speaker re-enters the microphone at a modest level, so a
    /// piano note right after an announcement still clears this bar while the
    /// announcement itself does not.
    private static let speechThreshold: Double = 0.05

    private func handle(estimate: PitchEstimate, curve: StretchCurve) {
        guard isListening else { return }

        let now = Date()
        let threshold = isSpeaking ? Self.speechThreshold : Self.quietThreshold

        guard let frequency = estimate.frequency,
              estimate.confidence >= 0.6,
              estimate.rms >= threshold else {
            // While we are talking, silence means "our voice is playing", not
            // "the user stopped". Keep the previous reading on screen.
            if !isSpeaking {
                let silence = lastSoundAt.map { now.timeIntervalSince($0) } ?? .infinity
                if silence >= 0.35 { verdict = .waiting }
            }
            return
        }
        lastSoundAt = now

        let target = targetFrequency(curve: curve)
        guard target > 0, let cents = PitchMath.cents(from: frequency, to: target) else {
            verdict = .uncertain
            return
        }

        if abs(cents) <= toleranceCents {
            verdict = .inTune(cents)
        } else if cents < 0 {
            verdict = .tooFlat(-cents)
        } else {
            verdict = .tooSharp(cents)
        }
    }

    /// Announces the verdict once, and only when it changes, so the user is not
    /// talked over while adjusting.
    ///
    /// While our own voice is still playing, the verdict is recorded but not
    /// spoken. Otherwise a reading taken during an announcement would trigger
    /// another announcement, and the two would feed each other.
    func announceIfChanged(settings: SpeechSettings) {
        let text = spokenVerdict()
        guard text != lastSpokenVerdict else { return }
        lastSpokenVerdict = text

        guard !isSpeaking else { return }
        guard case .waiting = verdict else {
            speak(text, settings: settings)
            return
        }
    }

    /// Speaks and marks the microphone as busy for the duration.
    private func speak(_ text: String, settings: SpeechSettings) {
        isSpeaking = true
        speech.speak(text, settings: settings)
    }

    /// Called when our voice finishes.
    ///
    /// A reading taken during the announcement was recorded but not spoken. If
    /// it differs from what was just said, speak it now; otherwise stay quiet,
    /// which also prevents the announcement from triggering another one.
    private func finishSpeaking(settings: SpeechSettings) {
        isSpeaking = false
        guard isListening else { return }
        let current = spokenVerdict()
        guard current != lastSpokenVerdict else { return }
        guard case .waiting = verdict else {
            lastSpokenVerdict = current
            speak(current, settings: settings)
            return
        }
    }

    private func flatnessCents(from verdict: Verdict) -> Double {
        if case .tooFlat(let cents) = verdict { return cents }
        return 0
    }
}
