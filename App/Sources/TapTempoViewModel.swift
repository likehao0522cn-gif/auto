import Combine
import AVFoundation
import Foundation
import TuneCore
import UIKit

@MainActor
final class TapTempoViewModel: ObservableObject {
    @Published private(set) var bpm: Double?
    @Published private(set) var tapCount: Int = 0

    private var estimator = TapTempoEstimator()
    private var resetTask: Task<Void, Never>?
    private var announcedInitialResult = false
    private let speech = SpeechFeedback()
    private let audioEngine = TapTempoAudioEngine()

    deinit {
        resetTask?.cancel()
    }

    func tap(hapticsEnabled: Bool = true) {
        estimator.record(at: Date.timeIntervalSinceReferenceDate)
        tapCount = estimator.timestamps.count
        if estimator.hasEnoughTapsForInitialEstimate {
            bpm = estimator.bpm
            if !announcedInitialResult, let bpm {
                announcedInitialResult = true
                speech.speak("速度每分钟 \(Int(bpm.rounded())) 拍")
            }
        }

        if hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
        try? audioEngine.playConfirmationClick()

        resetTask?.cancel()
        resetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.reset()
        }
    }

    func reset() {
        resetTask?.cancel()
        estimator.reset()
        bpm = nil
        tapCount = 0
        announcedInitialResult = false
    }
}

private final class TapTempoAudioEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isAttached = false

    func playConfirmationClick() throws {
        try AudioSessionManager.configureForTapTempo()

        if !isAttached {
            engine.attach(player)
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            engine.connect(player, to: engine.mainMixerNode, format: format)
            isAttached = true
        }

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let duration = 0.035
        let frameCount = AVAudioFrameCount((duration * 44_100).rounded())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else {
            return
        }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / 44_100
            let envelope = exp(-time * 90)
            channel[frame] = Float(sin(2 * Double.pi * 1_200 * time) * envelope * 0.16)
        }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }
}
