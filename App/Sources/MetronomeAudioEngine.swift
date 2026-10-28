import AVFoundation
import TuneCore

final class MetronomeAudioEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var isAttached = false
    private var isPlaying = false
    private var firstRenderedSampleTime: AVAudioFramePosition?
    private(set) var configuration = MetronomeConfiguration()

    func playbackElapsedTime() -> TimeInterval? {
        guard isPlaying,
              let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return nil
        }
        if firstRenderedSampleTime == nil {
            firstRenderedSampleTime = playerTime.sampleTime
        }
        guard let first = firstRenderedSampleTime else { return nil }
        return Double(playerTime.sampleTime - first) / sampleRate
    }

    func start(configuration: MetronomeConfiguration, timbre: MetronomeTimbre) throws {
        stop()
        self.configuration = configuration
        firstRenderedSampleTime = nil
        try AudioSessionManager.configureForMetronome()

        if !isAttached {
            engine.attach(player)
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            engine.connect(player, to: engine.mainMixerNode, format: format)
            isAttached = true
        }

        let barBuffer = try makeBuffer(
            duration: configuration.barDuration,
            clicks: MetronomePattern.clicks(for: configuration),
            timbre: timbre
        )
        engine.prepare()
        try engine.start()

        if configuration.countInBars.rawValue > 0 {
            let countInDuration = configuration.barDuration * Double(configuration.countInBars.rawValue)
            let countInBuffer = try makeBuffer(
                duration: countInDuration,
                clicks: MetronomePattern.countInClicks(for: configuration),
                timbre: timbre
            )
            player.scheduleBuffer(
                countInBuffer,
                at: AVAudioTime(sampleTime: 0, atRate: sampleRate),
                options: []
            )
            let loopStart = AVAudioTime(
                sampleTime: AVAudioFramePosition((countInDuration * sampleRate).rounded()),
                atRate: sampleRate
            )
            player.scheduleBuffer(barBuffer, at: loopStart, options: .loops)
        } else {
            player.scheduleBuffer(barBuffer, at: nil, options: .loops)
        }

        player.play()
        isPlaying = true
    }

    func stop() {
        player.stop()
        if engine.isRunning {
            engine.stop()
        }
        isPlaying = false
        firstRenderedSampleTime = nil
        AudioSessionManager.deactivate()
    }


    private func makeBuffer(
        duration: TimeInterval,
        clicks: [MetronomeClick],
        timbre: MetronomeTimbre
    ) throws -> AVAudioPCMBuffer {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw MetronomeAudioEngineError.cannotCreateFormat
        }

        let totalFrames = max(1, AVAudioFrameCount((duration * sampleRate).rounded()))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            throw MetronomeAudioEngineError.cannotCreateBuffer
        }
        buffer.frameLength = totalFrames

        guard let channel = buffer.floatChannelData?[0] else {
            throw MetronomeAudioEngineError.cannotCreateBuffer
        }
        channel.initialize(repeating: 0, count: Int(totalFrames))

        let clickDuration = 0.028
        let clickFrames = max(1, Int(clickDuration * sampleRate))

        for click in clicks {
            let startFrame = Int((click.time * sampleRate).rounded())
            guard startFrame < Int(totalFrames) else { continue }
            let frequency = click.isAccent ? timbre.accentFrequency : timbre.beatFrequency
            let amplitude = click.isAccent ? 0.85 : 0.55

            for offset in 0..<clickFrames {
                let frame = startFrame + offset
                guard frame < Int(totalFrames) else { break }
                let time = Double(offset) / sampleRate
                let envelope = exp(-time * timbre.decay)
                var tone = sin(2 * Double.pi * frequency * time)
                if timbre.addsOctaveHarmonic {
                    tone += sin(2 * Double.pi * frequency * 2 * time) * 0.28
                }
                let sample = Float(tone * envelope * amplitude)
                channel[frame] = max(-1, min(1, channel[frame] + sample))
            }
        }

        return buffer
    }
}

enum MetronomeAudioEngineError: LocalizedError {
    case cannotCreateFormat
    case cannotCreateBuffer

    var errorDescription: String? {
        switch self {
        case .cannotCreateFormat:
            return "无法创建节拍器音频格式。"
        case .cannotCreateBuffer:
            return "无法创建节拍器音频缓冲区。"
        }
    }
}
