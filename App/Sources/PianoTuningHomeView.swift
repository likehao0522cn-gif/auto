import SwiftUI
import TuneCore

/// The piano tuning module: a self-contained area for professional piano
/// tuning, kept separate from the general tuner used for other instruments.
///
/// Everything here works on a stretch curve rather than plain equal
/// temperament, because that is what a piano needs. Grouping it in one place
/// keeps the general tuner simple for guitars, strings and the like.
struct PianoTuningHomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var curveModel = PianoCurveViewModel()
    @StateObject private var speech = SpeechFeedback()

    var body: some View {
        List {
            curveSummarySection
            tuningSection
            setupSection
            modelSection
        }
        .navigationTitle("钢琴调律")
        .onAppear {
            speak(curveModel.spokenSummary)
        }
    }

    // MARK: - Sections

    private var curveSummarySection: some View {
        Section("当前曲线") {
            Button {
                speak(curveModel.spokenSummary)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: curveModel.spokenSummary)
                    Text(verbatim: "轻点重听")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "当前调律曲线"))
            .accessibilityValue(Text(verbatim: curveModel.spokenSummary))
            .accessibilityHint(Text(verbatim: "轻点重新朗读"))
        }
    }

    private var tuningSection: some View {
        Section("调律") {
            NavigationLink {
                PianoTuningView()
                    .environmentObject(curveModel)
            } label: {
                Text(verbatim: "开始调律")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "开始调律"))
            .accessibilityHint(Text(verbatim: "按当前曲线逐音调律"))
        }
    }

    private var setupSection: some View {
        Section("准备") {
            NavigationLink {
                PianoMeasureView()
                    .environmentObject(curveModel)
            } label: {
                Text(verbatim: "测量这架琴")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "测量这架琴"))
            .accessibilityHint(Text(verbatim: "逐根弹奏琴弦，测出这架琴的非谐性"))

            NavigationLink {
                PianoCurveView()
                    .environmentObject(curveModel)
            } label: {
                Text(verbatim: "查看调律曲线")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "查看调律曲线"))
        }
    }

    private var modelSection: some View {
        Section("琴型") {
            ForEach(PianoModelTemplate.all) { template in
                templateRow(template)
            }
        }
    }

    private func templateRow(_ template: PianoModelTemplate) -> some View {
        let isSelected = curveModel.selectedTemplateID == template.id
        return Button {
            curveModel.selectTemplate(template)
            speak(StretchCurveNarration.summary(for: curveModel.curve))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: template.displayName)
                    Text(verbatim: template.spokenDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: template.displayName))
        .accessibilityValue(Text(verbatim: isSelected ? "已选择" : "未选择"))
        .accessibilityHint(Text(verbatim: template.spokenDescription))
    }

    private func speak(_ text: String) {
        speech.speak(text, settings: appModel.speechSettings)
    }
}
