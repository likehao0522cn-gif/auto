import AVFoundation
import Combine
import Foundation
import TuneCore
import UIKit

@MainActor
final class MetronomeViewModel: ObservableObject {
    @Published var configuration: MetronomeConfiguration {
        didSet {
            saveConfiguration()
            if isPlaying { scheduleRestart() }
        }
    }

    @Published var timbre: MetronomeTimbre {
        didSet {
            saveConfiguration()
            if isPlaying { scheduleRestart() }
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            saveConfiguration()
            if hapticsEnabled, isPlaying {
                startHapticLoop()
            } else if !hapticsEnabled {
                hapticTask?.cancel()
                hapticTask = nil
            }
        }
    }

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var statusText: String = "已停止"
    @Published private(set) var errorMessage: String?

    private let engine = MetronomeAudioEngine()
    private let speech = SpeechFeedback()
    /// Usage statistics and the favorite tempo list.
    let favorites: FavoriteTempoStore
    private let defaults: UserDefaults
    private var interruptionObserver: NSObjectProtocol?
    private var hapticTask: Task<Void, Never>?
    private var scheduledHapticPattern: [MetronomeClick] = []
    /// Live changes used to rebuild the whole engine on every tap, which made
    /// +/- feel sluggish and could drop a beat. Coalesce bursts into one restart.
    private var restartTask: Task<Void, Never>?
    /// Accumulates playback time into the tempo statistics.
    private var playTimeTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        favorites: FavoriteTempoStore? = nil
    ) {
        self.defaults = defaults
        self.favorites = favorites ?? FavoriteTempoStore(defaults: defaults)
        // Clean up preferences left behind by removed features (count-in was dropped).
        defaults.removeObject(forKey: Keys.legacyCountIn)

        let bpm = defaults.object(forKey: Keys.bpm) as? Double ?? 120
        let numerator = defaults.integer(forKey: Keys.numerator)
        let denominator = defaults.integer(forKey: Keys.denominator)
        let signature = TimeSignature(
            numerator: numerator == 0 ? 4 : numerator,
            denominator: denominator == 0 ? 4 : denominator
        )
        let accent = AccentMode(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .firstBeat
        let subdivision = Subdivision(rawValue: defaults.integer(forKey: Keys.subdivision)) ?? .none
        self.configuration = MetronomeConfiguration(
            bpm: MetronomeTempo.clampedBPM(bpm),
            timeSignature: signature,
            accentMode: accent,
            subdivision: subdivision
        )
        self.timbre = MetronomeTimbre(
            rawValue: defaults.string(forKey: Keys.timbre) ?? ""
        ) ?? .crisp
        self.hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }
    }

    deinit {
        hapticTask?.cancel()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    func toggle() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }

    func start() {
        startEngine()
    }

    func stop() {
        restartTask?.cancel()
        restartTask = nil
        playTimeTask?.cancel()
        playTimeTask = nil
        hapticTask?.cancel()
        hapticTask = nil
        engine.stop()
        isPlaying = false
        statusText = "已停止"
        // No announcement: the button label already says 停止 and VoiceOver
        // reads it on activation.
        speech.stop()
    }

    func applyTapTempo(_ bpm: Double) {
        setBPM(bpm)
        speak("速度设为 \(Int(configuration.bpm)) BPM")
    }

    func applyManualBPM(_ bpm: Double) {
        setBPM(bpm)
        speak("速度已设为 \(Int(configuration.bpm)) BPM")
    }

    /// Applies a saved tempo. The value is announced because the user picked it
    /// from a list rather than reading it off the main screen.
    func applyFavoriteTempo(_ bpm: Int) {
        setBPM(Double(bpm))
        speak("速度已设为 \(Int(configuration.bpm)) BPM")
    }

    /// Adds the tempo currently in use to the favorites list.
    /// Returns false when the list is full.
    @discardableResult
    func addCurrentTempoToFavorites() -> Bool {
        favorites.add(bpm: Int(configuration.bpm))
    }

    func setBPM(_ bpm: Double) {
        configuration.bpm = MetronomeTempo.clampedBPM(bpm)
    }

    func resetDefaults() {
        stop()
        configuration = MetronomeConfiguration()
        timbre = .crisp
        hapticsEnabled = true
    }

    func tickHaptic(isAccent: Bool) {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: isAccent ? .heavy : .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func startEngine(announceStart: Bool = true) {
        do {
            try engine.start(configuration: configuration, timbre: timbre)
            isPlaying = true
            errorMessage = nil
            favorites.recordStart(bpm: Int(configuration.bpm))
            startPlayTimeTracking()
            beginPlaybackFeedback(announceStart: announceStart)
        } catch {
            isPlaying = false
            errorMessage = "无法开始节拍器，请检查音频是否被其他应用占用，或稍后再试。"
            statusText = "无法开始节拍器"
        }
    }

    /// Coalesce rapid +/- or swipe changes so only one engine rebuild happens.
    private func scheduleRestart() {
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, let self, self.isPlaying else { return }
            self.restart()
        }
    }

    /// Rebuilds the click pattern while already playing, e.g. after a tempo
    /// or time-signature change. Must not announce "节拍器开始": that overlaps
    /// the time-signature announcement the user actually asked for.
    private func restart() {
        hapticTask?.cancel()
        hapticTask = nil
        startEngine(announceStart: false)
    }

    /// Adds elapsed playback time to the current tempo every two seconds.
    /// Frequent small updates keep the statistic accurate without writing to
    /// disk on every beat.
    private func startPlayTimeTracking() {
        playTimeTask?.cancel()
        playTimeTask = Task { @MainActor [weak self] in
            var lastTick = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self, self.isPlaying else { return }
                let now = Date()
                let elapsed = now.timeIntervalSince(lastTick)
                lastTick = now
                self.favorites.recordPlayback(
                    bpm: Int(self.configuration.bpm),
                    seconds: elapsed
                )
            }
        }
    }

    private func beginPlaybackFeedback(announceStart: Bool) {
        scheduledHapticPattern = MetronomePattern.clicks(for: configuration)
        statusText = playingStatusText
        // VoiceOver already announces the button the user activated, so the
        // app stays silent here to avoid reading the same thing twice.
        _ = announceStart
        startHapticLoop()
    }

    private var playingStatusText: String {
        "正在播放，\(Int(configuration.bpm)) BPM，拍号 \(configuration.timeSignature.id)，\(timbre.title)"
    }

    private func startHapticLoop() {
        hapticTask?.cancel()
        guard hapticsEnabled else {
            hapticTask = nil
            return
        }

        hapticTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled, let self, self.isPlaying else { return }
            let pattern = self.scheduledHapticPattern
            guard !pattern.isEmpty, self.configuration.barDuration > 0 else { return }
            let patternDuration = self.configuration.barDuration
            var lastHapticLoopIndex: Int?
            var lastHapticClickIndex: Int?
            while !Task.isCancelled {
                guard self.isPlaying, self.hapticsEnabled else { return }

                if let elapsed = self.engine.playbackElapsedTime() {
                    let loopsElapsed = max(0, Int(floor(elapsed / patternDuration)))
                    let timeInLoop = elapsed - Double(loopsElapsed) * patternDuration
                    if timeInLoop >= 0, timeInLoop < 0.03 {
                        let nearestIndex = pattern.indices.min {
                            abs(pattern[$0].time - timeInLoop) < abs(pattern[$1].time - timeInLoop)
                        }
                        if let nearestIndex,
                           abs(pattern[nearestIndex].time - timeInLoop) < 0.02,
                           lastHapticLoopIndex != loopsElapsed || lastHapticClickIndex != nearestIndex {
                            let nearest = pattern[nearestIndex]
                            self.tickHaptic(isAccent: nearest.isAccent)
                            lastHapticLoopIndex = loopsElapsed
                            lastHapticClickIndex = nearestIndex
                        }
                    }
                }

                try? await Task.sleep(for: .milliseconds(15))
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
            guard isPlaying else { return }
            hapticTask?.cancel()
            hapticTask = nil
            engine.stop()
            isPlaying = false
            statusText = "音频被中断，请重新开始"
            speak("节拍器已暂停，请重新开始")
        case .ended:
            if !isPlaying {
                statusText = "已停止，等待重新开始"
            }
        @unknown default:
            break
        }
    }

    private func speak(_ text: String) {
        speech.speak(text)
    }

    private func saveConfiguration() {
        defaults.set(configuration.bpm, forKey: Keys.bpm)
        defaults.set(configuration.timeSignature.numerator, forKey: Keys.numerator)
        defaults.set(configuration.timeSignature.denominator, forKey: Keys.denominator)
        defaults.set(configuration.accentMode.rawValue, forKey: Keys.accent)
        defaults.set(configuration.subdivision.rawValue, forKey: Keys.subdivision)
        defaults.set(timbre.rawValue, forKey: Keys.timbre)
        defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
    }

    private enum Keys {
        static let bpm = "metronome.bpm"
        static let numerator = "metronome.numerator"
        static let denominator = "metronome.denominator"
        static let accent = "metronome.accent"
        static let subdivision = "metronome.subdivision"
        static let timbre = "metronome.timbre"
        static let hapticsEnabled = "metronome.hapticsEnabled"
        static let legacyCountIn = "metronome.countIn"
    }
}
