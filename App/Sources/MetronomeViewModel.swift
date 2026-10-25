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
            if isPlaying { restart() }
        }
    }

    @Published var timbre: MetronomeTimbre {
        didSet {
            saveConfiguration()
            if isPlaying { restart() }
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            saveConfiguration()
            if hapticsEnabled, isPlaying {
                startHapticLoop(after: 0)
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
    private let defaults: UserDefaults
    private var interruptionObserver: NSObjectProtocol?
    private var hapticTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let bpm = defaults.object(forKey: Keys.bpm) as? Double ?? 120
        let numerator = defaults.integer(forKey: Keys.numerator)
        let denominator = defaults.integer(forKey: Keys.denominator)
        let signature = TimeSignature(
            numerator: numerator == 0 ? 4 : numerator,
            denominator: denominator == 0 ? 4 : denominator
        )
        let accent = AccentMode(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .firstBeat
        let subdivision = Subdivision(rawValue: defaults.integer(forKey: Keys.subdivision)) ?? .none
        let countIn = CountInBars(rawValue: defaults.integer(forKey: Keys.countIn)) ?? .off
        self.configuration = MetronomeConfiguration(
            bpm: bpm,
            timeSignature: signature,
            accentMode: accent,
            subdivision: subdivision,
            countInBars: countIn
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
        statusTask?.cancel()
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
        hapticTask?.cancel()
        hapticTask = nil
        statusTask?.cancel()
        statusTask = nil
        engine.stop()
        isPlaying = false
        statusText = "已停止"
        speak("节拍器已停止")
    }

    func applyTapTempo(_ bpm: Double) {
        let clamped = min(300, max(20, bpm.rounded()))
        configuration.bpm = clamped
        speak("速度 \(Int(clamped))")
    }

    func setBPM(_ bpm: Double) {
        configuration.bpm = min(300, max(20, bpm.rounded()))
    }

    func tickHaptic(isAccent: Bool) {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: isAccent ? .heavy : .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func startEngine() {
        do {
            try engine.start(configuration: configuration, timbre: timbre)
            isPlaying = true
            errorMessage = nil
            beginPlaybackFeedback()
        } catch {
            isPlaying = false
            errorMessage = error.localizedDescription
            statusText = "无法开始节拍器"
        }
    }

    private func restart() {
        hapticTask?.cancel()
        hapticTask = nil
        statusTask?.cancel()
        statusTask = nil
        startEngine()
    }

    private func beginPlaybackFeedback() {
        let countInDuration = configuration.countInBars.rawValue > 0
            ? configuration.barDuration * Double(configuration.countInBars.rawValue)
            : 0

        if configuration.countInBars.rawValue > 0 {
            statusText = "预备拍，\(configuration.countInBars.title)"
            speak("预备拍，\(configuration.countInBars.title)")
            statusTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(countInDuration))
                guard !Task.isCancelled, let self, self.isPlaying else { return }
                self.statusText = self.playingStatusText
            }
        } else {
            statusText = playingStatusText
            speak("节拍器开始")
        }

        startHapticLoop(after: countInDuration)
    }

    private var playingStatusText: String {
        "正在播放 \(Int(configuration.bpm)) BPM，\(configuration.timeSignature.id)，\(timbre.title)"
    }

    private func startHapticLoop(after delay: TimeInterval) {
        hapticTask?.cancel()
        guard hapticsEnabled else {
            hapticTask = nil
            return
        }

        hapticTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled, let self, self.isPlaying else { return }

            var clickIndex = 0
            let pattern = MetronomePattern.clicks(for: self.configuration)
            guard !pattern.isEmpty else { return }

            while !Task.isCancelled {
                guard self.isPlaying, self.hapticsEnabled else { return }
                let click = pattern[clickIndex % pattern.count]
                self.tickHaptic(isAccent: click.isAccent)
                clickIndex = (clickIndex + 1) % pattern.count

                let nextIndex = clickIndex % pattern.count
                let interval: TimeInterval
                if nextIndex == 0 {
                    interval = self.configuration.barDuration - pattern[pattern.count - 1].time
                } else {
                    interval = pattern[nextIndex].time - pattern[nextIndex - 1].time
                }
                guard interval > 0 else { return }
                try? await Task.sleep(for: .seconds(interval))
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
            statusTask?.cancel()
            statusTask = nil
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
        defaults.set(configuration.countInBars.rawValue, forKey: Keys.countIn)
        defaults.set(timbre.rawValue, forKey: Keys.timbre)
        defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
    }

    private enum Keys {
        static let bpm = "metronome.bpm"
        static let numerator = "metronome.numerator"
        static let denominator = "metronome.denominator"
        static let accent = "metronome.accent"
        static let subdivision = "metronome.subdivision"
        static let countIn = "metronome.countIn"
        static let timbre = "metronome.timbre"
        static let hapticsEnabled = "metronome.hapticsEnabled"
    }
}