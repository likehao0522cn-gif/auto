import SwiftUI

struct MetronomeView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

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

                Stepper(
                    value: $metronome.configuration.bpm,
                    in: 20...300,
                    step: 1
                ) {
                    Text(verbatim: "调整速度")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "调整速度"))
                .accessibilityValue(Text(verbatim: "每分钟 \(Int(metronome.configuration.bpm)) 拍"))

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
    }
}
