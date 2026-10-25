import AVFoundation
import Foundation
import TuneCore
import UIKit

struct TuningReading: Equatable {
    let noteName: String
    let targetMIDI: Int
    let cents: Double
    let frequency: Double
    let confidence: Double
    let isInTune: Bool

    var displayText: String {
        if isInTune {
            return "\(noteName)，准"
        }
        return "\(noteName)，\(PitchMath.formatCents(cents))"
    }

    var spokenText: String {
        "\(noteName)，\(PitchMath.formatCents(cents))"
    }
}

@MainActor
final class TunerViewModel: ObservableObject {
    @Published private(set) var reading: TuningReading?
    @Published private(set) var liveReading: TuningReading?
    @Published private(set) var statusText: String = "准备聆听"
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var errorMessage: String?

    private let audioEngine = TunerAudioEngine()
    private let speech = SpeechFeedback()

    private var preset: InstrumentPreset = PresetCatalog.guitar
    private var targetString: TuningString?
    private var mode: DetectionMode = .locked
    private var concertA: Double = 440
    private var toleranceCents: Double = 3
    private var feedbackMode: AutoUpdateFeedbackMode = .numberAndHaptics
    private var namingStyle: NoteNamingStyle = .letter
    private var referenceTimbre: ReferenceToneTimbre = .sine

    private var previousRMS: Double = 0
    private var lastSoundAt: Date?
    private var pluckStartedAt: Date?
    private var pluckFrequencies: [Double] = []
    private var lastAnnouncedCents: Double?
    private var lastUpdateAt: Date?
    private var autoUpdateCount: Int = 0
    private var isSpeechActive = false
    private var onSpeechComplete: (() -> Void)?
    private var startedAtLeastOnce = false

    init() {
        speech.onFinish = { [weak self] in
            guard let self else { return }
            self.isSpeechActive = false
            let completion = self.onSpeechComplete
            self.onSpeechComplete = nil
            completion?()
        }
    }

