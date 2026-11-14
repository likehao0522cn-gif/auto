import SwiftUI
import TuneCore
import UIKit

/// The user's saved tempos. Selecting one applies it and closes the sheet, so
/// the interaction matches the time signature picker.
struct FavoriteTempoListView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingAddInput = false
    @State private var newTempoInput = ""
    @State private var addError: String?
    @FocusState private var isAddFieldFocused: Bool

    private var store: FavoriteTempoStore { metronome.favorites }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.sortedTempos) { tempo in
                        Button {
                            metronome.applyFavoriteTempo(tempo.bpm)
                            dismiss()
                        } label: {
                            HStack {
                                Text(verbatim: "\(tempo.bpm) BPM")
                                    .font(.title3)
                                    .monospacedDigit()
                                Spacer()
                                if tempo.bpm == Int(metronome.configuration.bpm) {
                                    Image(systemName: "checkmark")
                                        .font(.headline)
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: "\(tempo.bpm) BPM"))
                        .accessibilityValue(Text(verbatim: describe(tempo)))
                        .accessibilityHint(Text(verbatim: "双击应用这个速度"))
                        .accessibilityAddTraits(
                            tempo.bpm == Int(metronome.configuration.bpm) ? [.isSelected] : []
                        )
                        .swipeActions {
                            Button(role: .destructive) {
                                store.remove(bpm: tempo.bpm)
                            } label: {
                                Text(verbatim: "删除")
                            }
                        }
                    }
                } footer: {
                    Text(verbatim: "最多保存 \(FavoriteTempoRules.capacity) 个速度。向左滑动可以删除。")
                }

                Section("添加") {
                    // Adding the current tempo must not open a keyboard: the
                    // value is already known, so a text field here was confusing.
                    Button {
                        addCurrentTempo()
                    } label: {
                        Text(verbatim: "把当前速度 \(Int(metronome.configuration.bpm)) 加入常用")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "把当前速度加入常用"))
                    .accessibilityValue(Text(verbatim: "当前是 \(Int(metronome.configuration.bpm)) BPM"))
                    .accessibilityHint(Text(verbatim: "双击直接加入，不需要输入"))

                    Button {
                        newTempoInput = ""
                        addError = nil
                        isShowingAddInput = true
                        Task { @MainActor in
                            await Task.yield()
                            isAddFieldFocused = true
                        }
                    } label: {
                        Text(verbatim: "输入其他速度添加")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "输入其他速度添加"))

                    if let addError {
                        Text(verbatim: addError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("常用速度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: "取消")
                    }
                    .accessibilityLabel(Text(verbatim: "关闭常用速度"))
                }
            }
        }
        // Message-composer style: field and confirm share one row above the
        // keyboard, matching where a chat app puts its send button.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Show on isShowingAddInput alone. Requiring focus too was the same
            // deadlock the metronome screen had: the field only appeared once
            // focused, but focus needs the field to exist first.
            if isShowingAddInput {
                HStack(spacing: 10) {
                    TextField("输入 20 到 300", text: $newTempoInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isAddFieldFocused)
                        .submitLabel(.done)
                        .onAppear { isAddFieldFocused = true }
                        .onSubmit { addTypedTempo() }
                        .accessibilityLabel(Text(verbatim: "输入要添加的速度"))

                    Button {
                        addTypedTempo()
                    } label: {
                        Text(verbatim: "确定")
                            .fontWeight(.semibold)
                            .frame(minWidth: 56, minHeight: 36)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel(Text(verbatim: "确定并添加"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        // A half sheet keeps the metronome visible underneath, so opening the
        // list does not feel like leaving the screen. It can still be dragged
        // up to full height when the list grows.
        .presentationDetents([.medium, .large])
        // A grabber makes it obvious the card can be pulled down to close,
        // which matters when the user cannot see the dimmed area behind it.
        .presentationDragIndicator(.visible)
    }

    private func describe(_ tempo: FavoriteTempo) -> String {
        var parts: [String] = []
        parts.append(tempo.isManual ? "手动收藏" : "自动加入")
        parts.append("用过 \(tempo.useCount) 次")
        if tempo.playMinutes > 0 {
            parts.append("累计播放 \(tempo.playMinutes) 分钟")
        }
        return parts.joined(separator: "，")
    }

    /// Adds the tempo currently in use. No input is needed, so no keyboard is
    /// shown and the user gets immediate spoken feedback.
    private func addCurrentTempo() {
        let bpm = Int(metronome.configuration.bpm)
        if store.contains(bpm: bpm) {
            announce("\(bpm) 已经在常用里")
        } else if store.add(bpm: bpm) {
            announce("已加入常用速度 \(bpm)")
            addError = nil
        } else {
            let message = "常用速度最多 \(FavoriteTempoRules.capacity) 个，请先删除一个。"
            addError = message
            announce(message)
        }
    }

    private func addTypedTempo() {
        switch BPMInput.parse(newTempoInput) {
        case .success(let bpm):
            if store.contains(bpm: bpm) {
                announce("这个速度已经在常用里")
                addError = "这个速度已经在常用里。"
            } else if store.add(bpm: bpm) {
                announce("已加入常用速度 \(bpm)")
                dismissAddInput()
                addError = nil
            } else {
                addError = "常用速度最多 \(FavoriteTempoRules.capacity) 个，请先删除一个。"
                announce(addError ?? "")
            }
        case .failure(let error):
            let message: String
            switch error {
            case .empty: message = "请输入速度，范围是 20 到 300 BPM。"
            case .notAnInteger: message = "速度必须是整数，范围是 20 到 300 BPM。"
            case .outOfRange: message = "速度超出范围，请输入 20 到 300 BPM。"
            }
            addError = message
            announce(message)
        }
    }

    /// Applies the new tempo first, then lets the keyboard animate away before
    /// the input bar disappears, so the field is not ripped out mid-animation.
    private func dismissAddInput() {
        isAddFieldFocused = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !isAddFieldFocused else { return }
            withAnimation {
                isShowingAddInput = false
            }
        }
    }

    private func announce(_ text: String) {
        guard !text.isEmpty, UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
