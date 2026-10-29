import Foundation

enum SpeechOutputMode: String, CaseIterable, Identifiable, Hashable {
    case appVoice
    case automatic
    case voiceOver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appVoice:
            return "应用语音"
        case .automatic:
            return "自动：旁白开启时使用旁白"
        case .voiceOver:
            return "旁白播报"
        }
    }

    var detail: String {
        switch self {
        case .appVoice:
            return "使用应用内语音，可以分别调整语速和音调。"
        case .automatic:
            return "旁白开启时使用旁白声音和语速；旁白关闭时使用应用语音。"
        case .voiceOver:
            return "使用系统旁白的声音和语速，应用内的语速和音调设置不生效。"
        }
    }
}

struct SpeechSettings {
    static let defaultRate = 0.48
    static let defaultPitch = 1.0
    static let minimumRate = 0.30
    static let maximumRate = 0.70
    static let minimumPitch = 0.80
    static let maximumPitch = 1.20

    var rate: Double
    var pitch: Double
    var outputMode: SpeechOutputMode

    init(
        rate: Double = SpeechSettings.defaultRate,
        pitch: Double = SpeechSettings.defaultPitch,
        outputMode: SpeechOutputMode = .appVoice
    ) {
        self.rate = min(Self.maximumRate, max(Self.minimumRate, rate))
        self.pitch = min(Self.maximumPitch, max(Self.minimumPitch, pitch))
        self.outputMode = outputMode
    }

    static func load(from defaults: UserDefaults = .standard) -> SpeechSettings {
        let storedRate = defaults.object(forKey: Keys.rate) as? Double ?? defaultRate
        let storedPitch = defaults.object(forKey: Keys.pitch) as? Double ?? defaultPitch
        let storedMode = SpeechOutputMode(
            rawValue: defaults.string(forKey: Keys.outputMode) ?? ""
        ) ?? .appVoice
        return SpeechSettings(rate: storedRate, pitch: storedPitch, outputMode: storedMode)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rate, forKey: Keys.rate)
        defaults.set(pitch, forKey: Keys.pitch)
        defaults.set(outputMode.rawValue, forKey: Keys.outputMode)
    }

    static func rateLabel(_ rate: Double) -> String {
        let clamped = min(maximumRate, max(minimumRate, rate))
        let descriptor: String
        switch clamped {
        case ..<0.40: descriptor = "慢"
        case ..<0.46: descriptor = "稍慢"
        case ..<0.53: descriptor = "标准"
        case ..<0.61: descriptor = "稍快"
        default: descriptor = "快"
        }
        return "\(descriptor)，\(String(format: "%.2f", clamped))"
    }

    static func pitchLabel(_ pitch: Double) -> String {
        let clamped = min(maximumPitch, max(minimumPitch, pitch))
        let descriptor: String
        switch clamped {
        case ..<0.90: descriptor = "低"
        case ..<0.97: descriptor = "稍低"
        case ..<1.05: descriptor = "标准"
        case ..<1.13: descriptor = "稍高"
        default: descriptor = "高"
        }
        return "\(descriptor)，\(String(format: "%.2f", clamped))"
    }

    private enum Keys {
        static let rate = "speechRate"
        static let pitch = "speechPitch"
        static let outputMode = "speechOutputMode"
    }
}
