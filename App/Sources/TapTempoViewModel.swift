import Combine
import AVFoundation
import Foundation
import TuneCore
import UIKit

@MainActor
final class TapTempoViewModel: ObservableObject {
    @Published private(set) var bpm: Double?
    @Published private(set) var tapCount: Int = 0
    @Published private(set) var statusHint: String?
    let groupSize = TapTempoEstimator().groupSize

    private var estimator = TapTempoEstimator()
    private var resetTask: Task<Void, Never>?
    private var lastAnnouncedRoundedBPM: Int?
    private let speech = SpeechFeedback()
    private let audioEngine = TapTempoAudioEngine()

    deinit {
        resetTask?.cancel()
    }

    func tap(hapticsEnabled: Bool = true, countdownHintEnabled: Bool = true) {
        let restarted = estimator.record(at: Date.timeIntervalSinceReferenceDate)
        if restarted {
            bpm = nil
            tapCount = 0
            lastAnnouncedRoundedBPM = nil
            statusHint = nil
        }
        tapCount = estimator.tapCount

        if estimator.shouldPublishResult, let newBPM = estimator.bpm {
            estimator.markResultPublished()
            bpm = newBPM
            let roundedBPM = Int(newBPM.rounded())
            if lastAnnouncedRoundedBPM != roundedBPM {
                lastAnnouncedRoundedBPM = roundedBPM
                speech.speak("速度 \(roundedBPM) BPM")
            }
        }

        updateHint(enabled: countdownHintEnabled)

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
            guard let self, self.bpm == nil else { return }
            self.reset()
        }
    }

    func reset() {
        resetTask?.cancel()
        estimator.reset()
        bpm = nil
        tapCount = 0
        lastAnnouncedRoundedBPM = nil
        statusHint = nil
    }

    private func updateHint(enabled: Bool) {
        guard tapCount > 0 else {
            statusHint = nil
            return
        }

        guard enabled else {
            statusHint = bpm == nil
                ? "已记录 \(tapCount) 拍，继续敲击"
                : "已记录 \(tapCount) 拍"
            return
        }

        if bpm == nil {
            let remainder = estimator.tapCount % groupSize
            statusHint = "已记录 \(tapCount) 拍，再敲 \(groupSize - remainder) 拍得到第一个速度"
        } else if estimator.shouldPublishResult {
            statusHint = "已记录 \(tapCount) 拍，再敲 \(groupSize) 拍更新速度"
        } else {
            let remainder = estimator.tapCount % groupSize
            statusHint = "已记录 \(tapCount) 拍，再敲 \(max(1, groupSize - remainder)) 拍更新速度"
        }
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
