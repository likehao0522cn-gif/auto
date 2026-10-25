import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("调音") {
                NavigationLink {
                    TuningSettingsView()
                } label: {
                    Label("音高、容差和反馈", systemImage: "tuningfork")
                }
            }

            Section("声音") {
                NavigationLink {
                    SoundSettingsView()
                } label: {
                    Label("参考音和语音", systemImage: "speaker.wave.2")
                }
            }

            Section("节拍器") {
                NavigationLink {
                    MetronomeSettingsView()
                } label: {
                    Label("节拍器设置", systemImage: "metronome")
                }
            }

            Section("无障碍") {
                NavigationLink {
                    AccessibilitySettingsView()
                } label: {
                    Label("VoiceOver 和触觉", systemImage: "accessibility")
                }
            }

            Section("其他") {
                NavigationLink {
                    OtherSettingsView()
                } label: {
                    Label("语言、隐私和恢复默认", systemImage: "info.circle")
                }

                NavigationLink {
                    DiagnosticsView()
                } label: {
                    Label("诊断", systemImage: "stethoscope")
                }
            }
        }
        .navigationTitle("设置")
    }
}

struct TuningSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("标准音高") {
                Stepper(
                    value: $appModel.concertA,
                    in: 392...466,
                    step: 1
                ) {
                    Text("A4 \(Int(appModel.concertA)) Hz")
                }
                .accessibilityLabel("A4 标准音高")
                .accessibilityValue("\(Int(appModel.concertA)) 赫兹")
            }

            Section("准音容差") {
                Picker("准音容差", selection: $appModel.toleranceCents) {
                    Text("±1 音分").tag(1.0)
                    Text("±3 音分").tag(3.0)
                    Text("±5 音分").tag(5.0)
                }
                .pickerStyle(.segmented)
            }

            Section("音名读法") {
                Picker("音名读法", selection: $appModel.noteNamingStyle) {
                    ForEach(NoteNamingStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("自动更新反馈") {
                Picker("自动更新反馈", selection: $appModel.autoUpdateFeedbackMode) {
                    ForEach(AutoUpdateFeedbackMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.inline)

                Text("首次检测结果始终播报完整音名和音分。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("调音设置")
    }
}

struct SoundSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("参考音音色") {
                Picker("参考音音色", selection: $appModel.referenceToneTimbre) {
                    ForEach(ReferenceToneTimbre.allCases) { timbre in
                        Text(timbre.title).tag(timbre)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Text("提示音和语音会尽量保持简短，避免遮住乐器声。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("声音设置")
    }
}

struct MetronomeSettingsView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        Form {
            Section("当前节拍器设置") {
                LabeledContent("拍号", value: metronome.configuration.timeSignature.id)
                LabeledContent("重音", value: metronome.configuration.accentMode.title)
                LabeledContent("细分拍", value: metronome.configuration.subdivision.title)
                LabeledContent("预备拍", value: metronome.configuration.countInBars.title)
                LabeledContent("音色", value: metronome.timbre.title)
                LabeledContent("触觉", value: metronome.hapticsEnabled ? "开启" : "关闭")
            }

            Section {
                NavigationLink {
                    MetronomeSoundSettingsView()
                } label: {
                    Label("音色和触觉", systemImage: "waveform")
                }

                Button("恢复节拍器默认设置", role: .destructive) {
                    metronome.resetDefaults()
                }
                .accessibilityHint("恢复 120 BPM、4/4、第一拍重音和清脆点击音")
            }
        }
        .navigationTitle("节拍器设置")
    }
}

struct AccessibilitySettingsView: View {
    var body: some View {
        Form {
            Section("VoiceOver") {
                Text("所有主要操作都可以通过 VoiceOver 完成。调音器会优先朗读当前结果，节拍器会优先朗读播放状态和速度。")
            }

            Section("转子") {
                Text("建议使用 VoiceOver 转子快速切换检测模式、乐器、弦位和节拍器设置。")
            }

            Section("盲文显示器") {
                Text("所有按钮和状态都提供文字标签，盲文显示器可以读取当前结果和播放状态。")
            }
        }
        .navigationTitle("无障碍设置")
    }
}

struct OtherSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("语言") {
                Picker("界面语言", selection: $appModel.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("隐私") {
                Text("调音节拍器不录音、不上传音频。音高分析在设备本地完成。")
            }

            Section("恢复默认") {
                Button("恢复默认设置", role: .destructive) {
                    appModel.restoreDefaults()
                }
                .accessibilityHint("把调音和声音设置恢复为初始值")
            }
        }
        .navigationTitle("其他设置")
    }
}
