import AVFoundation
import Foundation
import TuneCore
import UIKit

/// Converts display note names such as "C#4" into speech-safe Chinese.
/// Chinese TTS reads a bare "#" as an extra word; the ASCII letters stay.
enum SpokenNoteName {
    static func convert(_ displayName: String) -> String {
        guard displayName.contains("#") else { return displayName }
        let base = displayName.replacingOccurrences(of: "#", with: "")
        let octaveMap: [Character: String] = [
            "0": "零", "1": "一", "2": "二", "3": "三", "4": "四",
            "5": "五", "6": "六", "7": "七", "8": "八", "9": "九"
        ]
        guard let letter = base.first else { return base }
        let rest = String(base.dropFirst())
        let spokenOctave = rest.compactMap { octaveMap[$0] }.joined()
        return "升\(letter)\(spokenOctave.isEmpty ? rest : spokenOctave)"
    }
}

struct TuningReading: Equatable {
    let noteName: String
    let targetMIDI: Int
    let cents: Double
    let frequency: Double
    /// Ideal frequency of the target note under the current concert pitch.
    let targetFrequency: Double
    let confidence: Double
    let isInTune: Bool
    let toleranceCents: Double

    private var feedback: TuningFeedback {
        TuningFeedback(
            noteName: noteName,
            cents: cents,
            confidence: confidence,
            toleranceCents: toleranceCents,
            frequency: frequency,
            targetFrequency: targetFrequency
        )
    }

    func displayText(unit: TuningDisplayUnit) -> String {
        feedback.displayText(unit: unit)
    }

    /// Full sentence used the first time a note is reported.
    func spokenText(unit: TuningDisplayUnit) -> String {
        feedback.fullSpokenText(unit: unit, name: SpokenNoteName.convert(noteName))
    }

    /// Value only. Used when the same note repeats inside the repeat window so
    /// the user hears the new reading without the note name again.
    func shortSpokenText(unit: TuningDisplayUnit) -> String {
        feedback.shortSpokenText(unit: unit)
    }

    func valueOnlyText(unit: TuningDisplayUnit) -> String {
        feedback.resultText(unit: unit)
    }

    func shouldAnnounceFullResult(comparedTo previous: TuningReading?) -> Bool {
        feedback.shouldAnnounceFullResult(comparedTo: previous?.feedback)
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
    @Published private(set) var needsMicrophonePermission = false

    /// How long a note name stays "known". Re-plucking the same note inside
    /// this window reports only the new value. Configured in tuner settings.
    var repeatNoteNameWindow: TimeInterval = 8

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
    var displayUnit: TuningDisplayUnit = .cents

    private var previousRMS: Double = 0
    private var lastSoundAt: Date?
    private var pluckStartedAt: Date?
    private var pluckFrequencies: [Double] = []
    private var lastAnnouncedCents: Double?
    private var lastUpdateAt: Date?
    private var autoUpdateCount: Int = 0
    private var lastPresentedReading: TuningReading?
    private var isShowingMultiplePitchWarning = false
    private var lastLiveReadingPublishAt: Date = .distantPast
    /// Note name of the most recent full announcement and when it happened.
    /// Repeating the same note within the window is reported as a value only,
    /// which keeps rapid re-plucks from re-reading the note name every time.
    private var lastAnnouncedNoteName: String?
    private var lastFullAnnouncementAt: Date = .distantPast
    /// Rolling estimate of the room's background level. Raised slowly while
    /// quiet, never by loud musical attacks, so tuning stays usable in noisy
    /// rooms instead of treating constant hiss as a played note.
    private var noiseFloorRMS: Double = 0.002
    private var noiseFloorInitialized = false
    private var isSpeechActive = false
    /// True while the app itself is producing sound (earcon or reference tone).
    /// Those frames must be ignored by pitch analysis; VoiceOver speech must not.
    private var isAppTonePlaying = false
    private var onSpeechComplete: (() -> Void)?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var routeRestartTask: Task<Void, Never>?
    private var isPageVisible = false
    private var isSceneActive = true
    private var resumeAfterLifecycle = false
    private var wantsListening = false
    private var isRequestingPermission = false

    init() {
        speech.onFinish = { [weak self] in
            guard let self else { return }
            self.isSpeechActive = false
            let completion = self.onSpeechComplete
            self.onSpeechComplete = nil
            completion?()
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleRouteChange(notification)
            }
        }
    }

