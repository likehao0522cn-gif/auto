import SwiftUI
import TuneCore

struct CountInView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        Form {
            Section("预备拍") {
                Picker("预备拍", selection: $metronome.configuration.countInBars) {
                    ForEach(CountInBars.allCases) { countIn in
                        Text(countIn.title).tag(countIn)
                    }
                }
                .pickerStyle(.inline)

                Text("预备拍会在正式播放前建立速度和拍感。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("预备拍")
    }
}
