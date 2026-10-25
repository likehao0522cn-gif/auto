import Combine
import Foundation
import TuneCore

enum AutoUpdateFeedbackMode: String, CaseIterable, Identifiable, Hashable {
    case numberAndHaptics
    case earconAndHaptics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .numberAndHaptics:
            return "变化数字 + 触觉"
        case .earconAndHaptics:
            return "仅短音型 + 触觉"
        }
    }
}

enum NoteNamingStyle: String, CaseIterable, Identifiable, Hashable {
    case letter
    case solfege

    var id: String { rawValue }

    var title: String {
        switch self {
        case .letter: return "字母音名 C4"
        case .solfege: return "固定唱名 do4"
        }
    }
}

enum NoteNamingFormatter {
    private static let solfegeNames = [
        "do", "do#", "re", "re#", "mi", "fa",
        "fa#", "sol", "sol#", "la", "la#", "si"
    ]

    static func noteName(midi: Int, style: NoteNamingStyle) -> String {
        let note = Note(midi: midi)
        switch style {
        case .letter:
            return note.displayName
        case .solfege:
            return "\(solfegeNames[note.pitchClass])\(note.octave)"
        }
    }

    static func stringDisplayName(_ string: TuningString, style: NoteNamingStyle) -> String {
        "\(string.numberLabel)，\(noteName(midi: string.midi, style: style))"
    }
}

enum ReferenceToneTimbre: String, CaseIterable, Identifiable, Hashable {
    case sine
    case piano

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sine: return "纯正弦音"
        case .piano: return "钢琴音色"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedPresetID: String {
        didSet { save() }
    }

    @Published var selectedStringID: String? {
        didSet { save() }
    }

    @Published var pianoTargetMIDI: Int {
        didSet { save() }
    }

    @Published var concertA: Double {
        didSet { save() }
    }

    @Published var toleranceCents: Double {
        didSet { save() }
    }

    @Published var autoUpdateFeedbackMode: AutoUpdateFeedbackMode {
        didSet { save() }
    }

    @Published var noteNamingStyle: NoteNamingStyle {
        didSet { save() }
    }

    @Published var referenceToneTimbre: ReferenceToneTimbre {
        didSet { save() }
    }

    @Published var language: AppLanguage {
        didSet { save() }
    }

    let presets: [InstrumentPreset] = PresetCatalog.all

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let presetID = defaults.string(forKey: Keys.presetID) ?? PresetCatalog.guitar.id
        let preset = PresetCatalog.preset(withID: presetID) ?? PresetCatalog.guitar
        self.selectedPresetID = preset.id
        self.selectedStringID = defaults.string(forKey: Keys.stringID) ?? preset.strings.first?.id
        self.pianoTargetMIDI = defaults.object(forKey: Keys.pianoTargetMIDI) as? Int ?? 69
        self.concertA = defaults.object(forKey: Keys.concertA) as? Double ?? 440
        self.toleranceCents = defaults.object(forKey: Keys.toleranceCents) as? Double ?? 3
        self.autoUpdateFeedbackMode = AutoUpdateFeedbackMode(
            rawValue: defaults.string(forKey: Keys.autoUpdateFeedbackMode) ?? ""
        ) ?? .numberAndHaptics
        self.noteNamingStyle = NoteNamingStyle(
            rawValue: defaults.string(forKey: Keys.noteNamingStyle) ?? ""
        ) ?? .letter
        self.referenceToneTimbre = ReferenceToneTimbre(
            rawValue: defaults.string(forKey: Keys.referenceToneTimbre) ?? ""
        ) ?? .sine
        self.language = AppLanguage(
            rawValue: defaults.string(forKey: Keys.language) ?? ""
        ) ?? .simplifiedChinese
    }

    var selectedPreset: InstrumentPreset {
        PresetCatalog.preset(withID: selectedPresetID) ?? PresetCatalog.guitar
    }

    var selectedString: TuningString? {
        guard let selectedStringID else { return nil }
        return selectedPreset.strings.first { $0.id == selectedStringID }
    }

    var selectedTargetDisplayName: String? {
        guard let target = selectedTargetString else { return nil }
        return NoteNamingFormatter.stringDisplayName(target, style: noteNamingStyle)
    }

    func displayName(for string: TuningString) -> String {
        NoteNamingFormatter.stringDisplayName(string, style: noteNamingStyle)
    }

    func displayName(forMIDI midi: Int) -> String {
        NoteNamingFormatter.noteName(midi: midi, style: noteNamingStyle)
    }

    var selectedTargetString: TuningString? {
        if selectedPreset.isPiano {
            return TuningString(
                id: "piano-target",
                numberLabel: "目标音",
                midi: pianoTargetMIDI
            )
        }
        return selectedString
    }

    func selectPreset(_ preset: InstrumentPreset) {
        selectedPresetID = preset.id
        selectedStringID = preset.strings.first?.id
    }

    func selectString(_ string: TuningString) {
        selectedStringID = string.id
    }

    private func save() {
        defaults.set(selectedPresetID, forKey: Keys.presetID)
        defaults.set(selectedStringID, forKey: Keys.stringID)
        defaults.set(pianoTargetMIDI, forKey: Keys.pianoTargetMIDI)
        defaults.set(concertA, forKey: Keys.concertA)
        defaults.set(toleranceCents, forKey: Keys.toleranceCents)
        defaults.set(autoUpdateFeedbackMode.rawValue, forKey: Keys.autoUpdateFeedbackMode)
        defaults.set(noteNamingStyle.rawValue, forKey: Keys.noteNamingStyle)
        defaults.set(referenceToneTimbre.rawValue, forKey: Keys.referenceToneTimbre)
        defaults.set(language.rawValue, forKey: Keys.language)
    }

    private enum Keys {
        static let presetID = "selectedPresetID"
        static let stringID = "selectedStringID"
        static let pianoTargetMIDI = "pianoTargetMIDI"
        static let concertA = "concertA"
        static let toleranceCents = "toleranceCents"
        static let autoUpdateFeedbackMode = "autoUpdateFeedbackMode"
        static let noteNamingStyle = "noteNamingStyle"
        static let referenceToneTimbre = "referenceToneTimbre"
        static let language = "language"
    }
}



