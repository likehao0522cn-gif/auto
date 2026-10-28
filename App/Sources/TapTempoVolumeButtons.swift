import Foundation
import AVFoundation
import MediaPlayer
import UIKit

@MainActor
final class TapTempoVolumeButtons: ObservableObject {
    private let audioSession = AVAudioSession.sharedInstance()
    private let volumeView = MPVolumeView(frame: CGRect(x: -2_000, y: -2_000, width: 1, height: 1))
    private var observation: NSKeyValueObservation?
    private var lastVolume: Float = 0
    private var onTap: (() -> Void)?
    private var isActive = false
    private var lastVolumeChangeAt: Date = .distantPast

    init() {
        volumeView.isHidden = true
    }

    func start(onTap: @escaping () -> Void) {
        guard !isActive else { return }
        isActive = true
        self.onTap = onTap
        lastVolume = audioSession.outputVolume

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: \.isKeyWindow) else {
            return
        }
        window.addSubview(volumeView)

        observation = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.handleVolumeChange(change.newValue)
            }
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        observation = nil
        volumeView.removeFromSuperview()
        onTap = nil
        lastVolumeChangeAt = .distantPast
    }

    private func handleVolumeChange(_ volume: Float?) {
        guard isActive, let volume, abs(volume - lastVolume) > 0.001 else { return }
        lastVolume = volume
        let now = Date()
        guard now.timeIntervalSince(lastVolumeChangeAt) > 0.08 else { return }
        lastVolumeChangeAt = now
        onTap?()

        let target: Float = volume > 0.5 ? 0.5 : 0.75
        (volumeView.subviews.compactMap { $0 as? UISlider }).first?.setValue(target, animated: false)
        lastVolume = target
    }
}
