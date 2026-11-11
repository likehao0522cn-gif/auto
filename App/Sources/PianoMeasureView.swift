import SwiftUI
import TuneCore

/// Measures a piano's inharmonicity, one key at a time.
///
/// Built for a blind user end to end: the prompt says which key to play, the
/// result is graded in words rather than a coefficient, and the measured keys
/// are listed so the user can tell how far along they are.
struct PianoMeasureView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var curveModel: PianoCurveViewModel
    @StateObject private var model = PianoMeasureViewModel()
    @StateObject private var speech = SpeechFeedback()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            keySection
            actionSection
            resultSection
            progressSection
            applySection
        }
        .navigationTitle("测量钢琴")
        .onDisappear {
            model.cancel(settings: appModel.speechSettings)
        }
    }

    // MARK: - Sections

    private var keySection: some View {
        Section("要测的音") {
            Stepper(value: $model.selectedMIDI, in: 21...108) {
                Text(verbatim: "当前音：\(noteName)")
            }
            .accessibilityLabel(Text(verbatim: "要测的音"))
            .accessibilityValue(Text(verbatim: noteName))

            Text(verbatim: "请依次弹奏需要测量的弦，测得越多，曲线越准")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "提示"))
                .accessibilityValue(Text(verbatim: "请依次弹奏需要测量的弦，测得越多，曲线越准"))
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                measure()
            } label: {
                Text(verbatim: measureButtonTitle)
            }
            .disabled(!model.canMeasure)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: measureButtonTitle))
            .accessibilityHint(Text(verbatim: "轻点后按提示弹奏\(noteName)"))

            if model.measuredCount > 0 {
                Button {
                    model.reset(settings: appModel.speechSettings)
                } label: {
                    Text(verbatim: "清除全部测量")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "清除全部测量"))
            }
        }
    }

    private var resultSection: some View {
        Section("结果") {
            statusRow
        }
    }

    private var statusRow: some View {
        Text(verbatim: statusText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "状态"))
            .accessibilityValue(Text(verbatim: statusText))
    }

    private var progressSection: some View {
        Section("已测的音") {
            if model.measurements.isEmpty {
                Text(verbatim: "还没有测量任何弦")
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "还没有测量任何弦"))
            } else {
                ForEach(measuredKeys, id: \.self) { midi in
                    measuredRow(midi)
                }
            }
        }
    }

    private var applySection: some View {
        Section {
            Button {
                applyToCurve()
            } label: {
                Text(verbatim: "用这批测量生成曲线")
            }
            .disabled(model.measuredCount == 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "用这批测量生成曲线"))
            .accessibilityHint(Text(verbatim: "把测得的非谐性应用到当前调律曲线"))
        } footer: {
            Text(verbatim: "至少要测几根弦才比较可靠，建议低音、中音、高音各测几根")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "至少要测几根弦才比较可靠，建议低音、中音、高音各测几根"))
        }
    }

    private func measuredRow(_ midi: Int) -> some View {
        let measurement = model.measurements[midi]
        let text = measurement.map { model.describe($0) } ?? ""
        return Text(verbatim: text)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: Note(midi: midi).displayName))
            .accessibilityValue(Text(verbatim: text))
    }

    // MARK: - Helpers

    private var noteName: String {
        appModel.displayName(forMIDI: model.selectedMIDI)
    }

    private var measuredKeys: [Int] {
        model.measurements.keys.sorted()
    }

    private var measureButtonTitle: String {
        switch model.stage {
        case .listening: return "正在聆听，请弹奏 \(noteName)"
        case .measuring: return "正在分析"
        default: return "测量 \(noteName)"
        }
    }

    private var statusText: String {
        switch model.stage {
        case .idle:
            return "准备就绪"
        case .listening:
            return "正在聆听，请弹奏 \(noteName)"
        case .measuring:
            return "正在分析泛音"
        case .done:
            if let measurement = model.lastMeasurement {
                return model.describe(measurement)
            }
            return "完成"
        case .failed(let message):
            return message
        }
    }

    private func applyToCurve() {
        curveModel.apply(measured: model.profile)
        speech.speak(curveModel.spokenSummary, settings: appModel.speechSettings)
    }

    private func measure() {
        model.startMeasure(settings: appModel.speechSettings)
    }
}
