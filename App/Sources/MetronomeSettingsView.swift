import SwiftUI
import TuneCore

struct MetronomeSoundSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        Form {
            Section("节拍器音色") {
                Picker(selection: $metronome.timbre) {
                    ForEach(MetronomeTimbre.allCases) { timbre in
                        Text(verbatim: timbre.title).tag(timbre)
                    }
                } label: {
                    Text(verbatim: "节拍器音色")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "节拍器音色"))
            }

            Section("触觉") {
                Toggle(isOn: $metronome.hapticsEnabled) {
                    Text(verbatim: "播放时使用触觉打拍")
                }
            }

            Section {
                Text(verbatim: "锁屏和后台播放时，触觉不保证持续可用；音频点击声始终是主要节拍提示。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("节拍器声音")
    }
}
