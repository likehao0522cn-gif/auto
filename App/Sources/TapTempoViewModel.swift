import Combine
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

    func tap() {
        estimator.record(at: Date.timeIntervalSinceReferenceDate)
        tapCount = estimator.timestamps.count
        if estimator.hasEnoughTapsForInitialEstimate {
            bpm = estimator.bpm
            if !announcedInitialResult, let bpm {
                announcedInitialResult = true
                speech.speak("速度 \(Int(bpm.rounded()))")
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()

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
