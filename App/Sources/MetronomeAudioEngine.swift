import AVFoundation
import TuneCore

final class MetronomeAudioEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var isAttached = false
    private var isPlaying = false
    private(set) var configuration = MetronomeConfiguration()

    func start(configuration: MetronomeConfiguration) throws {
        stop()
        self.configuration = configuration
        try AudioSessionManager.configureForMetronome()

        if !isAttached {
            engine.attach(player)
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            engine.connect(player, to: engine.mainMixerNode, format: format)
            isAttached = true
        }

        let barBuffer = try makeBuffer(
            duration: configuration.barDuration,
            clicks: MetronomePattern.clicks(for: configuration)
        )
        engine.prepare()
        try engine.start()

        if configuration.countInBars.rawValue > 0 {
            let countInDuration = configuration.barDuration * Double(configuration.countInBars.rawValue)
            let countInBuffer = try makeBuffer(
                duration: countInDuration,
                clicks: countInClicks(for: configuration)
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
        AudioSessionManager.deactivate()
    }

    private func countInClicks(for configuration: MetronomeConfiguration) -> [MetronomeClick] {
        let clicksPerBar = MetronomePattern.clicks(for: configuration)
        return (0..<configuration.countInBars.rawValue).flatMap { barIndex in
            clicksPerBar.map { click in
                MetronomeClick(
                    time: click.time + Double(barIndex) * configuration.barDuration,
                    isAccent: click.isAccent
                )
            }
        }
    }

    private func makeBuffer(duration: TimeInterval, clicks: [MetronomeClick]) throws -> AVAudioPCMBuffer {
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
            let frequency = click.isAccent ? 1_760.0 : 1_120.0
            let amplitude = click.isAccent ? 0.85 : 0.55

            for offset in 0..<clickFrames {
                let frame = startFrame + offset
                guard frame < Int(totalFrames) else { break }
                let time = Double(offset) / sampleRate
                let envelope = exp(-time * 95)
                let tone = sin(2 * Double.pi * frequency * time)
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
