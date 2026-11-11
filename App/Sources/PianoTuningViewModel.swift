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
            try audioEngine.start { [weak self] estimate, _, _ in
                self?.handle(estimate: estimate, curve: curve)
            }
            isListening = true
            speech.speak("开始调律 \(noteName)", settings: settings)
        } catch {
            isListening = false
            errorMessage = TunerAudioEngineError.chineseMessage(for: error)
            speech.speak("麦克风无法开启", settings: settings)
        }
    }

    func stop(settings: SpeechSettings) {
        audioEngine.stop()
        isListening = false
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

    private func handle(estimate: PitchEstimate, curve: StretchCurve) {
        guard isListening else { return }
        let now = Date()

        guard let frequency = estimate.frequency,
              estimate.confidence >= 0.6,
              estimate.rms >= 0.006 else {
            let silence = lastSoundAt.map { now.timeIntervalSince($0) } ?? .infinity
            if silence >= 0.35 { verdict = .waiting }
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
    func announceIfChanged(settings: SpeechSettings) {
        let text = spokenVerdict()
        guard text != lastSpokenVerdict else { return }
        lastSpokenVerdict = text
        guard case .waiting = verdict else {
            speech.speak(text, settings: settings)
            return
        }
    }

    private func flatnessCents(from verdict: Verdict) -> Double {
        if case .tooFlat(let cents) = verdict { return cents }
        return 0
    }
}
