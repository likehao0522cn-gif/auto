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
                Picker(selection: $octave) {
                    ForEach(0...8, id: \.self) { octave in
                        Text(verbatim: "第 \(octave) 八度").tag(octave)
                    }
                } label: {
                    Text(verbatim: "八度")
                }
                .accessibilityLabel(Text(verbatim: "八度"))

                Picker(selection: $noteIndex) {
                    ForEach(availableNoteIndices, id: \.self) { index in
                        Text(verbatim: appModel.displayName(forMIDI: (octave + 1) * 12 + index)).tag(index)
                    }
                } label: {
                    Text(verbatim: "音名")
                }
                .accessibilityLabel(Text(verbatim: "音名"))
            }

            Section {
                Text(verbatim: "当前目标：\(appModel.displayName(forMIDI: selectedMIDI))")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "当前目标"))
                    .accessibilityValue(Text(verbatim: appModel.displayName(forMIDI: selectedMIDI)))

                Button {
                    appModel.pianoTargetMIDI = selectedMIDI
                    dismiss()
                } label: {
                    Text(verbatim: "应用目标音")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "应用目标音"))
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
