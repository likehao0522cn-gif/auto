import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        List {
            if metronome.isPlaying {
                Section {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "节拍器正在播放")
                                .font(.headline)
                            Text(verbatim: "每分钟 \(Int(metronome.configuration.bpm)) 拍，拍号 \(metronome.configuration.timeSignature.id)")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            metronome.stop()
                        } label: {
                            Text(verbatim: "停止")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: "停止节拍器"))
                    }
                }
            }

            Section("快速开始") {
                NavigationLink {
                    TunerView()
                } label: {
                    Text(verbatim: "快速调音")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "快速调音"))

                NavigationLink {
                    MetronomeView()
                } label: {
                    Text(verbatim: "快速节拍")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "快速节拍"))
            }

            Section("工具") {
                NavigationLink {
                    TunerView()
                } label: {
                    Text(verbatim: "调音器")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "调音器"))

                NavigationLink {
                    MetronomeView()
                } label: {
                    Text(verbatim: "节拍器")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "节拍器"))

                NavigationLink {
                    HelpView()
                } label: {
                    Text(verbatim: "帮助")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "帮助"))

                NavigationLink {
                    SettingsView()
                } label: {
                    Text(verbatim: "设置")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "设置"))
            }

            Section("版本") {
                Text(verbatim: "语音设置测试版 2026-10-29")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "语音设置测试版，构建日期 2026 年 10 月 29 日"))
                    .accessibilityIdentifier("SPEECH_SETTINGS_2026_10_29")
            }

            Section("当前乐器") {
                Text(verbatim: "\(appModel.selectedPreset.displayName)\(appModel.selectedTargetDisplayName.map { "，" + $0 } ?? "")")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "当前乐器"))
                    .accessibilityValue(Text(verbatim: "\(appModel.selectedPreset.displayName)\(appModel.selectedTargetDisplayName.map { "，" + $0 } ?? "")"))
            }
        }
        .navigationTitle("调音节拍器")
    }
}