    deinit {
        routeRestartTask?.cancel()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
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
        routeRestartTask?.cancel()
        routeRestartTask = nil
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
        isListening = false
        errorMessage = nil
        needsMicrophonePermission = false
        statusText = "准备聆听"
        isPaused = false
        resumeAfterLifecycle = false
        wantsListening = true

        guard isPageVisible, isSceneActive else {
            resumeAfterLifecycle = true
            statusText = "等待回到前台后继续"
            return
        }

        requestPermissionIfNeeded { [weak self] granted in
            guard let self else { return }
            guard self.wantsListening else { return }
            guard granted else {
                self.errorMessage = "麦克风权限未开启。请在系统设置中允许调音节拍器使用麦克风。"
                self.needsMicrophonePermission = true
                self.statusText = "需要麦克风权限"
                self.isListening = false
                return
            }
            self.beginListening(announceEntry: announceEntry)
        }
    }

    /// Configure the tuner but stay paused until the user explicitly resumes.
    func startPaused(
        preset: InstrumentPreset,
        string: TuningString?,
        mode: DetectionMode,
        concertA: Double,
        toleranceCents: Double,
        feedbackMode: AutoUpdateFeedbackMode,
        namingStyle: NoteNamingStyle,
        referenceTimbre: ReferenceToneTimbre
    ) {
        routeRestartTask?.cancel()
        routeRestartTask = nil
        audioEngine.stop()
        speech.stop()
        isSpeechActive = false
        isAppTonePlaying = false
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
        isListening = false
        isPaused = true
        wantsListening = false
        resumeAfterLifecycle = false
        errorMessage = nil
        needsMicrophonePermission = false
        statusText = "已暂停，点继续聆听开始"
    }

    func stop() {
        routeRestartTask?.cancel()
        routeRestartTask = nil
        audioEngine.stop()
        speech.stop()
        isSpeechActive = false
        isAppTonePlaying = false
        isListening = false
        isPaused = false
        resumeAfterLifecycle = false
        wantsListening = false
    }

    func pause() {
        guard isListening else { return }
        routeRestartTask?.cancel()
        routeRestartTask = nil
        audioEngine.stop()
        isListening = false
        isPaused = true
        wantsListening = false
        statusText = "已暂停聆听"
        speak("已暂停聆听")
    }

    func pauseForOverlay() {
        guard isListening else { return }
        routeRestartTask?.cancel()
        routeRestartTask = nil
        audioEngine.stop()
        isListening = false
        isPaused = true
        wantsListening = false
        statusText = "已暂停聆听"
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        wantsListening = true
        if !isPageVisible || !isSceneActive {
            resumeAfterLifecycle = true
            statusText = "等待回到前台后继续"
            return
        }
        beginListening(announceEntry: false)
        speak("继续聆听")
    }

    func retryMicrophonePermission() {
        start(
            preset: preset,
            string: targetString,
            mode: mode,
            concertA: concertA,
            toleranceCents: toleranceCents,
            feedbackMode: feedbackMode,
            namingStyle: namingStyle,
            referenceTimbre: referenceTimbre,
            announceEntry: false
        )
    }

    func handleScenePhaseChange(wasActive: Bool, isActive: Bool) {
        guard wasActive != isActive else { return }
        isSceneActive = isActive

        if !isActive, isListening {
            resumeAfterLifecycle = true
            wantsListening = true
            audioEngine.stop()
            speech.stop()
            isSpeechActive = false
            isListening = false
            isPaused = true
            statusText = "已暂停聆听"
        } else if isActive {
            resumeIfNeeded()
        }
    }

