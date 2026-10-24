import SwiftUI

struct TapTempoView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel
    @StateObject private var viewModel = TapTempoViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("测速")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(viewModel.bpm.map { "\(Int($0.rounded())) BPM" } ?? "等待拍点")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("测速结果")
                .accessibilityValue(viewModel.bpm.map { "\(Int($0.rounded())) BPM" } ?? "还没有结果")

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                VStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 42))
                        .accessibilityHidden(true)
                    Text("测速区域")
                        .font(.title2.bold())
                    Text("连续单击记录拍点")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 260)
            .contentShape(RoundedRectangle(cornerRadius: 24))
            .onTapGesture {
                viewModel.tap()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("测速区域")
            .accessibilityValue("已记录 \(viewModel.tapCount) 拍")
            .accessibilityHint("连续单击记录拍点，不要求双击")
            .accessibilityAddTraits(.allowsDirectInteraction)

            Text("已记录 \(viewModel.tapCount) 拍")
                .foregroundStyle(.secondary)
                .accessibilityLabel("已记录拍点")
                .accessibilityValue("\(viewModel.tapCount) 拍")

            Button {
                viewModel.tap()
            } label: {
                Label("记录一拍", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("VoiceOver 下也可以双击这个按钮记录拍点")

            Button {
                if let bpm = viewModel.bpm {
                    metronome.applyTapTempo(bpm)
                }
            } label: {
                Label("应用到节拍器", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.bpm == nil)
            .accessibilityHint("把测速结果设为当前节拍器速度")

            Button("重新测速") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)

            Text("音量键测速会在真机验证后启用。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel("说明")
                .accessibilityValue("音量键测速会在真机验证后启用")
        }
        .padding()
        .navigationTitle("测速")
    }
}
