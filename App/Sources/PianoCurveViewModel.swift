import Foundation
import TuneCore

/// Holds the piano tuning curve the user is currently working with.
///
/// This is deliberately separate from TunerViewModel. Selecting a curve is a
/// configuration concern; the tuner only needs to ask for the target frequency
/// of a key. Keeping them apart means the curve screen can be tested and
/// changed without touching the audio path.
@MainActor
final class PianoCurveViewModel: ObservableObject {
    /// Identifier of the selected template, or nil when the curve comes from a
    /// measured profile.
    @Published private(set) var selectedTemplateID: String? {
        didSet { defaults.set(selectedTemplateID, forKey: Keys.templateID) }
    }

    /// The measured profile, when the user has measured this piano.
    @Published private(set) var measuredProfile: InharmonicityProfile?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedTemplateID = defaults.string(forKey: Keys.templateID)
    }

    /// The template the user picked, falling back to large upright.
    var selectedTemplate: PianoModelTemplate {
        guard let id = selectedTemplateID, let template = PianoModelTemplate.template(withID: id) else {
            return .largeUpright
        }
        return template
    }

    /// The curve to use for tuning. A measured profile wins over a template,
    /// because it describes the actual instrument.
    var curve: StretchCurve {
        if let profile = measuredProfile, !profile.trusted.isEmpty {
            return StretchCurveBuilder.measured(profile: profile)
        }
        return StretchCurveBuilder.template(for: selectedTemplate)
    }

    /// Spoken one-line summary of the current curve.
    var spokenSummary: String {
        StretchCurveNarration.summary(for: curve)
    }

    func selectTemplate(_ template: PianoModelTemplate) {
        selectedTemplateID = template.id
        measuredProfile = nil
    }

    func apply(measured profile: InharmonicityProfile) {
        measuredProfile = profile
        selectedTemplateID = nil
    }

    func useTemplateInstead() {
        measuredProfile = nil
        if selectedTemplateID == nil {
            selectedTemplateID = PianoModelTemplate.largeUpright.id
        }
    }

    /// Target frequency for a key under the selected curve and concert pitch.
    func targetFrequency(forMIDI midi: Int, concertA: Double = 440) -> Double {
        curve.stretchedFrequency(forMIDI: midi, concertA: concertA)
    }

    private enum Keys {
        static let templateID = "pianoCurveTemplateID"
    }
}