    func pageDidDisappear() {
        isPageVisible = false
        routeRestartTask?.cancel()
        routeRestartTask = nil
        audioEngine.stop()
        speech.stop()
        isSpeechActive = false
        isListening = false
        isPaused = false
        resumeAfterLifecycle = false
        wantsListening = false
    }

    func pageWillAppear(sceneIsActive: Bool) {
        isPageVisible = true
        isSceneActive = sceneIsActive
    }

    func pageDidBecomeActive() {
        isSceneActive = true
        if needsMicrophonePermission {
            retryMicrophonePermission()
        } else {
            resumeIfNeeded()
        }
    }

    func prepareToListenWhenActive(
        preset: InstrumentPreset,
        string: TuningString?,
        mode: DetectionMode,
        concertA: Double,
        toleranceCents: Double,
        feedbackMode: AutoUpdateFeedbackMode,
        namingStyle: NoteNamingStyle,
        referenceTimbre: ReferenceToneTimbre
    ) {
        self.preset = preset
        self.targetString = string
        self.mode = mode
        self.concertA = concertA
        self.toleranceCents = toleranceCents
        self.feedbackMode = feedbackMode
        self.namingStyle = namingStyle
        self.referenceTimbre = referenceTimbre
        wantsListening = true
        resumeAfterLifecycle = true
        isPaused = false
        statusText = "等待回到前台后继续"
    }

    func setSceneActive(_ isActive: Bool) {
        guard isActive != isSceneActive else { return }
        handleScenePhaseChange(wasActive: isSceneActive, isActive: isActive)
    }

