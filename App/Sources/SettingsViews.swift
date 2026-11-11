import SwiftUI
import TuneCore

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

            Section("钢琴调律") {
                NavigationLink {
                    PianoCurveView()
                } label: {
                    Text(verbatim: "调律曲线")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "调律曲线"))
                .accessibilityHint(Text(verbatim: "查看和调整钢琴的拉伸曲线"))
            }

            Section("声音") {
                NavigationLink {
                    SoundSettingsView()
                } label: {
                    Text(verbatim: "参考音和语音")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "参考音和语音"))

                NavigationLink {
                    SpeechSettingsView()
                } label: {
                    Text(verbatim: "语音语速、音调和音量")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "语音语速、音调和音量"))
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ConcertPitchView()
                } label: {
                    settingRow(
                        "标准音高",
                        value: "\(Int(appModel.concertA)) 赫兹"
                    )
                }
            } header: {
                Text(verbatim: "标准音高")
            } footer: {
                Text(verbatim: "这里改的是当前乐器 \(appModel.selectedPreset.displayName) 的标准音高，其他乐器不受影响。")
            }

            Section("准音容差") {
                AdjustableValueRow(
                    title: "准音容差",
                    value: $appModel.toleranceCents,
                    range: 1...5,
                    step: 2,
                    valueLabel: { "\(Int($0)) 音分" }
                )
            }

            Section("显示单位") {
                SwipeChoiceRow(
                    title: "显示单位",
                    options: TuningDisplayUnit.allCases,
                    selection: $appModel.tuningDisplayUnit,
                    label: { $0.title }
                )

                Text(verbatim: "旁白朗读与屏幕显示使用同一个单位。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("重复音名") {
                SwipeChoiceRow(
                    title: "重复音名省略",
                    options: RepeatNameWindow.allCases,
                    selection: $appModel.repeatNameWindow,
                    label: { $0.title }
                )

                Text(verbatim: "在这个时间内重复弹同一个音，只朗读新的数值，不再重复音名。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("音名读法") {
                SwipeChoiceRow(
                    title: "音名读法",
                    options: NoteNamingStyle.allCases,
                    selection: $appModel.noteNamingStyle,
                    label: { $0.title }
                )
            }

            Section("进入调音器") {
                Toggle(isOn: $appModel.tunerAutoStartEnabled) {
                    Text(verbatim: "进入后自动开始检测")
                }
                .accessibilityHint(Text(verbatim: "关闭后，进入调音器会保持暂停，需要手动点继续聆听"))
            }

            Section("自动更新反馈") {
                SwipeChoiceRow(
                    title: "自动更新反馈",
                    options: AutoUpdateFeedbackMode.allCases,
                    selection: $appModel.autoUpdateFeedbackMode,
                    label: { $0.title }
                )

                Text(verbatim: "首次检测结果始终播报完整音名和音分。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("调音器设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Text(verbatim: "关闭")
                }
                .accessibilityLabel(Text(verbatim: "关闭调音器设置"))
            }
        }
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

struct SoundSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("参考音音色") {
                Picker(selection: $appModel.referenceToneTimbre) {
                    ForEach(ReferenceToneTimbre.allCases) { timbre in
                        Text(verbatim: timbre.title)
                            .tag(timbre)
                            .accessibilityLabel(Text(verbatim: timbre.spokenTitle))
                    }
                } label: {
                    Text(verbatim: "参考音音色")
                }
                .pickerStyle(.inline)
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

struct SpeechSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var speechPreview = SpeechFeedback()

    var body: some View {
        Form {
            Section("语音来源") {
                SwipeChoiceRow(
                    title: "播报方式",
                    options: SpeechOutputMode.allCases,
                    selection: $appModel.speechOutputMode,
                    label: { $0.shortTitle }
                )

                Text(verbatim: appModel.speechOutputMode.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("应用语音") {
                AdjustableValueRow(
                    title: "语音语速",
                    value: $appModel.speechRate,
                    range: SpeechSettings.minimumRate...SpeechSettings.maximumRate,
                    step: 0.05,
                    valueLabel: { SpeechSettings.rateLabel($0) }
                )

                AdjustableValueRow(
                    title: "语音音调",
                    value: $appModel.speechPitch,
                    range: SpeechSettings.minimumPitch...SpeechSettings.maximumPitch,
                    step: 0.05,
                    valueLabel: { SpeechSettings.pitchLabel($0) }
                )

                AdjustableValueRow(
                    title: "语音音量",
                    value: $appModel.speechVolume,
                    range: SpeechSettings.minimumVolume...SpeechSettings.maximumVolume,
                    step: 0.1,
                    valueLabel: { SpeechSettings.volumeLabel($0) }
                )

                Button {
                    speechPreview.speak(
                        "这是当前语音语速、音调和音量。",
                        settings: appModel.speechSettings
                    )
                } label: {
                    Text(verbatim: "试听当前语音")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "试听当前语音"))

                Text(verbatim: "数值是相对百分比，100% 是最大值。语速、音调和音量只影响应用语音；选择旁白播报时，应用会使用系统旁白的语音和语速。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("语音设置")
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
                            .accessibilityLabel(Text(verbatim: language.spokenTitle))
                            .disabled(!language.isAvailable)
                    }
                } label: {
                    Text(verbatim: "界面语言")
                }
                .pickerStyle(.inline)

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
