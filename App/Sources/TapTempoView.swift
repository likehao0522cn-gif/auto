import SwiftUI

struct TapTempoView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var metronome: MetronomeViewModel
    @StateObject private var viewModel = TapTempoViewModel()
    @StateObject private var volumeButtons = TapTempoVolumeButtons()

    var body: some View {
        VStack(spacing: 20) {
            Text("测速")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

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
                viewModel.tap(hapticsEnabled: appModel.tapTempoHapticsEnabled)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("测速区域")
            .accessibilityValue("已记录 \(viewModel.tapCount) 拍")
            .accessibilityHint("连续单击记录拍点，不要求双击")
            .accessibilityAddTraits(.allowsDirectInteraction)

            Text("已记录 \(viewModel.tapCount) 拍")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Button {
                viewModel.tap(hapticsEnabled: appModel.tapTempoHapticsEnabled)
            } label: {
                Text("记录一拍")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .accessibilityLabel("记录一拍")
            .buttonStyle(.bordered)
            .accessibilityHint("VoiceOver 下也可以双击这个按钮记录拍点")

            Button {
                if let bpm = viewModel.bpm {
                    metronome.applyTapTempo(bpm)
                }
            } label: {
                Text("应用到节拍器")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .accessibilityLabel("应用到节拍器")
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.bpm == nil)
            .accessibilityHint("把测速结果设为当前节拍器速度")

            Button("重新测速") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)

            Toggle("拍点触觉反馈", isOn: $appModel.tapTempoHapticsEnabled)
                .accessibilityHint("关闭后，记录拍点时不产生触觉反馈")

            Text("可使用音量键记录拍点；该能力仍需真机验证，失败时请使用屏幕区域或“记录一拍”按钮。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel("说明：可使用音量键记录拍点，仍需真机验证。失败时请使用屏幕区域或记录一拍按钮")
        }
        .padding()
        .navigationTitle("测速")
        .onAppear {
            volumeButtons.start {
                viewModel.tap(hapticsEnabled: appModel.tapTempoHapticsEnabled)
            }
        }
        .onDisappear {
            volumeButtons.stop()
        }
    }
}
