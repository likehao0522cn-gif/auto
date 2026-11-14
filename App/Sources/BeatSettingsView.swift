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
                    settingRow("拍号", value: metronome.configuration.timeSignature.accessibilityTitle)
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

            Section("定时") {
                Picker(selection: $metronome.timerPauseBehaviour) {
                    ForEach(TimerPauseBehaviour.allCases) { behaviour in
                        Text(verbatim: behaviour.title)
                            .tag(behaviour)
                            .accessibilityLabel(Text(verbatim: behaviour.spokenTitle))
                    }
                } label: {
                    Text(verbatim: "停止节拍器时")
                }
                .pickerStyle(.inline)
                .accessibilityHint(Text(verbatim: "决定停止节拍器时，定时是否继续走"))

                Text(verbatim: metronome.timerPauseBehaviour == .wallClock
                    ? "暂停期间也算在定时里，到点就停。"
                    : "暂停期间不计时，只算实际播放的时长。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

            Section("常用速度") {
                FavoritesSettingsRows(store: metronome.favorites)
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
                .accessibilityLabel(Text(verbatim: signature.accessibilityTitle))
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
/// Rows that edit the favorite tempo store. A dedicated subview is used so
/// `@ObservedObject` subscribes to the shared store and the rows refresh as
/// soon as they change.
private struct FavoritesSettingsRows: View {
    @ObservedObject var store: FavoriteTempoStore

    var body: some View {
        Toggle(isOn: $store.autoAddEnabled) {
            Text(verbatim: "自动加入常用速度")
        }
        .accessibilityHint(Text(verbatim: "同一个速度使用满 5 次且累计播放满 2 分钟，会自动加入常用速度列表"))

        SwipeChoiceRow(
            title: "常用速度排序",
            options: FavoriteTempoSort.allCases,
            selection: $store.sortOrder,
            label: { $0.title }
        )

        Text(verbatim: "常用速度最多保存 \(FavoriteTempoRules.capacity) 个。")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
