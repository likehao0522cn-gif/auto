import SwiftUI
import TuneCore

struct BeatSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel
    @EnvironmentObject private var appModel: AppModel

    private var timeSignatureBinding: Binding<TimeSignature> {
        Binding(
            get: { metronome.configuration.timeSignature },
            set: { metronome.configuration.timeSignature = $0 }
        )
    }

    var body: some View {
        Form {
            Section("节拍") {
                Picker(selection: timeSignatureBinding) {
                    ForEach(TimeSignature.presets) { signature in
                        Text(verbatim: signature.id)
                            .tag(signature)
                            .accessibilityLabel(Text(verbatim: "拍号 \(signature.spokenTitle)"))
                    }
                } label: {
                    Text(verbatim: "拍号")
                }
                .pickerStyle(.inline)
            }

            Section("重音") {
                Picker(selection: $metronome.configuration.accentMode) {
                    ForEach(AccentMode.allCases) { accent in
                        Text(verbatim: accent.title)
                            .tag(accent)
                            .accessibilityLabel(Text(verbatim: accent.spokenTitle))
                    }
                } label: {
                    Text(verbatim: "重音")
                }
                .pickerStyle(.inline)
            }

            Section("细分拍") {
                Picker(selection: $metronome.configuration.subdivision) {
                    ForEach(Subdivision.allCases) { subdivision in
                        Text(verbatim: subdivision.title)
                            .tag(subdivision)
                            .accessibilityLabel(Text(verbatim: subdivision.spokenTitle))
                    }
                } label: {
                    Text(verbatim: "细分拍")
                }
                .pickerStyle(.inline)
            }

            Section("声音") {
                Picker(selection: $metronome.timbre) {
                    ForEach(MetronomeTimbre.allCases) { timbre in
                        Text(verbatim: timbre.title)
                            .tag(timbre)
                            .accessibilityLabel(Text(verbatim: timbre.spokenTitle))
                    }
                } label: {
                    Text(verbatim: "节拍器音色")
                }
                .pickerStyle(.inline)

                Toggle(isOn: $metronome.hapticsEnabled) {
                    Text(verbatim: "播放时使用触觉打拍")
                }

                Text(verbatim: "锁屏和后台播放时，触觉不保证持续可用；音频点击声始终是主要节拍提示。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("测速") {
                Toggle(isOn: $appModel.tapTempoCountdownHintEnabled) {
                    Text(verbatim: "显示还差几拍提示")
                }
                .accessibilityLabel(Text(verbatim: "显示还差几拍提示"))
                .accessibilityHint(Text(verbatim: "开启时显示距离第一个速度结果还差几拍"))
            }

            Section("帮助") {
                NavigationLink {
                    MetronomeHelpView()
                } label: {
                    Text(verbatim: "节拍器帮助")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "节拍器帮助"))
            }
        }
        .navigationTitle("节拍器设置")
    }
}
