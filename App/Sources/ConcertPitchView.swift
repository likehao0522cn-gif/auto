import SwiftUI
import TuneCore
import UIKit

/// Standard pitch settings. Each instrument keeps its own A4 value, and the
/// value can be typed directly for cases a fixed list does not cover.
struct ConcertPitchView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var customInput = ""
    @State private var isShowingCustomInput = false
    @State private var inputError: String?
    @FocusState private var isInputFocused: Bool

    /// Common reference pitches. 440 is the modern default; the others cover
    /// baroque and European orchestra practice.
    private let presets: [Int] = [415, 430, 432, 435, 438, 439, 440, 441, 442, 443]

    private var instrumentName: String { appModel.selectedPreset.displayName }

    var body: some View {
        Form {
            Section {
                ForEach(presets, id: \.self) { value in
                    Button {
                        apply(Double(value))
                    } label: {
                        HStack {
                            Text(verbatim: "\(value) 赫兹")
                                .monospacedDigit()
                            Spacer()
                            if Int(appModel.concertA) == value {
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
                    .accessibilityLabel(Text(verbatim: "\(value) 赫兹"))
                    .accessibilityAddTraits(Int(appModel.concertA) == value ? [.isSelected] : [])
                }
            } header: {
                Text(verbatim: "常用标准音高")
            } footer: {
                Text(verbatim: "当前 \(instrumentName) 使用 \(Int(appModel.concertA)) 赫兹。")
            }

            Section("自定义") {
                Button {
                    customInput = "\(Int(appModel.concertA))"
                    inputError = nil
                    isShowingCustomInput = true
                    Task { @MainActor in
                        await Task.yield()
                        isInputFocused = true
                    }
                } label: {
                    Text(verbatim: "输入标准音高")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "输入标准音高"))
                .accessibilityHint(Text(verbatim: "范围为 392 到 466 赫兹"))

                if isShowingCustomInput {
                    TextField("输入 392 到 466", text: $customInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                        .accessibilityLabel(Text(verbatim: "输入标准音高"))

                    Button {
                        applyTypedValue()
                    } label: {
                        Text(verbatim: "确定")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "确定并应用标准音高"))

                    if let inputError {
                        Text(verbatim: inputError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    appModel.concertAOverrides[appModel.selectedPresetID] = nil
                    announce("已恢复为默认标准音高")
                } label: {
                    Text(verbatim: "恢复本乐器为默认")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "恢复本乐器为默认"))
                .accessibilityHint(Text(verbatim: "使用默认标准音高 \(Int(appModel.defaultConcertA)) 赫兹"))
            }
        }
        .navigationTitle("标准音高")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    applyTypedValue()
                } label: {
                    Text(verbatim: "确定")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel(Text(verbatim: "确定并应用标准音高"))
            }
        }
    }

    private func apply(_ value: Double) {
        appModel.concertA = value
        announce("\(instrumentName) 标准音高已设为 \(Int(appModel.concertA)) 赫兹")
    }

    private func applyTypedValue() {
        let trimmed = customInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else {
            inputError = "请输入 392 到 466 之间的整数。"
            announce(inputError ?? "")
            return
        }
        guard (392...466).contains(value) else {
            inputError = "超出范围，请输入 392 到 466。"
            announce(inputError ?? "")
            return
        }
        inputError = nil
        isShowingCustomInput = false
        isInputFocused = false
        apply(Double(value))
    }

    private func announce(_ text: String) {
        guard !text.isEmpty, UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