    func start(
        preset: InstrumentPreset,
        string: TuningString?,
        mode: DetectionMode,
        concertA: Double,
        toleranceCents: Double,
        feedbackMode: AutoUpdateFeedbackMode,
        namingStyle: NoteNamingStyle,
        referenceTimbre: ReferenceToneTimbre,
        announceEntry: Bool
    ) {
        audioEngine.stop()
        speech.stop()
        isSpeechActive = false
        self.preset = preset
        self.targetString = string
        self.mode = mode
        self.concertA = concertA
        self.toleranceCents = toleranceCents
        self.feedbackMode = feedbackMode
        self.namingStyle = namingStyle
        self.referenceTimbre = referenceTimbre
        resetDetectionState()
        reading = nil
        liveReading = nil
        errorMessage = nil
        statusText = "准备聆听"

        requestPermissionIfNeeded { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.errorMessage = "麦克风权限未开启。请在系统设置中允许调音节拍器使用麦克风。"
                self.statusText = "需要麦克风权限"
                self.isListening = false
                return
            }
            self.beginListening(announceEntry: announceEntry)
        }
    }

    func stop() {
        audioEngine.stop()
        speech.stop()
        isSpeechActive = false
        isListening = false
        isPaused = false
    }

    func pause() {
        guard isListening else { return }
        audioEngine.stop()
        isListening = false
        isPaused = true
        statusText = "已暂停聆听"
        speak("已暂停聆听")
    }

    func pauseForOverlay() {
        guard isListening else { return }
        audioEngine.stop()
        isListening = false
        isPaused = true
        statusText = "已暂停聆听"
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        beginListening(announceEntry: false)
        speak("继续聆听")
    }

    func queryResult() {
        if let reading {
            speak(reading.spokenText)
        } else {
            speak("还没有检测到稳定音高")
        }
    }

    func playReferenceTone() {
        guard isListening else {
            speak("请先继续聆听")
            return
        }
        let targetMIDI = reading?.targetMIDI ?? targetString?.midi ?? 69
        let frequency = PitchMath.frequency(forMIDI: Double(targetMIDI), concertA: concertA)
        isSpeechActive = true
        statusText = "正在播放参考音"
        do {
            try audioEngine.playReferenceTone(frequency: frequency, timbre: referenceTimbre) { [weak self] in
                guard let self else { return }
                self.isSpeechActive = false
                self.statusText = "继续聆听"
                self.speak("继续聆听")
            }
        } catch {
            isSpeechActive = false
            errorMessage = error.localizedDescription
            statusText = "参考音播放失败"
        }
    }

    private func requestPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        @unknown default:
            completion(false)
        }
    }

    private func beginListening(announceEntry: Bool) {
        do {
            try audioEngine.start { [weak self] estimate in
                self?.handle(estimate)
            }
            isListening = true
            isPaused = false
            errorMessage = nil
            statusText = "正在聆听"
            if announceEntry {
                speak(entryAnnouncement)
            }
            startedAtLeastOnce = true
        } catch {
            isListening = false
            errorMessage = error.localizedDescription
            statusText = "无法开始聆听"
        }
    }

    private var entryAnnouncement: String {
        let target = targetString.map {
            NoteNamingFormatter.stringDisplayName($0, style: namingStyle)
        } ?? mode.title
        return "调音器，\(preset.displayName)，\(target)，正在聆听"
    }

    private func handle(_ estimate: PitchEstimate) {
        guard isListening, !isPaused, !isSpeechActive else { return }

        let now = Date()

        guard let frequency = estimate.frequency, estimate.isReliable else {
            let silenceDuration = lastSoundAt.map { now.timeIntervalSince($0) } ?? .infinity
            if silenceDuration >= 0.3 {
                resetPluck()
                liveReading = nil
                statusText = "等待声音"
            }
            return
        }

        lastSoundAt = now
        let isOnset = pluckStartedAt == nil || (previousRMS < 0.008 && estimate.rms >= 0.012)
        if isOnset {
            pluckStartedAt = now
            pluckFrequencies.removeAll(keepingCapacity: true)
            lastAnnouncedCents = nil
            lastUpdateAt = nil
            autoUpdateCount = 0
        }
        previousRMS = estimate.rms

        let live = makeReading(frequency: frequency, confidence: estimate.confidence)
        liveReading = live

        pluckFrequencies.append(frequency)
        if pluckFrequencies.count > 8 {
            pluckFrequencies.removeFirst(pluckFrequencies.count - 8)
        }

        guard pluckFrequencies.count >= 3,
              let startedAt = pluckStartedAt,
              now.timeIntervalSince(startedAt) >= 0.25 else {
            statusText = "正在分析"
            return
        }

        let recent = Array(pluckFrequencies.suffix(5)).sorted()
        let medianFrequency = recent[recent.count / 2]
        let stableReading = makeReading(frequency: medianFrequency, confidence: estimate.confidence)

        if lastAnnouncedCents == nil {
            present(stableReading, initial: true)
            return
        }

        guard let previousCents = lastAnnouncedCents,
              abs(stableReading.cents - previousCents) >= 5,
              let lastUpdateAt,
              now.timeIntervalSince(lastUpdateAt) >= 0.3,
              autoUpdateCount < 3 else {
            return
        }

        present(stableReading, initial: false)
    }

    private func makeReading(frequency: Double, confidence: Double) -> TuningReading {
        let targetNote: Note
        let cents: Double

        if mode == .locked, let targetString {
            targetNote = targetString.note
            let targetFrequency = PitchMath.frequency(for: targetNote, concertA: concertA)
            cents = PitchMath.cents(from: frequency, to: targetFrequency) ?? 0
        } else if let nearest = PitchMath.nearestNote(to: frequency, concertA: concertA) {
            targetNote = nearest.note
            cents = nearest.cents
        } else {
            targetNote = Note(midi: 69)
            cents = 0
        }

        return TuningReading(
            noteName: NoteNamingFormatter.noteName(midi: targetNote.midi, style: namingStyle),
            targetMIDI: targetNote.midi,
            cents: cents,
            frequency: frequency,
            confidence: confidence,
            isInTune: abs(cents) <= toleranceCents
        )
    }

    private func present(_ reading: TuningReading, initial: Bool) {
        self.reading = reading
        statusText = reading.displayText
        lastAnnouncedCents = reading.cents
        lastUpdateAt = Date()
        if !initial {
            autoUpdateCount += 1
        }

        playHaptic(for: reading)

        if initial {
            speak(reading.spokenText)
        } else if feedbackMode == .numberAndHaptics {
            speak(PitchMath.formatCents(reading.cents))
        } else {
            isSpeechActive = true
            do {
                try audioEngine.playEarcon(cents: reading.cents) { [weak self] in
                    self?.isSpeechActive = false
                }
            } catch {
                isSpeechActive = false
            }
        }
    }

    private func playHaptic(for reading: TuningReading) {
        if reading.isInTune {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else if reading.cents > 0 {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                generator.impactOccurred()
            }
        } else {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    private func speak(_ text: String, completion: (() -> Void)? = nil) {
        guard !text.isEmpty else { return }
        isSpeechActive = true
        onSpeechComplete = completion
        speech.speak(text)
    }

    private func resetPluck() {
        previousRMS = 0
        pluckStartedAt = nil
        pluckFrequencies.removeAll(keepingCapacity: true)
        lastAnnouncedCents = nil
        lastUpdateAt = nil
        autoUpdateCount = 0
    }

    private func resetDetectionState() {
        resetPluck()
        lastSoundAt = nil
        startedAtLeastOnce = false
    }
}




