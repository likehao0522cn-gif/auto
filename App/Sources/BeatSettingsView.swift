import SwiftUI
import TuneCore

struct BeatSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("节拍") {
                NavigationLink {
                    TimeSignatureSettingsView()
                } label: {
                    settingRow("拍号", value: metronome.configuration.timeSignature.id)
                }

                NavigationLink {
                    AccentSettingsView()
                } label: {
                    settingRow("重音", value: metronome.configuration.accentMode.title)
                }

                NavigationLink {
                    SubdivisionSettingsView()
                } label: {
                    settingRow("细分拍", value: metronome.configuration.subdivision.title)
                }
            }

            Section("声音") {
                NavigationLink {
                    MetronomeTimbreSettingsView()
                } label: {
                    settingRow("音色", value: metronome.timbre.title)
                }

                Toggle(isOn: $metronome.hapticsEnabled) {
                    Text(verbatim: "播放时触觉打拍")
                }
            }

            Section("测速") {
                Toggle(isOn: $appModel.tapTempoCountdownHintEnabled) {
                    Text(verbatim: "显示还差几拍提示")
                }
                .accessibilityHint(Text(verbatim: "开启时显示距离第一个速度结果还差几拍"))
            }

            Section("帮助") {
                NavigationLink {
                    MetronomeHelpView()
                } label: {
                    Text(verbatim: "节拍器帮助")
                }
            }
        }
        .navigationTitle("节拍器设置")
    }

    private func settingRow(_ title: String, value: String) -> some View {
        HStack {
            Text(verbatim: title)
            Spacer()
            Text(verbatim: value)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: value))
    }
}

private struct TimeSignatureSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        List {
            ForEach(TimeSignature.presets) { signature in
                Button {
                    metronome.configuration.timeSignature = signature
                } label: {
                    HStack {
                        Text(verbatim: signature.id)
                            .monospacedDigit()
                        Spacer()
                        if metronome.configuration.timeSignature == signature {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: signature.spokenTitle))
                .accessibilityAddTraits(
                    metronome.configuration.timeSignature == signature ? [.isSelected] : []
                )
            }
        }
        .navigationTitle("拍号")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AccentSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        List {
            ForEach(AccentMode.allCases) { accent in
                Button {
                    metronome.configuration.accentMode = accent
                } label: {
                    HStack {
                        Text(verbatim: accent.title)
                        Spacer()
                        if metronome.configuration.accentMode == accent {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: accent.spokenTitle))
                .accessibilityAddTraits(
                    metronome.configuration.accentMode == accent ? [.isSelected] : []
                )
            }
        }
        .navigationTitle("重音")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SubdivisionSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        List {
            ForEach(Subdivision.allCases) { subdivision in
                Button {
                    metronome.configuration.subdivision = subdivision
                } label: {
                    HStack {
                        Text(verbatim: subdivision.title)
                        Spacer()
                        if metronome.configuration.subdivision == subdivision {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: subdivision.spokenTitle))
                .accessibilityAddTraits(
                    metronome.configuration.subdivision == subdivision ? [.isSelected] : []
                )
            }
        }
        .navigationTitle("细分拍")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MetronomeTimbreSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        List {
            ForEach(MetronomeTimbre.allCases) { timbre in
                Button {
                    metronome.timbre = timbre
                } label: {
                    HStack {
                        Text(verbatim: timbre.title)
                        Spacer()
                        if metronome.timbre == timbre {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: timbre.spokenTitle))
                .accessibilityAddTraits(metronome.timbre == timbre ? [.isSelected] : [])
            }
        }
        .navigationTitle("节拍器音色")
        .navigationBarTitleDisplayMode(.inline)
    }
}