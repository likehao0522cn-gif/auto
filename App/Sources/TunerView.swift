import SwiftUI
import TuneCore
import UIKit

struct TunerView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var metronome: MetronomeViewModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = TunerViewModel()
    @State private var mode: DetectionMode = .locked
    @State private var hasAppeared = false
    @State private var restartTask: Task<Void, Never>?
    @State private var isShowingHelp = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                resultCard

                Picker(selection: $mode) {
                    ForEach(DetectionMode.allCases) { mode in
                        Text(verbatim: mode.title).tag(mode)
                    }
                } label: {
                    Text(verbatim: "检测模式")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text(verbatim: "检测模式"))

                VStack(spacing: 0) {
                    NavigationLink {
                        InstrumentPickerView()
                    } label: {
                        selectorRow(title: "乐器", value: appModel.selectedPreset.displayName)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "乐器：\(appModel.selectedPreset.displayName)"))

                    if !appModel.selectedPreset.strings.isEmpty {
                        Divider()
                        NavigationLink {
                            StringPickerView()
                        } label: {
                            selectorRow(
                                title: "弦位",
                                value: appModel.selectedTargetDisplayName ?? "未选择"
                            )
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: "弦位：\(appModel.selectedTargetDisplayName ?? "未选择")"))
                    } else if appModel.selectedPreset.isPiano {
                        Divider()
                        NavigationLink {
                            PianoTargetPickerView()
                        } label: {
                            selectorRow(
                                title: "目标音",
                                value: mode == .automatic
                                    ? "自动识别"
                                    : (appModel.selectedTargetDisplayName ?? "未选择")
                            )
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: "目标音：\(mode == .automatic ? "自动识别" : (appModel.selectedTargetDisplayName ?? "未选择"))"))
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                actionButtons

                if let errorMessage = viewModel.errorMessage {
                    Text(verbatim: errorMessage)
                        .foregroundStyle(.red)

                    if viewModel.needsMicrophonePermission {
                        Button {
                            viewModel.retryMicrophonePermission()
                        } label: {
                            Text(verbatim: "重新尝试聆听")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: "重新尝试聆听"))
                        .buttonStyle(.bordered)

                        Button {
                            openSystemSettings()
                        } label: {
                            Text(verbatim: "打开系统设置")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: "打开系统设置"))
                        .buttonStyle(.borderedProminent)
                    }
                }

                Text(verbatim: viewModel.isListening ? "麦克风正在持续监听" : "麦克风未在监听")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("调音器")
        .onAppear {
            restartTask?.cancel()
            hasAppeared = true
            viewModel.pageWillAppear(sceneIsActive: scenePhase == .active)
            if metronome.isPlaying {
                metronome.stop()
            }
            mode = appModel.selectedPreset.defaultMode
            if scenePhase == .active {
                startNow(announceEntry: true)
            } else {
                viewModel.prepareToListenWhenActive(
                    preset: appModel.selectedPreset,
                    string: appModel.selectedTargetString,
                    mode: mode,
                    concertA: appModel.concertA,
                    toleranceCents: appModel.toleranceCents,
                    feedbackMode: appModel.autoUpdateFeedbackMode,
                    namingStyle: appModel.noteNamingStyle,
                    referenceTimbre: appModel.referenceToneTimbre
                )
            }
        }
        .onDisappear {
            restartTask?.cancel()
            if isShowingHelp {
                return
            }
            hasAppeared = false
            viewModel.pageDidDisappear()
        }
        .onChange(of: scenePhase) { _, current in
            switch current {
            case .background, .inactive:
                viewModel.setSceneActive(false)
            case .active:
                viewModel.pageDidBecomeActive()
            @unknown default:
                break
            }
        }
        .onChange(of: appModel.selectedPresetID) { _, _ in
            mode = appModel.selectedPreset.defaultMode
            scheduleRestart(announceEntry: true)
        }
        .onChange(of: appModel.selectedStringID) { _, _ in
            scheduleRestart(announceEntry: false)
        }
        .onChange(of: appModel.pianoTargetMIDI) { _, _ in
            scheduleRestart(announceEntry: false)
        }
        .onChange(of: appModel.concertA) { _, _ in
            scheduleRestart(announceEntry: false)
        }
        .onChange(of: appModel.toleranceCents) { _, _ in
            scheduleRestart(announceEntry: false)
        }
        .onChange(of: appModel.autoUpdateFeedbackMode) { _, _ in
            scheduleRestart(announceEntry: false)
        }
        .onChange(of: appModel.noteNamingStyle) { _, _ in
            scheduleRestart(announceEntry: false)
        }
        .onChange(of: appModel.referenceToneTimbre) { _, _ in
            scheduleRestart(announceEntry: false)
        }
        .onChange(of: mode) { _, _ in
            scheduleRestart(announceEntry: false)
        }
        .sheet(isPresented: $isShowingHelp, onDismiss: {
            guard hasAppeared, viewModel.isPaused else { return }
            viewModel.resume()
        }) {
            NavigationStack {
                HelpView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                isShowingHelp = false
                            } label: {
                                Text(verbatim: "关闭")
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(verbatim: "关闭帮助"))
                        }
                    }
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "当前结果")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(verbatim: resultText)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.45)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 92)
                .accessibilityLabel(Text(verbatim: "当前结果"))
                .accessibilityValue(Text(verbatim: resultText))

            if let liveReading = viewModel.liveReading {
                Text(verbatim: String(format: "%.1f 赫兹", liveReading.frequency))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .contain)
    }

    private var resultText: String {
        if let reading = viewModel.reading {
            return reading.displayText
        }
        return viewModel.statusText
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.playReferenceTone()
            } label: {
                Text(verbatim: "播放参考音")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "播放参考音"))
            .buttonStyle(.bordered)

            Button {
                viewModel.queryResult()
            } label: {
                Text(verbatim: "查询结果")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "查询结果"))
            .buttonStyle(.bordered)

            Button {
                if viewModel.isPaused {
                    viewModel.resume()
                } else {
                    viewModel.pause()
                }
            } label: {
                Text(verbatim: viewModel.isPaused ? "继续聆听" : "暂停聆听")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: viewModel.isPaused ? "继续聆听" : "暂停聆听"))
            .buttonStyle(.borderedProminent)

            Button {
                viewModel.pauseForOverlay()
                isShowingHelp = true
            } label: {
                Text(verbatim: "帮助")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "帮助"))
            .buttonStyle(.bordered)
        }
    }

    private func selectorRow(title: String, value: String) -> some View {
        HStack {
            Text(verbatim: title)
                .foregroundStyle(.primary)
            Spacer()
            Text(verbatim: value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(title)：\(value)"))
    }

    private func scheduleRestart(announceEntry: Bool) {
        restartTask?.cancel()
        restartTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, hasAppeared, scenePhase == .active else { return }
            startNow(announceEntry: announceEntry)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func startNow(announceEntry: Bool) {
        viewModel.start(
            preset: appModel.selectedPreset,
            string: appModel.selectedTargetString,
            mode: mode,
            concertA: appModel.concertA,
            toleranceCents: appModel.toleranceCents,
            feedbackMode: appModel.autoUpdateFeedbackMode,
            namingStyle: appModel.noteNamingStyle,
            referenceTimbre: appModel.referenceToneTimbre,
            announceEntry: announceEntry
        )
    }
}
