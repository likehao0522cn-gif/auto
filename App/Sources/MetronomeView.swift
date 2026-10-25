import SwiftUI

struct MetronomeView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("\(Int(metronome.configuration.bpm))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("BPM")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(metronome.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("速度")
                .accessibilityValue("\(Int(metronome.configuration.bpm)) BPM，\(metronome.statusText)")

                Stepper(
                    value: $metronome.configuration.bpm,
                    in: 20...300,
                    step: 1
                ) {
                    Text("调整速度")
                }
                .accessibilityValue("\(Int(metronome.configuration.bpm)) BPM")

                Button {
                    metronome.toggle()
                } label: {
                    Label(
                        metronome.isPlaying ? "停止" : "开始",
                        systemImage: metronome.isPlaying ? "stop.fill" : "play.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(metronome.isPlaying ? "停止节拍器" : "开始播放节拍器")
            }

            Section("节拍设置") {
                NavigationLink {
                    BeatSettingsView()
                } label: {
                    Label("拍号、重音和细分拍", systemImage: "music.note.list")
                }

                NavigationLink {
                    TapTempoView()
                } label: {
                    Label("测速", systemImage: "hand.tap")
                }

                NavigationLink {
                    CountInView()
                } label: {
                    Label("预备拍", systemImage: "hourglass")
                }
            }

            Section {
                NavigationLink {
                    MetronomeHelpView()
                } label: {
                    Label("帮助", systemImage: "questionmark.circle")
                }
            }

            if let errorMessage = metronome.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel("错误")
                        .accessibilityValue(errorMessage)
                }
            }
        }
        .navigationTitle("节拍器")
        .accessibilityAction(named: "开始或停止") {
            metronome.toggle()
        }
    }
}
