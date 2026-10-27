import AVFoundation
import TuneCore

enum TunerAudioEngineError: LocalizedError {
    case noInputAvailable
    case permissionDenied
    case engineNotRunning

    var errorDescription: String? {
        switch self {
        case .noInputAvailable:
            return "没有可用的麦克风输入。"
        case .permissionDenied:
            return "麦克风权限未开启。"
        case .engineNotRunning:
            return "调音器当前没有在聆听。"
        }
    }
}

final class TunerAudioEngine {
    private let engine = AVAudioEngine()
    private let detector = PitchDetector()
    private let tonePlayer = AVAudioPlayerNode()
    private var toneAttached = false
    private var toneGeneration = 0
    private let analysisQueue = DispatchQueue(
        label: "com.shm06.TuneMetronome.pitch-analysis",
        qos: .userInitiated
    )
    private var isRunning = false
    private var generation = 0
    private var tapInstalled = false

    func start(onEstimate: @escaping (PitchEstimate) -> Void) throws {
        guard !isRunning else { return }

        let session = AVAudioSession.sharedInstance()
        guard session.recordPermission != .denied else {
            throw TunerAudioEngineError.permissionDenied
        }

        try AudioSessionManager.configureForTuner()
        generation += 1
        let currentGeneration = generation

        if !toneAttached {
            engine.attach(tonePlayer)
            let toneFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            engine.connect(tonePlayer, to: engine.mainMixerNode, format: toneFormat)
            toneAttached = true
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            AudioSessionManager.deactivate()
            throw TunerAudioEngineError.noInputAvailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 8_192, format: format) { [weak self] buffer, _ in
            guard let self, let samples = Self.monoSamples(from: buffer) else { return }
            let sampleRate = buffer.format.sampleRate
            self.analysisQueue.async { [weak self] in
                guard let self else { return }
                let estimate = self.detector.detect(samples: samples, sampleRate: sampleRate)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == currentGeneration, self.isRunning else { return }
                    onEstimate(estimate)
                }
            }
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
            isRunning = true
        } catch {
            inputNode.removeTap(onBus: 0)
            tapInstalled = false
            AudioSessionManager.deactivate()
            throw error
        }
    }

    func stop() {
        toneGeneration += 1
        guard isRunning || tapInstalled else { return }
        generation += 1
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        tonePlayer.stop()
        engine.stop()
        isRunning = false
        AudioSessionManager.deactivate()
    }

    func playReferenceTone(
        frequency: Double,
        timbre: ReferenceToneTimbre,
        duration: Double = 2.0,
        onFinish: @escaping () -> Void
    ) throws {
        guard isRunning else { throw TunerAudioEngineError.engineNotRunning }
        guard frequency > 0, duration > 0.1 else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
            throw TunerAudioEngineError.noInputAvailable
        }
        let frameCount = AVAudioFrameCount((duration * 44_100).rounded())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else {
            throw TunerAudioEngineError.noInputAvailable
        }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / 44_100
            let fadeIn = min(1, time * 40)
            let fadeOut = min(1, (duration - time) * 20)
            let envelope = max(0, min(fadeIn, fadeOut))
            let sample: Double

            switch timbre {
            case .sine:
                sample = sin(2 * Double.pi * frequency * time)
            case .piano:
                let decay = exp(-time * 1.4)
                sample = (
                    sin(2 * Double.pi * frequency * time) * 0.72
                    + sin(2 * Double.pi * frequency * 2 * time) * 0.18
                    + sin(2 * Double.pi * frequency * 3 * time) * 0.07
                ) * decay
            }

            channel[frame] = Float(sample * envelope * 0.22)
        }

        tonePlayer.stop()
        toneGeneration += 1
        let currentToneGeneration = toneGeneration
        tonePlayer.scheduleBuffer(buffer, at: nil, options: [])
        tonePlayer.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard self.toneGeneration == currentToneGeneration else { return }
            onFinish()
        }
    }

    func playEarcon(
        cents: Double,
        isInTune: Bool,
        onFinish: @escaping () -> Void
    ) throws {
        guard isRunning else { throw TunerAudioEngineError.engineNotRunning }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
            throw TunerAudioEngineError.noInputAvailable
        }
        if isInTune {
            let confirmationDuration = 0.18
            let confirmationFrames = AVAudioFrameCount((confirmationDuration * 44_100).rounded())
            guard let confirmationBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: confirmationFrames
            ), let confirmationChannel = confirmationBuffer.floatChannelData?[0] else {
                throw TunerAudioEngineError.noInputAvailable
            }
            confirmationBuffer.frameLength = confirmationFrames

            for frame in 0..<Int(confirmationFrames) {
                let time = Double(frame) / 44_100
                let envelope = max(0, min(1, min(time * 60, (confirmationDuration - time) * 60)))
                let sample = sin(2 * Double.pi * 1_320 * time) * envelope * 0.2
                confirmationChannel[frame] = Float(sample)
            }

            tonePlayer.stop()
            toneGeneration += 1
            let currentToneGeneration = toneGeneration
            tonePlayer.scheduleBuffer(confirmationBuffer, at: nil, options: [])
            tonePlayer.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + confirmationDuration) {
                guard self.toneGeneration == currentToneGeneration else { return }
                onFinish()
            }
            return
        }

        let duration = 0.22
        let frameCount = AVAudioFrameCount((duration * 44_100).rounded())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else {
            throw TunerAudioEngineError.noInputAvailable
        }
        buffer.frameLength = frameCount

        let isHigh = cents >= 0
        let firstFrequency = isHigh ? 880.0 : 1_320.0
        let secondFrequency = isHigh ? 1_320.0 : 880.0
        let halfDuration = duration / 2

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / 44_100
            let frequency = time < halfDuration ? firstFrequency : secondFrequency
            let localTime = time.truncatingRemainder(dividingBy: halfDuration)
            let envelope = max(0, min(1, min(localTime * 60, (halfDuration - localTime) * 60)))
            let sample = sin(2 * Double.pi * frequency * localTime) * envelope * 0.18
            channel[frame] = Float(sample)
        }

        tonePlayer.stop()
        toneGeneration += 1
        let currentToneGeneration = toneGeneration
        tonePlayer.scheduleBuffer(buffer, at: nil, options: [])
        tonePlayer.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard self.toneGeneration == currentToneGeneration else { return }
            onFinish()
        }
    }
    private static func monoSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return nil }
        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0 else { return nil }

        var samples = [Float](repeating: 0, count: frameLength)
        if buffer.format.isInterleaved {
            let data = channelData[0]
            for frame in 0..<frameLength {
                samples[frame] = data[frame * channelCount]
            }
        } else {
            let data = channelData[0]
            for frame in 0..<frameLength {
                samples[frame] = data[frame]
            }
        }
        return samples
    }
}






