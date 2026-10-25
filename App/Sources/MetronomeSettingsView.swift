import SwiftUI
import TuneCore

struct MetronomeSoundSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        Form {
            Section("节拍器音色") {
                Picker("节拍器音色", selection: $metronome.timbre) {
                    ForEach(MetronomeTimbre.allCases) { timbre in
                        Text(timbre.title).tag(timbre)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("触觉") {
                Toggle("播放时使用触觉打拍", isOn: $metronome.hapticsEnabled)
                    .accessibilityHint("开启后，节拍器播放期间会按当前拍号和细分拍产生震动")
            }

            Section {
                Text("锁屏和后台播放时，触觉不保证持续可用；音频点击声始终是主要节拍提示。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("节拍器声音")
    }
}