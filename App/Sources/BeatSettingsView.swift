import SwiftUI
import TuneCore

struct BeatSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    private var timeSignatureBinding: Binding<TimeSignature> {
        Binding(
            get: { metronome.configuration.timeSignature },
            set: { metronome.configuration.timeSignature = $0 }
        )
    }

    var body: some View {
        Form {
            Section("拍号") {
                Picker(selection: timeSignatureBinding) {
                    ForEach(TimeSignature.presets) { signature in
                        Text(verbatim: signature.id).tag(signature)
                    }
                } label: {
                    Text(verbatim: "拍号")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "拍号"))
            }

            Section("重音") {
                Picker(selection: $metronome.configuration.accentMode) {
                    ForEach(AccentMode.allCases) { accent in
                        Text(verbatim: accent.title).tag(accent)
                    }
                } label: {
                    Text(verbatim: "重音")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "重音"))
            }

            Section("细分拍") {
                Picker(selection: $metronome.configuration.subdivision) {
                    ForEach(Subdivision.allCases) { subdivision in
                        Text(verbatim: subdivision.title).tag(subdivision)
                    }
                } label: {
                    Text(verbatim: "细分拍")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "细分拍"))
            }
        }
        .navigationTitle("节拍设置")
    }
}
