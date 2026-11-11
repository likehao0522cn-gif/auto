import SwiftUI
import TuneCore

/// Browses the piano tuning curve as speech instead of a chart.
///
/// The whole screen is built for a blind user: the summary is read on entry,
/// the three regions are separate rows with their values, and every key can be
/// stepped through one at a time. Nothing here depends on seeing the curve.
struct PianoCurveView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var model: PianoCurveViewModel
    @State private var selectedKey: Int = 69
    @StateObject private var speech = SpeechFeedback()

    private var curve: StretchCurve {
        model.curve
    }

    private var keyName: String {
        Note(midi: selectedKey).displayName
    }

    var body: some View {
        List {
            summarySection
            measureSection
            templateSection
            regionSection
            keySection
            sourceSection
        }
        .navigationTitle("钢琴调律曲线")
        .onAppear {
            speak(StretchCurveNarration.summary(for: curve))
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section("曲线概况") {
            Button {
                speak(model.spokenSummary)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: model.spokenSummary)
                    Text(verbatim: "轻点重听")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "曲线概况"))
            .accessibilityValue(Text(verbatim: model.spokenSummary))
            .accessibilityHint(Text(verbatim: "轻点重新朗读"))
        }
    }

    private var measureSection: some View {
        Section("实测") {
            NavigationLink {
                PianoMeasureView()
            } label: {
                Text(verbatim: "测量这架琴")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "测量这架琴"))
            .accessibilityHint(Text(verbatim: "逐根弹奏琴弦，测出这架琴的非谐性"))
        }
    }

    private var templateSection: some View {
        Section("琴型") {
            ForEach(PianoModelTemplate.all) { template in
                templateRow(template)
            }
        }
    }

    private func templateRow(_ template: PianoModelTemplate) -> some View {
        let isSelected = model.selectedTemplateID == template.id
        return Button {
            model.selectTemplate(template)
            speak(StretchCurveNarration.summary(for: model.curve))
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

    private var regionSection: some View {
        Section("分区偏差") {
            ForEach(CurveRegion.allCases) { region in
                regionRow(region)
            }
        }
    }

    private func regionRow(_ region: CurveRegion) -> some View {
        let description = StretchCurveNarration.regionDescription(for: curve, region: region)
        return Button {
            speak(description)
        } label: {
            HStack {
                Text(verbatim: region.title)
                Spacer()
                Text(verbatim: description)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: region.title))
        .accessibilityValue(Text(verbatim: description))
        .accessibilityHint(Text(verbatim: "轻点朗读"))
    }

    private var keySection: some View {
        Section("逐音查看") {
            Stepper(value: $selectedKey, in: 21...108) {
                Text(verbatim: "当前音：\(keyName)")
            }
            .accessibilityLabel(Text(verbatim: "选择要查看的音"))
            .accessibilityValue(Text(verbatim: keyName))

            Button {
                speak(keyDescription)
            } label: {
                Text(verbatim: keyDescription)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(keyName) 的调律偏差"))
            .accessibilityValue(Text(verbatim: keyDescription))
            .accessibilityHint(Text(verbatim: "轻点朗读"))

            Button {
                stepKey(by: -12)
            } label: {
                Text(verbatim: "向下一个八度")
            }
            .disabled(selectedKey - 12 < 21)
            .accessibilityLabel(Text(verbatim: "向下一个八度"))

            Button {
                stepKey(by: 12)
            } label: {
                Text(verbatim: "向上一个八度")
            }
            .disabled(selectedKey + 12 > 108)
            .accessibilityLabel(Text(verbatim: "向上一个八度"))
        }
    }

    private var sourceSection: some View {
        Section("来源") {
            Text(verbatim: curve.source)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "曲线来源"))
                .accessibilityValue(Text(verbatim: curve.source))
        }
    }

    // MARK: - Helpers

    private var keyDescription: String {
        StretchCurveNarration.keyDescription(for: curve, midi: selectedKey, noteName: spokenKeyName)
    }

    private var spokenKeyName: String {
        appModel.displayName(forMIDI: selectedKey)
    }

    private func speak(_ text: String) {
        speech.speak(text, settings: appModel.speechSettings)
    }

    private func stepKey(by octaves: Int) {
        let target = min(108, max(21, selectedKey + octaves))
        guard target != selectedKey else { return }
        selectedKey = target
        speak(keyDescription)
    }
}
