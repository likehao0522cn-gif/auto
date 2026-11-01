import Foundation

enum MetronomeTimbre: String, CaseIterable, Identifiable, Hashable {
    case crisp
    case soft
    case electronic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crisp: return "清脆点击"
        case .soft: return "柔和木鱼"
        case .electronic: return "电子脉冲"
        }
    }

    var spokenTitle: String {
        switch self {
        case .crisp: return "清脆点击，明亮短促，容易从环境中听出"
        case .soft: return "柔和木鱼，低沉温暖，适合长时间练习"
        case .electronic: return "电子脉冲，带高频泛音，适合快速节奏"
        }
    }

    var accentFrequency: Double {
        switch self {
        case .crisp: return 1_760
        case .soft: return 960
        case .electronic: return 1_320
        }
    }

    var beatFrequency: Double {
        switch self {
        case .crisp: return 1_120
        case .soft: return 680
        case .electronic: return 880
        }
    }

    var decay: Double {
        switch self {
        case .crisp: return 95
        case .soft: return 55
        case .electronic: return 130
        }
    }

    var addsOctaveHarmonic: Bool {
        switch self {
        case .crisp, .soft: return false
        case .electronic: return true
        }
    }
}
