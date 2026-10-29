import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("调音") {
                NavigationLink {
                    TuningSettingsView()
                } label: {
                    Text(verbatim: "音高、容差和反馈")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "音高、容差和反馈"))
            }

            Section("声音") {
                NavigationLink {
                    SoundSettingsView()
                } label: {
                    Text(verbatim: "参考音和语音")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "参考音和语音"))
            }

            Section("节拍器") {
                NavigationLink {
                    MetronomeSettingsView()
                } label: {
                    Text(verbatim: "节拍器设置")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "节拍器设置"))
            }

            Section("无障碍") {
                NavigationLink {
                    AccessibilitySettingsView()
                } label: {
                    Text(verbatim: "旁白和触觉")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "旁白和触觉"))
            }

            Section("其他") {
                NavigationLink {
                    OtherSettingsView()
                } label: {
                    Text(verbatim: "语言、隐私和恢复默认")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "语言、隐私和恢复默认"))

                NavigationLink {
                    DiagnosticsView()
                } label: {
                    Text(verbatim: "诊断")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "诊断"))
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
                    Text(verbatim: "标准音高：\(Int(appModel.concertA)) 赫兹")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "标准音高"))
                .accessibilityValue(Text(verbatim: "\(Int(appModel.concertA)) 赫兹"))
            }

            Section("准音容差") {
                Picker(selection: $appModel.toleranceCents) {
                    Text(verbatim: "上下 1 音分").tag(1.0)
                    Text(verbatim: "上下 3 音分").tag(3.0)
                    Text(verbatim: "上下 5 音分").tag(5.0)
                } label: {
                    Text(verbatim: "准音容差")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text(verbatim: "准音容差"))
            }

            Section("音名读法") {
                Picker(selection: $appModel.noteNamingStyle) {
                    ForEach(NoteNamingStyle.allCases) { style in
                        Text(verbatim: style.title).tag(style)
                    }
                } label: {
                    Text(verbatim: "音名读法")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "音名读法"))
            }

            Section("自动更新反馈") {
                Picker(selection: $appModel.autoUpdateFeedbackMode) {
                    ForEach(AutoUpdateFeedbackMode.allCases) { mode in
                        Text(verbatim: mode.title).tag(mode)
                    }
                } label: {
                    Text(verbatim: "自动更新反馈")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "自动更新反馈"))

                Text(verbatim: "首次检测结果始终播报完整音名和音分。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("调音设置")
    }
}

struct SoundSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var speechPreview = SpeechFeedback()

    var body: some View {
        Form {
            Section("语音播报") {
                Picker(selection: $appModel.speechOutputMode) {
                    ForEach(SpeechOutputMode.allCases) { mode in
                        Text(verbatim: mode.title).tag(mode)
                    }
                } label: {
                    Text(verbatim: "播报方式")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "播报方式"))

                Text(verbatim: appModel.speechOutputMode.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("应用语音") {
                Stepper(
                    value: $appModel.speechRate,
                    in: SpeechSettings.minimumRate...SpeechSettings.maximumRate,
                    step: 0.05
                ) {
                    Text(verbatim: "语音速度：\(SpeechSettings.rateLabel(appModel.speechRate))")
                }
                .accessibilityLabel(Text(verbatim: "语音速度"))
                .accessibilityValue(Text(verbatim: SpeechSettings.rateLabel(appModel.speechRate)))

                Stepper(
                    value: $appModel.speechPitch,
                    in: SpeechSettings.minimumPitch...SpeechSettings.maximumPitch,
                    step: 0.05
                ) {
                    Text(verbatim: "语音音调：\(SpeechSettings.pitchLabel(appModel.speechPitch))")
                }
                .accessibilityLabel(Text(verbatim: "语音音调"))
                .accessibilityValue(Text(verbatim: SpeechSettings.pitchLabel(appModel.speechPitch)))

                Button {
                    speechPreview.speak(
                        "这是当前语音速度和音调。",
                        settings: appModel.speechSettings
                    )
                } label: {
                    Text(verbatim: "试听当前语音")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "试听当前语音"))

                Text(verbatim: "语速和音调只影响应用语音；旁白播报使用系统旁白自己的声音和语速。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("参考音音色") {
                Picker(selection: $appModel.referenceToneTimbre) {
                    ForEach(ReferenceToneTimbre.allCases) { timbre in
                        Text(verbatim: timbre.title).tag(timbre)
                    }
                } label: {
                    Text(verbatim: "参考音音色")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "参考音音色"))
            }

            Section {
                Text(verbatim: "提示音和语音会尽量保持简短，避免遮住乐器声。")
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
                    Text(verbatim: "音色和触觉")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "音色和触觉"))

                Button(role: .destructive) {
                    metronome.resetDefaults()
                } label: {
                    Text(verbatim: "恢复节拍器默认设置")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "恢复节拍器默认设置"))
            }
        }
        .navigationTitle("节拍器设置")
    }
}

struct AccessibilitySettingsView: View {
    var body: some View {
        Form {
            Section("旁白") {
                Text(verbatim: "所有主要操作都可以通过旁白完成。调音器会优先朗读当前结果，节拍器会优先朗读播放状态和速度。")
            }

            Section("转子") {
                Text(verbatim: "建议使用旁白转子快速切换检测模式、乐器、弦位和节拍器设置。")
            }

            Section("盲文显示器") {
                Text(verbatim: "所有按钮和状态都提供文字标签，盲文显示器可以读取当前结果和播放状态。")
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
                Picker(selection: $appModel.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(verbatim: language.title)
                            .tag(language)
                            .disabled(!language.isAvailable)
                    }
                } label: {
                    Text(verbatim: "界面语言")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "界面语言"))

                Text(verbatim: "英文界面和英文语音尚未完成，当前版本只提供中文。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("隐私") {
                Text(verbatim: "调音节拍器不录音、不上传音频。音高分析在设备本地完成。")
            }

            Section("测速") {
                Toggle(isOn: $appModel.tapTempoHapticsEnabled) {
                    Text(verbatim: "拍点触觉反馈")
                }
            }

            Section("恢复默认") {
                Button(role: .destructive) {
                    appModel.restoreDefaults()
                } label: {
                    Text(verbatim: "恢复默认设置")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "恢复默认设置"))
            }
        }
        .navigationTitle("其他设置")
    }
}
