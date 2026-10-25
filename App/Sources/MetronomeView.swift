import SwiftUI

struct MetronomeView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel
    @AccessibilityFocusState private var focusedSection: MetronomeAccessibilityFocus?

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
                .accessibilityFocused($focusedSection, equals: .status)

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
                .accessibilityFocused($focusedSection, equals: .playback)
            }

            Section("节拍设置") {
                NavigationLink {
                    MetronomeSoundSettingsView()
                } label: {
                    Label("音色和触觉", systemImage: "waveform")
                        .accessibilityFocused($focusedSection, equals: .soundSettings)
                }

                NavigationLink {
                    BeatSettingsView()
                } label: {
                    Label("拍号、重音和细分拍", systemImage: "music.note.list")
                        .accessibilityFocused($focusedSection, equals: .beatSettings)
                }

                NavigationLink {
                    TapTempoView()
                } label: {
                    Label("测速", systemImage: "hand.tap")
                        .accessibilityFocused($focusedSection, equals: .tapTempo)
                }

                NavigationLink {
                    CountInView()
                } label: {
                    Label("预备拍", systemImage: "hourglass")
                        .accessibilityFocused($focusedSection, equals: .countIn)
                }
            }

            Section {
                NavigationLink {
                    MetronomeHelpView()
                } label: {
                    Label("帮助", systemImage: "questionmark.circle")
                        .accessibilityFocused($focusedSection, equals: .help)
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
        .accessibilityRotor("节拍器快速导航") {
            AccessibilityRotorEntry("播放状态和速度", id: MetronomeAccessibilityFocus.status)
            AccessibilityRotorEntry("开始或停止", id: MetronomeAccessibilityFocus.playback)
            AccessibilityRotorEntry("音色和触觉", id: MetronomeAccessibilityFocus.soundSettings)
            AccessibilityRotorEntry("节拍设置", id: MetronomeAccessibilityFocus.beatSettings)
            AccessibilityRotorEntry("测速", id: MetronomeAccessibilityFocus.tapTempo)
            AccessibilityRotorEntry("预备拍", id: MetronomeAccessibilityFocus.countIn)
            AccessibilityRotorEntry("帮助", id: MetronomeAccessibilityFocus.help)
        }
        .accessibilityAction(named: "开始或停止") {
            metronome.toggle()
        }
    }
}

private enum MetronomeAccessibilityFocus: Hashable {
    case status
    case soundSettings
    case playback
    case beatSettings
    case tapTempo
    case countIn
    case help
}