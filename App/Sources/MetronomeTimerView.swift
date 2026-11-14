import SwiftUI
import TuneCore
import UIKit

/// Picks how long the metronome should play.
///
/// Built like the saved tempo list: a full-height list of options, each one
/// spoken clearly, plus a way to type a custom length. Choosing an option
/// applies it and closes, so the user is back at the metronome immediately.
struct MetronomeTimerView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingCustomInput = false
    @State private var customMinutes = ""
    @State private var customError: String?
    @FocusState private var isCustomFieldFocused: Bool

    private var currentDuration: TimeInterval? { metronome.runTimer?.duration }

    var body: some View {
        NavigationStack {
            List {
                presetsSection
                customSection
                offSection
            }
            .navigationTitle("定时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: "取消")
                    }
                    .accessibilityLabel(Text(verbatim: "关闭定时设置"))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isShowingCustomInput {
                customInputBar
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Sections

    private var presetsSection: some View {
        Section("常用时长") {
            ForEach(TimerDurations.presets) { option in
                presetRow(option)
            }
        }
    }

    private func presetRow(_ option: TimerDurationOption) -> some View {
        let isSelected = currentDuration == option.seconds
        return Button {
            choose(seconds: option.seconds, spoken: option.spokenTitle)
        } label: {
            HStack {
                Text(verbatim: option.spokenTitle)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: option.spokenTitle))
        .accessibilityValue(Text(verbatim: isSelected ? "已选中" : ""))
        .accessibilityHint(Text(verbatim: "双击选择 " + option.spokenTitle))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var customSection: some View {
        Section("自定义") {
            Button {
                customMinutes = ""
                customError = nil
                isShowingCustomInput = true
            } label: {
                Text(verbatim: "输入分钟数")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "输入分钟数"))
            .accessibilityHint(Text(verbatim: "输入 1 到 999 之间的整数分钟"))

            if let customError {
                Text(verbatim: customError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var offSection: some View {
        Section {
            Button {
                metronome.clearRunTimer()
                announceAndClose("定时已关闭")
            } label: {
                Text(verbatim: "不设定时")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "不设定时"))
            .accessibilityHint(Text(verbatim: "双击关闭定时，节拍器会一直播放")
            )
        } footer: {
            Text(verbatim: "定时会在开始播放时开始倒数，到时间自动停止")
        }
    }

    private var customInputBar: some View {
        HStack(spacing: 10) {
            TextField("输入 1 到 999", text: $customMinutes)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .focused($isCustomFieldFocused)
                .submitLabel(.done)
                .onAppear { isCustomFieldFocused = true }
                .onSubmit { applyCustomInput() }
                .accessibilityLabel(Text(verbatim: "输入分钟数"))

            Button {
                applyCustomInput()
            } label: {
                Text(verbatim: "确定")
                    .fontWeight(.semibold)
                    .frame(minWidth: 56, minHeight: 36)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(Text(verbatim: "确定并设置定时"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Actions

    private func choose(seconds: TimeInterval, spoken: String) {
        metronome.setRunDuration(seconds)
        announceAndClose("定时设为 " + spoken)
    }

    private func applyCustomInput() {
        switch TimerDurations.parse(minutes: customMinutes) {
        case .success(let minutes):
            isCustomFieldFocused = false
            customError = nil
            metronome.setRunDuration(Double(minutes) * 60)
            announceAndClose("定时设为 " + TimerDurations.spoken(minutes: minutes))
        case .failure(let error):
            let message: String
            switch error {
            case .empty: message = "请输入分钟数。"
            case .notAnInteger: message = "请输入整数分钟。"
            case .outOfRange: message = "范围是 1 到 999 分钟。"
            }
            customError = message
            isCustomFieldFocused = true
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        }
    }

    /// Says what was chosen, waits long enough for it to be heard, then closes.
    ///
    /// Spoken through the metronome so the confirmation arrives on whichever
    /// channel the user chose; posting only to VoiceOver would silently do
    /// nothing for someone on app voice.
    private func announceAndClose(_ text: String) {
        metronome.announce(text)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            dismiss()
        }
    }
}
