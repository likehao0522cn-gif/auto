import AVFoundation
import SwiftUI
import UIKit

struct DiagnosticsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var metronome: MetronomeViewModel
    @State private var didCopy = false

    var body: some View {
        Form {
            Section("设备与权限") {
                diagnosticRow("设备", value: UIDevice.current.model)
                diagnosticRow("系统版本", value: UIDevice.current.systemVersion)
                diagnosticRow("应用版本", value: appVersion)
                diagnosticRow("麦克风权限", value: microphonePermissionText)
                diagnosticRow("音频输入", value: audioInputText)
                diagnosticRow("音频输出", value: audioOutputText)
                diagnosticRow("采样率", value: sampleRateText)
            }

            Section("调音设置") {
                diagnosticRow("乐器", value: appModel.selectedPreset.displayName)
                diagnosticRow("弦位或目标音", value: appModel.selectedTargetDisplayName ?? "无")
                diagnosticRow("标准音高", value: "\(Int(appModel.concertA)) 赫兹")
                diagnosticRow("准音容差", value: "上下 \(Int(appModel.toleranceCents)) 音分")
                diagnosticRow("音名读法", value: appModel.noteNamingStyle.title)
                diagnosticRow("更新反馈", value: appModel.autoUpdateFeedbackMode.title)
                diagnosticRow("参考音音色", value: appModel.referenceToneTimbre.title)
            }

            Section("检测与调度") {
                diagnosticRow("检测频率", value: "调音器页面实时显示")
                diagnosticRow("检测置信度", value: "调音器页面实时显示")
                diagnosticRow("节拍器调度", value: "基于音频采样时间，暂无偏差数据")
                diagnosticRow("最近错误", value: metronome.errorMessage ?? "无")
            }

            Section("节拍器设置") {
                diagnosticRow("播放状态", value: metronome.isPlaying ? "正在播放" : "已停止")
                diagnosticRow("速度", value: "每分钟 \(Int(metronome.configuration.bpm)) 拍")
                diagnosticRow("拍号", value: metronome.configuration.timeSignature.id)
                diagnosticRow("重音", value: metronome.configuration.accentMode.title)
                diagnosticRow("细分拍", value: metronome.configuration.subdivision.title)
                diagnosticRow("预备拍", value: metronome.configuration.countInBars.title)
                diagnosticRow("音色", value: metronome.timbre.title)
                diagnosticRow("触觉", value: metronome.hapticsEnabled ? "开启" : "关闭")
            }

            Section {
                Button {
                    UIPasteboard.general.string = diagnosticText
                    didCopy = true
                } label: {
                    Text(verbatim: didCopy ? "已复制诊断信息" : "复制诊断信息")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: didCopy ? "已复制诊断信息" : "复制诊断信息"))

                Button {
                    openSystemSettings()
                } label: {
                    Text(verbatim: "打开系统设置")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "打开系统设置"))

                Text(verbatim: "诊断信息不包含音频、苹果账号或密码。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("诊断")
    }

    private func diagnosticRow(_ title: String, value: String) -> some View {
        LabeledContent(title, value: value)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityValue(Text(verbatim: value))
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        return "\(short) (\(build))"
    }

    private var microphonePermissionText: String {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return "已允许"
        case .denied: return "已拒绝"
        case .undetermined: return "尚未询问"
        @unknown default: return "未知"
        }
    }

    private var sampleRateText: String {
        let rate = AVAudioSession.sharedInstance().sampleRate
        return rate > 0 ? String(format: "%.0f 赫兹", rate) : "不可用"
    }

    private var audioInputText: String {
        let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
        guard !inputs.isEmpty else { return "无可用输入" }
        return inputs.map(\.portName).joined(separator: "、")
    }

    private var audioOutputText: String {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        guard !outputs.isEmpty else { return "无可用输出" }
        return outputs.map(\.portName).joined(separator: "、")
    }

    private var diagnosticText: String {
        """
        调音节拍器诊断
        设备: \(UIDevice.current.model)
        系统版本: \(UIDevice.current.systemVersion)
        应用版本: \(appVersion)
        麦克风权限: \(microphonePermissionText)
        音频输入: \(audioInputText)
        音频输出: \(audioOutputText)
        采样率: \(sampleRateText)
        乐器: \(appModel.selectedPreset.displayName)
        弦位或目标音: \(appModel.selectedTargetDisplayName ?? "无")
        标准音高: \(Int(appModel.concertA)) 赫兹
        准音容差: 上下 \(Int(appModel.toleranceCents)) 音分
        音名读法: \(appModel.noteNamingStyle.title)
        更新反馈: \(appModel.autoUpdateFeedbackMode.title)
        参考音音色: \(appModel.referenceToneTimbre.title)
        检测频率: 调音器页面实时显示
        检测置信度: 调音器页面实时显示
        节拍器调度: 基于音频采样时间，暂无偏差数据
        最近错误: \(metronome.errorMessage ?? "无")
        节拍器播放状态: \(metronome.isPlaying ? "正在播放" : "已停止")
        节拍器速度: 每分钟 \(Int(metronome.configuration.bpm)) 拍
        拍号: \(metronome.configuration.timeSignature.id)
        重音: \(metronome.configuration.accentMode.title)
        细分拍: \(metronome.configuration.subdivision.title)
        预备拍: \(metronome.configuration.countInBars.title)
        节拍器音色: \(metronome.timbre.title)
        触觉: \(metronome.hapticsEnabled ? "开启" : "关闭")
        """
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
