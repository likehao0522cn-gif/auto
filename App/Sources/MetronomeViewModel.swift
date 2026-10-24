import AVFoundation
import Combine
import Foundation
import TuneCore

@MainActor
final class MetronomeViewModel: ObservableObject {
    @Published var configuration: MetronomeConfiguration {
        didSet {
            saveConfiguration()
            guard isPlaying else { return }
            restart()
        }
    }

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var statusText: String = "已停止"
    @Published private(set) var errorMessage: String?

    private let engine = MetronomeAudioEngine()
    private let speech = SpeechFeedback()
    private let defaults: UserDefaults
    private var interruptionObserver: NSObjectProtocol?

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
        do {
            try engine.start(configuration: configuration)
            isPlaying = true
            errorMessage = nil
            statusText = "正在播放 \(Int(configuration.bpm)) BPM，\(configuration.timeSignature.id)"
            speak("节拍器开始")
        } catch {
            isPlaying = false
            errorMessage = error.localizedDescription
            statusText = "无法开始节拍器"
        }
    }

    func stop() {
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

    private func restart() {
        do {
            try engine.start(configuration: configuration)
            isPlaying = true
            statusText = "正在播放 \(Int(configuration.bpm)) BPM，\(configuration.timeSignature.id)"
        } catch {
            isPlaying = false
            errorMessage = error.localizedDescription
            statusText = "无法开始节拍器"
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
    }

    private enum Keys {
        static let bpm = "metronome.bpm"
        static let numerator = "metronome.numerator"
        static let denominator = "metronome.denominator"
        static let accent = "metronome.accent"
        static let subdivision = "metronome.subdivision"
        static let countIn = "metronome.countIn"
    }
}
