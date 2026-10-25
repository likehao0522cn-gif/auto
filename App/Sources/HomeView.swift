import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        List {
            if metronome.isPlaying {
                Section {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "metronome.fill")
                            .font(.title2)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("节拍器正在播放")
                                .font(.headline)
                            Text("\(Int(metronome.configuration.bpm)) BPM，\(metronome.configuration.timeSignature.id)")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("停止") {
                            metronome.stop()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("停止节拍器")
                    }
                }
            }

            Section("快速开始") {
                NavigationLink {
                    TunerView()
                } label: {
                    Label("快速调音", systemImage: "music.note")
                }
                .accessibilityHint("使用上次的乐器和弦位，进入后自动开始聆听")

                NavigationLink {
                    MetronomeView()
                } label: {
                    Label("快速节拍", systemImage: "metronome")
                }
                .accessibilityHint("使用上次的节拍器设置，不会自动播放")
            }

            Section("工具") {
                NavigationLink {
                    TunerView()
                } label: {
                    Label("调音器", systemImage: "tuningfork")
                }

                NavigationLink {
                    MetronomeView()
                } label: {
                    Label("节拍器", systemImage: "metronome")
                }

                NavigationLink {
                    HelpView()
                } label: {
                    Label("帮助", systemImage: "questionmark.circle")
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }

            Section("当前乐器") {
                Text("\(appModel.selectedPreset.displayName)\(appModel.selectedTargetDisplayName.map { "，" + $0 } ?? "")")
                    .accessibilityLabel("当前乐器")
                    .accessibilityValue("\(appModel.selectedPreset.displayName)\(appModel.selectedTargetDisplayName.map { "，" + $0 } ?? "")")
            }
        }
        .navigationTitle("调音节拍器")
    }
}

