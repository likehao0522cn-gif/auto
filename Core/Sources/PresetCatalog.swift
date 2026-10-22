import Foundation

public enum PresetKind: String, Hashable, Sendable {
    case chromatic
    case strings
    case piano
}

public enum DetectionMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case locked
    case automatic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .locked: return "锁定目标音"
        case .automatic: return "自动识别"
        }
    }
}

public struct TuningString: Identifiable, Hashable, Sendable {
    public let id: String
    public let numberLabel: String
    public let midi: Int

    public init(id: String, numberLabel: String, midi: Int) {
        self.id = id
        self.numberLabel = numberLabel
        self.midi = midi
    }

    public var note: Note { Note(midi: midi) }

    public var displayName: String {
        "\(numberLabel)，\(note.displayName)"
    }
}

public struct InstrumentPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let kind: PresetKind
    public let strings: [TuningString]
    public let defaultMode: DetectionMode

    public init(
        id: String,
        displayName: String,
        kind: PresetKind,
        strings: [TuningString],
        defaultMode: DetectionMode
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.strings = strings
        self.defaultMode = defaultMode
    }

    public var isPiano: Bool { kind == .piano }
    public var isChromatic: Bool { kind == .chromatic }
}

public enum PresetCatalog {
    public static let chromatic = InstrumentPreset(
        id: "chromatic",
        displayName: "半音模式",
        kind: .chromatic,
        strings: [],
        defaultMode: .automatic
    )

    public static let guitar = InstrumentPreset(
        id: "guitar",
        displayName: "吉他",
        kind: .strings,
        strings: [
            TuningString(id: "guitar-6", numberLabel: "六弦", midi: 40),
            TuningString(id: "guitar-5", numberLabel: "五弦", midi: 45),
            TuningString(id: "guitar-4", numberLabel: "四弦", midi: 50),
            TuningString(id: "guitar-3", numberLabel: "三弦", midi: 55),
            TuningString(id: "guitar-2", numberLabel: "二弦", midi: 59),
            TuningString(id: "guitar-1", numberLabel: "一弦", midi: 64)
        ],
        defaultMode: .locked
    )

    public static let ukulele = InstrumentPreset(
        id: "ukulele",
        displayName: "尤克里里",
        kind: .strings,
        strings: [
            TuningString(id: "ukulele-4", numberLabel: "四弦", midi: 67),
            TuningString(id: "ukulele-3", numberLabel: "三弦", midi: 60),
            TuningString(id: "ukulele-2", numberLabel: "二弦", midi: 64),
            TuningString(id: "ukulele-1", numberLabel: "一弦", midi: 69)
        ],
        defaultMode: .locked
    )

    public static let violin = InstrumentPreset(
        id: "violin",
        displayName: "小提琴",
        kind: .strings,
        strings: [
            TuningString(id: "violin-4", numberLabel: "四弦", midi: 55),
            TuningString(id: "violin-3", numberLabel: "三弦", midi: 62),
            TuningString(id: "violin-2", numberLabel: "二弦", midi: 69),
            TuningString(id: "violin-1", numberLabel: "一弦", midi: 76)
        ],
        defaultMode: .locked
    )

    public static let cello = InstrumentPreset(
        id: "cello",
        displayName: "大提琴",
        kind: .strings,
        strings: [
            TuningString(id: "cello-4", numberLabel: "四弦", midi: 36),
            TuningString(id: "cello-3", numberLabel: "三弦", midi: 43),
            TuningString(id: "cello-2", numberLabel: "二弦", midi: 50),
            TuningString(id: "cello-1", numberLabel: "一弦", midi: 57)
        ],
        defaultMode: .locked
    )

    public static let erhu = InstrumentPreset(
        id: "erhu",
        displayName: "二胡",
        kind: .strings,
        strings: [
            TuningString(id: "erhu-inner", numberLabel: "内弦", midi: 62),
            TuningString(id: "erhu-outer", numberLabel: "外弦", midi: 69)
        ],
        defaultMode: .locked
    )

    public static let guzheng: InstrumentPreset = {
        let midiNotes = [
            38, 40, 42, 45, 47,
            50, 52, 54, 57, 59,
            62, 64, 66, 69, 71,
            74, 76, 78, 81, 83,
            86
        ]
        let strings = midiNotes.enumerated().map { index, midi in
            TuningString(
                id: "guzheng-\(index + 1)",
                numberLabel: "第 \(index + 1) 弦（由低到高）",
                midi: midi
            )
        }
        return InstrumentPreset(
            id: "guzheng",
            displayName: "古筝",
            kind: .strings,
            strings: strings,
            defaultMode: .locked
        )
    }()

    public static let pipa = InstrumentPreset(
        id: "pipa",
        displayName: "琵琶",
        kind: .strings,
        strings: [
            TuningString(id: "pipa-4", numberLabel: "四弦", midi: 45),
            TuningString(id: "pipa-3", numberLabel: "三弦", midi: 50),
            TuningString(id: "pipa-2", numberLabel: "二弦", midi: 52),
            TuningString(id: "pipa-1", numberLabel: "一弦", midi: 57)
        ],
        defaultMode: .locked
    )

    public static let piano = InstrumentPreset(
        id: "piano",
        displayName: "钢琴",
        kind: .piano,
        strings: [],
        defaultMode: .automatic
    )

    public static let all: [InstrumentPreset] = [
        chromatic,
        guitar,
        ukulele,
        violin,
        cello,
        erhu,
        guzheng,
        pipa,
        piano
    ]

    public static func preset(withID id: String) -> InstrumentPreset? {
        all.first { $0.id == id }
    }
}

