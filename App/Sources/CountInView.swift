import SwiftUI
import TuneCore

struct CountInView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        Form {
            Section("预备拍") {
                Picker(selection: $metronome.configuration.countInBars) {
                    ForEach(CountInBars.allCases) { countIn in
                        Text(verbatim: countIn.title).tag(countIn)
                    }
                } label: {
                    Text(verbatim: "预备拍")
                }
                .pickerStyle(.inline)
                .accessibilityLabel(Text(verbatim: "预备拍"))

                Text(verbatim: "预备拍会在正式播放前建立速度和拍感。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("预备拍")
    }
}
