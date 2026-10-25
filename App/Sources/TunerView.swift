import SwiftUI
import TuneCore

struct TunerView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var metronome: MetronomeViewModel
    @StateObject private var viewModel = TunerViewModel()
    @State private var mode: DetectionMode = .locked
    @State private var hasAppeared = false
    @State private var restartTask: Task<Void, Never>?
    @State private var isShowingHelp = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                resultCard

                Picker("检测模式", selection: $mode) {
                    ForEach(DetectionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("检测模式")

                VStack(spacing: 0) {
                    NavigationLink {
                        InstrumentPickerView()
                    } label: {
                        selectorRow(title: "乐器", value: appModel.selectedPreset.displayName)
                    }

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
                    } else if appModel.selectedPreset.isPiano {
                        Divider()
                        NavigationLink {
                            PianoTargetPickerView()
                        } label: {
                            selectorRow(
                                title: "目标音",
                                value: appModel.selectedTargetDisplayName ?? "自动识别"
                            )
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                actionButtons

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel("错误")
                        .accessibilityValue(errorMessage)
                }

                Text(viewModel.isListening ? "麦克风正在持续监听" : "麦克风未在监听")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("监听状态")
                    .accessibilityValue(viewModel.isListening ? "正在监听" : "未监听")
            }
            .padding()
        }
        .navigationTitle("调音器")
        .onAppear {
            restartTask?.cancel()
            hasAppeared = true
            if metronome.isPlaying {
                metronome.stop()
            }
            mode = appModel.selectedPreset.defaultMode
            startNow(announceEntry: true)
        }
        .onDisappear {
            restartTask?.cancel()
            viewModel.stop()
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
                            Button("关闭") {
                                isShowingHelp = false
                            }
                            .accessibilityHint("关闭帮助并继续调音")
                        }
                    }
            }
        }
    }

    private var resultCard: some View {
        VStack(spacing: 12) {
            Text("当前结果")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(resultText)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.45)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 92)

            if let liveReading = viewModel.liveReading {
                Text(String(format: "%.1f Hz", liveReading.frequency))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前结果")
        .accessibilityValue(resultText)
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
                Label("播放参考音", systemImage: "speaker.wave.2.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("播放当前目标音，播放期间暂停音高分析")

            Button {
                viewModel.queryResult()
            } label: {
                Label("查询结果", systemImage: "speaker.wave.2")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)

            Button {
                if viewModel.isPaused {
                    viewModel.resume()
                } else {
                    viewModel.pause()
                }
            } label: {
                Label(
                    viewModel.isPaused ? "继续聆听" : "暂停聆听",
                    systemImage: viewModel.isPaused ? "mic.fill" : "mic.slash.fill"
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint(viewModel.isPaused ? "重新开始麦克风监听" : "释放麦克风并停止检测")

            Button {
                viewModel.pauseForOverlay()
                isShowingHelp = true
            } label: {
                Label("帮助", systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("打开帮助时暂停聆听，返回后自动恢复")
        }
    }

    private func selectorRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
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
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint("双击选择")
    }

    private func scheduleRestart(announceEntry: Bool) {
        restartTask?.cancel()
        restartTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, hasAppeared else { return }
            startNow(announceEntry: announceEntry)
        }
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

