import Foundation

public struct Note: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let midi: Int

    private static let sharpNames = [
        "C", "C#", "D", "D#", "E", "F",
        "F#", "G", "G#", "A", "A#", "B"
    ]

    public init(midi: Int) {
        self.midi = midi
    }

    public var pitchClass: Int {
        ((midi % 12) + 12) % 12
    }

    public var name: String {
        Self.sharpNames[pitchClass]
    }

    public var octave: Int {
        midi / 12 - 1
    }

    public var displayName: String {
        "\(name)\(octave)"
    }

    public var description: String {
        displayName
    }
}

public struct NearestNote: Equatable, Sendable {
    public let note: Note
    public let midi: Double
    public let cents: Double

    public init(note: Note, midi: Double, cents: Double) {
        self.note = note
        self.midi = midi
        self.cents = cents
    }
}

public enum PitchMath {
    public static let referenceMIDI: Double = 69
    public static let semitonesPerOctave: Double = 12
    public static let centsPerSemitone: Double = 100

    public static func frequency(forMIDI midi: Double, concertA: Double = 440) -> Double {
        concertA * pow(2, (midi - referenceMIDI) / semitonesPerOctave)
    }

    public static func frequency(for note: Note, concertA: Double = 440) -> Double {
        frequency(forMIDI: Double(note.midi), concertA: concertA)
    }

    public static func midi(forFrequency frequency: Double, concertA: Double = 440) -> Double? {
        guard frequency > 0, concertA > 0 else { return nil }
        return referenceMIDI + semitonesPerOctave * log2(frequency / concertA)
    }

    public static func cents(from frequency: Double, to target: Double) -> Double? {
        guard frequency > 0, target > 0 else { return nil }
        return 1200 * log2(frequency / target)
    }

    public static func nearestNote(to frequency: Double, concertA: Double = 440) -> NearestNote? {
        guard let midi = midi(forFrequency: frequency, concertA: concertA) else { return nil }
        let nearestMIDI = Int(midi.rounded())
        let note = Note(midi: nearestMIDI)
        let target = frequency(for: note, concertA: concertA)
        guard let cents = cents(from: frequency, to: target), cents.isFinite else { return nil }
        return NearestNote(note: note, midi: midi, cents: cents)
    }

    public static func formatCents(_ cents: Double) -> String {
        let rounded = Int(cents.rounded())
        if rounded == 0 {
            return "准"
        }
        return rounded > 0 ? "高 \(rounded) 音分" : "低 \(abs(rounded)) 音分"
    }
}


