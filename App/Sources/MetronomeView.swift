import SwiftUI
import TuneCore
import UIKit

struct MetronomeView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel
    @State private var bpmInput = ""
    @State private var bpmInputError: String?
    @FocusState private var isBPMInputFocused: Bool

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text(verbatim: "\(Int(metronome.configuration.bpm))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(verbatim: "每分钟拍数")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(verbatim: metronome.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "速度"))
                .accessibilityValue(Text(verbatim: "每分钟 \(Int(metronome.configuration.bpm)) 拍，\(metronome.statusText)"))

                AdjustableValueRow(
                    title: "节拍器速度",
                    value: $metronome.configuration.bpm,
                    range: MetronomeTempo.validBPMRange,
                    step: 1,
                    valueLabel: { "每分钟 \(Int($0)) 拍" }
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: "手动输入速度")
                        .font(.headline)
                        .accessibilityHidden(true)

                    TextField("输入 20 到 300", text: $bpmInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isBPMInputFocused)
                        .accessibilityLabel(Text(verbatim: "手动输入速度"))
                        .accessibilityHint(Text(verbatim: "请输入每分钟 20 到 300 的整数，然后点应用输入的速度"))
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
                    .accessibilityHint(Text(verbatim: "将输入框中每分钟 20 到 300 的整数应用到节拍器"))

                    if let bpmInputError {
                        Text(verbatim: bpmInputError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(verbatim: "输入错误"))
                            .accessibilityValue(Text(verbatim: bpmInputError))
                    }
                }
                .padding(.vertical, 4)

                Button {
                    metronome.toggle()
                } label: {
                    Text(verbatim: metronome.isPlaying ? "停止" : "开始")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: metronome.isPlaying ? "停止节拍器" : "开始节拍器"))
                .buttonStyle(.borderedProminent)
            }

            Section("节拍设置") {
                NavigationLink {
                    MetronomeSoundSettingsView()
                } label: {
                    Text(verbatim: "音色和触觉")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "音色和触觉"))

                NavigationLink {
                    BeatSettingsView()
                } label: {
                    Text(verbatim: "拍号、重音和细分拍")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "拍号、重音和细分拍"))

                NavigationLink {
                    TapTempoView()
                } label: {
                    Text(verbatim: "测速")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "测速"))

                NavigationLink {
                    CountInView()
                } label: {
                    Text(verbatim: "预备拍")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "预备拍"))
            }

            Section {
                NavigationLink {
                    MetronomeHelpView()
                } label: {
                    Text(verbatim: "帮助")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "帮助"))
            }

            if let errorMessage = metronome.errorMessage {
                Section("错误") {
                    Text(verbatim: errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("节拍器")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
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
                message = "请输入速度，范围是每分钟 20 到 300 拍。"
            case .notAnInteger:
                message = "速度必须是整数，范围是每分钟 20 到 300 拍。"
            case .outOfRange:
                message = "速度超出范围，请输入每分钟 20 到 300 拍。"
            }
            bpmInputError = message
            isBPMInputFocused = true
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        }
    }
}
