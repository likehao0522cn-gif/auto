import SwiftUI
import TuneCore
import UIKit

struct MetronomeView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel
    @State private var bpmInput = ""
    @State private var isShowingBPMInput = false
    @State private var bpmInputError: String?
    @FocusState private var isBPMInputFocused: Bool

    private var timeSignatureBinding: Binding<TimeSignature> {
        Binding(
            get: { metronome.configuration.timeSignature },
            set: { metronome.configuration.timeSignature = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    speedReadout
                    TimeSignatureSwipeSelector(selection: timeSignatureBinding)
                    secondaryActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            transportControls
        }
        .navigationTitle("节拍器")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    BeatSettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text(verbatim: "节拍器设置"))
                .accessibilityHint(Text(verbatim: "包含拍号、重音、细分拍、音色、触觉、测速提示和帮助"))
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    isBPMInputFocused = false
                } label: {
                    Text(verbatim: "完成")
                }
            }
        }
    }

    private var speedReadout: some View {
        VStack(spacing: 6) {
            Text(verbatim: "\(Int(metronome.configuration.bpm))")
                .font(.system(size: 112, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(verbatim: "BPM")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(.secondary)

            HStack(spacing: 7) {
                Circle()
                    .fill(metronome.isPlaying ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(verbatim: metronome.statusText)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "速度"))
        .accessibilityValue(Text(verbatim: "\(Int(metronome.configuration.bpm)) BPM，\(metronome.statusText)"))
    }

    private var secondaryActions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink {
                    TapTempoView()
                } label: {
                    secondaryActionLabel("测速", systemImage: "metronome")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Text(verbatim: "测速"))

                Button {
                    bpmInput = "\(Int(metronome.configuration.bpm))"
                    bpmInputError = nil
                    withAnimation {
                        isShowingBPMInput.toggle()
                    }
                    if isShowingBPMInput {
                        isBPMInputFocused = true
                    }
                } label: {
                    secondaryActionLabel("输入速度", systemImage: "keyboard")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Text(verbatim: "输入速度"))

            }

            if isShowingBPMInput {
                manualBPMInput
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func secondaryActionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
            Text(verbatim: title)
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 58)
    }

    private var manualBPMInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("输入 20 到 300", text: $bpmInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .focused($isBPMInputFocused)
                .accessibilityLabel(Text(verbatim: "手动输入速度"))
                .accessibilityHint(Text(verbatim: "请输入 20 到 300 的整数 BPM，然后点应用输入的速度"))
                .onChange(of: bpmInput) { _, _ in
                    bpmInputError = nil
                }

            Button {
                applyManualBPMInput()
            } label: {
                Text(verbatim: "应用输入的速度")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "应用输入的速度"))
            .accessibilityHint(Text(verbatim: "将输入框中 20 到 300 的整数 BPM 应用到节拍器"))

            if let bpmInputError {
                Text(verbatim: bpmInputError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "输入错误"))
                    .accessibilityValue(Text(verbatim: bpmInputError))
            }
        }
    }

    private var transportControls: some View {
        HStack(spacing: 16) {
            transportButton(systemName: "minus", label: "减小速度", enabled: metronome.configuration.bpm > MetronomeTempo.validBPMRange.lowerBound) {
                metronome.setBPM(metronome.configuration.bpm - 1)
            }

            Button {
                metronome.toggle()
            } label: {
                Text(verbatim: metronome.isPlaying ? "停止" : "开始")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: metronome.isPlaying ? "停止节拍器" : "开始节拍器"))

            transportButton(systemName: "plus", label: "增大速度", enabled: metronome.configuration.bpm < MetronomeTempo.validBPMRange.upperBound) {
                metronome.setBPM(metronome.configuration.bpm + 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.bar)
    }

    private func transportButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.bold))
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityValue(Text(verbatim: "\(Int(metronome.configuration.bpm)) BPM"))
    }

    private func applyManualBPMInput() {
        switch BPMInput.parse(bpmInput) {
        case .success(let bpm):
            bpmInputError = nil
            bpmInput = "\(bpm)"
            isBPMInputFocused = false
            metronome.applyManualBPM(Double(bpm))
        case .failure(let error):
            let message: String
            switch error {
            case .empty:
                message = "请输入速度，范围是 20 到 300 BPM。"
            case .notAnInteger:
                message = "速度必须是整数，范围是 20 到 300 BPM。"
            case .outOfRange:
                message = "速度超出范围，请输入 20 到 300 BPM。"
            }
            bpmInputError = message
            isBPMInputFocused = true
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        }
    }
}

private struct TimeSignatureSwipeSelector: View {
    @Binding var selection: TimeSignature

    private var presets: [TimeSignature] { TimeSignature.presets }

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "拍号")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Image(systemName: "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Text(verbatim: selection.id)
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "拍号"))
        .accessibilityValue(Text(verbatim: selection.id))
        .accessibilityHint(Text(verbatim: "上下清扫调整拍号"))
        .accessibilityAddTraits(.isAdjustable)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            @unknown default: break
            }
        }
    }

    private func step(_ delta: Int) {
        guard let index = presets.firstIndex(of: selection) else { return }
        let nextIndex = (index + delta + presets.count) % presets.count
        let next = presets[nextIndex]
        guard next != selection else { return }

        selection = next
        UISelectionFeedbackGenerator().selectionChanged()

        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: "拍号 \(next.id)")
        }
    }
}