    func queryResult() {
        if let reading {
            speak(reading.spokenText(unit: displayUnit))
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
        isAppTonePlaying = true
        statusText = "正在播放参考音"
        do {
            try audioEngine.playReferenceTone(frequency: frequency, timbre: referenceTimbre) { [weak self] in
                guard let self else { return }
                self.isAppTonePlaying = false
                self.statusText = "继续聆听"
                self.speak("继续聆听")
            }
        } catch {
            isAppTonePlaying = false
            errorMessage = "参考音播放失败，请稍后再试。"
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
            guard !isRequestingPermission else { return }
            isRequestingPermission = true
            session.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.isRequestingPermission = false
                    completion(granted)
                }
            }
        @unknown default:
            completion(false)
        }
    }

    private func beginListening(announceEntry: Bool) {
        if isListening {
            return
        }
        guard isPageVisible, isSceneActive else {
            resumeAfterLifecycle = true
            statusText = "等待回到前台后继续"
            return
        }
        do {
            try audioEngine.start { [weak self] estimate, samples, sampleRate in
                self?.handle(estimate, samples: samples, sampleRate: sampleRate)
            }
            isListening = true
            isPaused = false
            errorMessage = nil
            needsMicrophonePermission = false
            statusText = "正在聆听"
            if announceEntry {
                speak(entryAnnouncement)
            }
        } catch {
            isListening = false
            isPaused = true
            errorMessage = TunerAudioEngineError.chineseMessage(for: error)
            statusText = "无法开始聆听"
        }
    }

    private func resumeIfNeeded() {
        guard isPageVisible, isSceneActive, wantsListening else { return }
        guard resumeAfterLifecycle || (!isListening && !isPaused) else { return }

        if needsMicrophonePermission {
            retryMicrophonePermission()
            return
        }

        resumeAfterLifecycle = false
        isPaused = false
        requestPermissionIfNeeded { [weak self] granted in
            guard let self else { return }
            guard self.wantsListening else { return }
            guard granted else {
                self.errorMessage = "麦克风权限未开启。请在系统设置中允许调音节拍器使用麦克风。"
                self.needsMicrophonePermission = true
                self.statusText = "需要麦克风权限"
                self.isListening = false
                return
            }
            self.beginListening(announceEntry: false)
            if self.isListening {
                self.speak("继续聆听")
            } else {
                self.resumeAfterLifecycle = false
                self.isPaused = true
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            guard isListening else { return }
            resumeAfterLifecycle = true
            wantsListening = true
            routeRestartTask?.cancel()
            routeRestartTask = nil
            audioEngine.stop()
            speech.stop()
            isSpeechActive = false
            isListening = false
            isPaused = true
            statusText = "音频被中断，等待恢复"
        case .ended:
            guard resumeAfterLifecycle, isPageVisible else { return }
            if needsMicrophonePermission {
                retryMicrophonePermission()
                return
            }
            resumeIfNeeded()
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            return
        }
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange:
            break
        default:
            return
        }
        guard isListening, isPageVisible, isSceneActive else { return }

        routeRestartTask?.cancel()
        routeRestartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let self, self.isListening, self.isSceneActive else { return }
            self.audioEngine.stop()
            self.speech.stop()
            self.isSpeechActive = false
            self.isListening = false
            self.beginListening(announceEntry: false)
            if self.isListening {
                self.speak("音频输出已切换，继续聆听")
            }
        }
    }

    private var entryAnnouncement: String {
        let target = targetString.map {
            SpokenNoteName.convert(
                NoteNamingFormatter.stringDisplayName($0, style: namingStyle)
            )
        } ?? mode.title
        return "调音器，\(preset.displayName)，\(target)，正在聆听"
    }

    private func handle(_ estimate: PitchEstimate, samples: [Float], sampleRate: Double) {
        // The app's own earcon/reference tone must never be analysed. Speech is
        // allowed through so a new note can interrupt it; the onset check below
        // requires a louder attack while speaking to avoid looping on our voice.
        guard isListening, !isPaused, !isAppTonePlaying else { return }

        let now = Date()
        updateNoiseFloor(rms: estimate.rms)

        let adaptiveMinimumRMS = min(0.02, max(0.0025, noiseFloorRMS * 2.5))
        // High piano notes decay fast and carry little energy. Requiring the
        // same level as bass notes made C7 and above look silent.
        let highNoteRelief = (estimate.frequency ?? 0) >= 1_500
        let requiredRMS = highNoteRelief
            ? max(0.0012, adaptiveMinimumRMS * 0.45)
            : adaptiveMinimumRMS
        let requiredConfidence = highNoteRelief ? 0.5 : 0.62
        let reliable = estimate.frequency != nil
            && estimate.confidence >= requiredConfidence
            && estimate.rms >= requiredRMS

        guard let frequency = estimate.frequency, reliable else {
            let silenceDuration = lastSoundAt.map { now.timeIntervalSince($0) } ?? .infinity
            if silenceDuration >= 0.3 {
                resetPluck()
                liveReading = nil
                statusText = "等待声音"
            }
            return
        }

        lastSoundAt = now
        // While our own announcement is playing it can leak into the mic.
        // Accept a new note then only when it is clearly louder than speech,
        // so fast note changes still register without looping on our own voice.
        let isOnset: Bool
        if isSpeechActive {
            isOnset = pluckStartedAt == nil || (previousRMS < 0.02 && estimate.rms >= 0.05)
        } else {
            // Scale the attack requirement with the room noise so background
            // rumble cannot start a tuning event on its own.
            let quietThreshold = max(0.008, adaptiveMinimumRMS)
            let attackThreshold = max(0.012, adaptiveMinimumRMS * 1.8)
            isOnset = pluckStartedAt == nil
                || (previousRMS < quietThreshold && estimate.rms >= attackThreshold)
        }
        if isOnset {
            pluckStartedAt = now
            pluckFrequencies.removeAll(keepingCapacity: true)
            lastAnnouncedCents = nil
            lastUpdateAt = nil
            autoUpdateCount = 0
            // A new attack means a new note. Clear the previous note's speech
            // state; the next announcement interrupts it without queueing.
            isSpeechActive = false
            onSpeechComplete = nil
        }
        previousRMS = estimate.rms

        let live = makeReading(frequency: frequency, confidence: estimate.confidence)
        if now.timeIntervalSince(lastLiveReadingPublishAt) >= 0.25 {
            liveReading = live
            lastLiveReadingPublishAt = now
        }

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

        // A single string or key should give a stable pitch. When the recent
        // frames disagree a lot, the estimate is probably tracking a different
        // partial; reporting "multiple notes" there would be wrong, so wait
        // for a steadier reading instead.
        let spread = recent.last! - recent.first!
        let isSteady = medianFrequency > 0 && spread / medianFrequency < 0.03

        let multiplePitchResult = MultiplePitchDetector.detect(
            samples: samples,
            sampleRate: sampleRate,
            primaryFrequency: medianFrequency,
            primaryConfidence: estimate.confidence,
            rms: estimate.rms,
            isPitchSteady: isSteady
        )
        if multiplePitchResult.isMultiplePitches {
            if !isShowingMultiplePitchWarning {
                isShowingMultiplePitchWarning = true
                resetPluck()
                liveReading = nil
                statusText = "检测到多个音，请一次弹一个音"
                speak("检测到多个音，请一次弹一个音")
            }
            return
        }
        isShowingMultiplePitchWarning = false

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
            targetFrequency: PitchMath.frequency(for: targetNote, concertA: concertA),
            confidence: confidence,
            isInTune: abs(cents) <= toleranceCents,
            toleranceCents: toleranceCents
        )
    }

    private func present(_ reading: TuningReading, initial: Bool) {
        self.reading = reading
        statusText = reading.displayText(unit: displayUnit)
        lastAnnouncedCents = reading.cents
        lastUpdateAt = Date()
        if !initial {
            autoUpdateCount += 1
        }

        playHaptic(for: reading)

        // Repeating the same note shortly after it was named does not need the
        // name again; the user already knows which note they are holding.
        let now = Date()
        let window = repeatNoteNameWindow
        let isSameNoteRecentlyNamed = window > 0
            && lastAnnouncedNoteName == reading.noteName
            && now.timeIntervalSince(lastFullAnnouncementAt) < window

        let shouldSpeakFullResult = !isSameNoteRecentlyNamed
            && (initial || reading.shouldAnnounceFullResult(comparedTo: lastPresentedReading))
        lastPresentedReading = reading

        if shouldSpeakFullResult {
            lastAnnouncedNoteName = reading.noteName
            lastFullAnnouncementAt = now
            speak(reading.spokenText(unit: displayUnit))
        } else if feedbackMode == .numberAndHaptics {
            // Value only: repeating a note must not re-read its name, even when
            // confidence dips (the short form would otherwise include it).
            speak(reading.valueOnlyText(unit: displayUnit))
        } else {
            isAppTonePlaying = true
            do {
                try audioEngine.playEarcon(
                    cents: reading.cents,
                    isInTune: reading.isInTune
                ) { [weak self] in
                    self?.isAppTonePlaying = false
                }
            } catch {
                isAppTonePlaying = false
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
        // SpeechFeedback interrupts any older utterance itself and waits for
        // the cancellation to settle, so the new result is not clipped.
        isSpeechActive = true
        onSpeechComplete = completion
        speech.speak(text)
    }

    private func updateNoiseFloor(rms: Double) {
        guard rms.isFinite, rms >= 0 else { return }
        if !noiseFloorInitialized {
            noiseFloorRMS = max(0.0015, rms)
            noiseFloorInitialized = true
            return
        }
        // Fast to rise when the room gets noisier, very slow to fall so a
        // sustained note cannot lower the gate under itself.
        if rms > noiseFloorRMS {
            noiseFloorRMS += (rms - noiseFloorRMS) * 0.08
        } else {
            // 1%/frame at ~186 ms per frame took ~19 s to recover, so a loud
            // passage kept the gate high long after the room went quiet.
            noiseFloorRMS += (rms - noiseFloorRMS) * 0.05
        }
    }

    private func resetPluck() {
        previousRMS = 0
        pluckStartedAt = nil
        pluckFrequencies.removeAll(keepingCapacity: true)
        lastAnnouncedCents = nil
        lastUpdateAt = nil
        autoUpdateCount = 0
        lastPresentedReading = nil
        isShowingMultiplePitchWarning = false
    }

    private func resetDetectionState() {
        resetPluck()
        noiseFloorInitialized = false
        lastSoundAt = nil
        lastLiveReadingPublishAt = .distantPast
    }
}




