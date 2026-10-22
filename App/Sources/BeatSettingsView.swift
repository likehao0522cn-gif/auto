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
                Picker("拍号", selection: timeSignatureBinding) {
                    ForEach(TimeSignature.presets) { signature in
                        Text(signature.id).tag(signature)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityLabel("拍号")
            }

            Section("重音") {
                Picker("重音", selection: $metronome.configuration.accentMode) {
                    ForEach(AccentMode.allCases) { accent in
                        Text(accent.title).tag(accent)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("细分拍") {
                Picker("细分拍", selection: $metronome.configuration.subdivision) {
                    ForEach(Subdivision.allCases) { subdivision in
                        Text(subdivision.title).tag(subdivision)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("节拍设置")
    }
}
