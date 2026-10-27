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
    let toleranceCents: Double

    private var feedback: TuningFeedback {
        TuningFeedback(
            noteName: noteName,
            cents: cents,
            confidence: confidence,
            toleranceCents: toleranceCents
        )
    }

    var displayText: String {
        feedback.displayText
    }

    var spokenText: String {
        feedback.fullSpokenText
    }

    var shortSpokenText: String {
        feedback.shortSpokenText
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
    private var lastPresentedReading: TuningReading?
    private var isSpeechActive = false
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

    func stop() {
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
            try audioEngine.start { [weak self] estimate in
                self?.handle(estimate)
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
            errorMessage = error.localizedDescription
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
            isInTune: abs(cents) <= toleranceCents,
            toleranceCents: toleranceCents
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

        let shouldSpeakFullResult = initial
            || reading.shouldAnnounceFullResult(comparedTo: lastPresentedReading)
        lastPresentedReading = reading

        if shouldSpeakFullResult {
            speak(reading.spokenText)
        } else if feedbackMode == .numberAndHaptics {
            speak(reading.shortSpokenText)
        } else {
            isSpeechActive = true
            do {
                try audioEngine.playEarcon(
                    cents: reading.cents,
                    isInTune: reading.isInTune
                ) { [weak self] in
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
        lastPresentedReading = nil
    }

    private func resetDetectionState() {
        resetPluck()
        lastSoundAt = nil
    }
}




