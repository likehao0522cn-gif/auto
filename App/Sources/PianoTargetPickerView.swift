import SwiftUI
import TuneCore

struct PianoTargetPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var octave: Int = 4
    @State private var noteIndex: Int = 9

    private var availableNoteIndices: [Int] {
        if octave == 0 { return Array(9...11) }
        if octave == 8 { return [0] }
        return Array(0...11)
    }

    private var selectedMIDI: Int {
        (octave + 1) * 12 + noteIndex
    }

    var body: some View {
        Form {
            Section("选择目标音") {
                Picker("八度", selection: $octave) {
                    ForEach(0...8, id: \.self) { octave in
                        Text("第 \(octave) 八度").tag(octave)
                    }
                }

                Picker("音名", selection: $noteIndex) {
                    ForEach(availableNoteIndices, id: \.self) { index in
                        Text(Note(midi: (octave + 1) * 12 + index).name).tag(index)
                    }
                }
            }

            Section {
                Text("当前目标：\(Note(midi: selectedMIDI).displayName)")
                    .accessibilityLabel("当前目标")
                    .accessibilityValue(Note(midi: selectedMIDI).displayName)

                Button("应用目标音") {
                    appModel.pianoTargetMIDI = selectedMIDI
                    dismiss()
                }
                .accessibilityHint("返回调音器并使用这个目标音")
            }
        }
        .navigationTitle("钢琴目标音")
        .onAppear {
            let midi = min(108, max(21, appModel.pianoTargetMIDI))
            octave = midi / 12 - 1
            noteIndex = midi % 12
        }
        .onChange(of: octave) { _, _ in
            if !availableNoteIndices.contains(noteIndex) {
                noteIndex = availableNoteIndices[0]
            }
        }
    }
}
