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

    var spokenTitle: String {
        switch self {
        case .numberAndHaptics:
            return "变化数字加触觉，音高变化时朗读新的音分数字"
        case .earconAndHaptics:
            return "仅短音型加触觉，不朗读数字，只播放提示音型"
        }
    }
}

/// How long the app keeps treating a note as "already named". Inside the
/// window a repeated note reports only the new value.
enum RepeatNameWindow: Double, CaseIterable, Identifiable, Hashable {
    case off = 0
    case three = 3
    case five = 5
    case eight = 8
    case fifteen = 15
    case thirty = 30

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .off: return "关闭"
        case .three: return "3 秒"
        case .five: return "5 秒"
        case .eight: return "8 秒"
        case .fifteen: return "15 秒"
        case .thirty: return "30 秒"
        }
    }

    var spokenTitle: String {
        switch self {
        case .off: return "关闭，每次都朗读音名"
        case .three: return "3 秒"
        case .five: return "5 秒"
        case .eight: return "8 秒"
        case .fifteen: return "15 秒"
        case .thirty: return "30 秒"
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

    var spokenTitle: String {
        switch self {
        case .letter: return "字母音名，例如 C4、升F3"
        case .solfege: return "固定唱名，例如 do4、升fa3"
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

    /// Speech-friendly form. Display stays as C#4, but Chinese TTS/VoiceOver
    /// reads a bare "#" character by character, so sharpen is spelled out.
    static func spokenNoteName(midi: Int, style: NoteNamingStyle) -> String {
        let display = noteName(midi: midi, style: style)
        if display.contains("#") {
            return "升" + display.replacingOccurrences(of: "#", with: "")
        }
        return display
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

    var spokenTitle: String {
        switch self {
        case .sine: return "纯正弦音，单一频率，最容易听准"
        case .piano: return "钢琴音色，接近真实钢琴，带泛音"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simplifiedChinese: return "简体中文（当前版本仅提供中文）"
        case .english: return "英语（尚未提供）"
        }
    }

    var isAvailable: Bool {
        self == .simplifiedChinese
    }

    var spokenTitle: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "英语，尚未提供"
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

    /// Whether tuning deviation is shown as cents or hertz. The same unit is
    /// used for the on-screen text and the spoken result.
    @Published var tuningDisplayUnit: TuningDisplayUnit {
        didSet { save() }
    }

    /// Window during which a repeated note is announced by value only.
    @Published var repeatNameWindow: RepeatNameWindow {
        didSet { save() }
    }

    @Published var language: AppLanguage {
        didSet { save() }
    }

    @Published var tapTempoHapticsEnabled: Bool {
        didSet { save() }
    }

    @Published var tapTempoCountdownHintEnabled: Bool {
        didSet { save() }
    }

    /// When false, opening the tuner stays paused until the user taps
    /// "继续聆听". Useful when the room is noisy and the user wants to settle
    /// the instrument first.
    @Published var tunerAutoStartEnabled: Bool {
        didSet { save() }
    }

    @Published var speechRate: Double {
        didSet { save() }
    }

    @Published var speechPitch: Double {
        didSet { save() }
    }

    @Published var speechVolume: Double {
        didSet { save() }
    }

    @Published var speechOutputMode: SpeechOutputMode {
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
        self.tuningDisplayUnit = TuningDisplayUnit(
            rawValue: defaults.string(forKey: Keys.tuningDisplayUnit) ?? ""
        ) ?? .cents
        let storedRepeat = defaults.object(forKey: Keys.repeatNameWindow) as? Double
        self.repeatNameWindow = storedRepeat.flatMap(RepeatNameWindow.init(rawValue:)) ?? .eight
        let storedLanguage = AppLanguage(
            rawValue: defaults.string(forKey: Keys.language) ?? ""
        ) ?? .simplifiedChinese
        self.language = storedLanguage.isAvailable ? storedLanguage : .simplifiedChinese
        self.tapTempoHapticsEnabled = defaults.object(forKey: Keys.tapTempoHapticsEnabled) as? Bool ?? true
        self.tapTempoCountdownHintEnabled = defaults.object(forKey: Keys.tapTempoCountdownHintEnabled) as? Bool ?? true
        self.tunerAutoStartEnabled = defaults.object(forKey: Keys.tunerAutoStartEnabled) as? Bool ?? true
        let speechSettings = SpeechSettings.load(from: defaults)
        self.speechRate = speechSettings.rate
        self.speechPitch = speechSettings.pitch
        self.speechVolume = speechSettings.volume
        self.speechOutputMode = speechSettings.outputMode
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

    var speechSettings: SpeechSettings {
        SpeechSettings(
            rate: speechRate,
            pitch: speechPitch,
            volume: speechVolume,
            outputMode: speechOutputMode
        )
    }

    func restoreDefaults() {
        selectedPresetID = PresetCatalog.guitar.id
        selectedStringID = PresetCatalog.guitar.strings.first?.id
        pianoTargetMIDI = 69
        concertA = 440
        toleranceCents = 3
        autoUpdateFeedbackMode = .numberAndHaptics
        noteNamingStyle = .letter
        referenceToneTimbre = .sine
        tuningDisplayUnit = .cents
        repeatNameWindow = .eight
        language = .simplifiedChinese
        tapTempoHapticsEnabled = true
        tapTempoCountdownHintEnabled = true
        tunerAutoStartEnabled = true
        speechRate = SpeechSettings.defaultRate
        speechPitch = SpeechSettings.defaultPitch
        speechVolume = SpeechSettings.defaultVolume
        speechOutputMode = .appVoice
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
        defaults.set(tuningDisplayUnit.rawValue, forKey: Keys.tuningDisplayUnit)
        defaults.set(repeatNameWindow.rawValue, forKey: Keys.repeatNameWindow)
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(tapTempoHapticsEnabled, forKey: Keys.tapTempoHapticsEnabled)
        defaults.set(tapTempoCountdownHintEnabled, forKey: Keys.tapTempoCountdownHintEnabled)
        defaults.set(tunerAutoStartEnabled, forKey: Keys.tunerAutoStartEnabled)
        SpeechSettings(
            rate: speechRate,
            pitch: speechPitch,
            volume: speechVolume,
            outputMode: speechOutputMode
        )
            .save(to: defaults)
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
        static let tuningDisplayUnit = "tuningDisplayUnit"
        static let repeatNameWindow = "repeatNameWindow"
        static let language = "language"
        static let tapTempoHapticsEnabled = "tapTempoHapticsEnabled"
        static let tapTempoCountdownHintEnabled = "tapTempoCountdownHintEnabled"
        static let tunerAutoStartEnabled = "tunerAutoStartEnabled"
    }
}



