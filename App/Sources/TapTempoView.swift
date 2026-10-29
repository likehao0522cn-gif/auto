import SwiftUI

struct TapTempoView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var metronome: MetronomeViewModel
    @StateObject private var viewModel = TapTempoViewModel()
    @StateObject private var volumeButtons = TapTempoVolumeButtons()

    var body: some View {
        VStack(spacing: 20) {
            Text(verbatim: "测速")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(verbatim: viewModel.bpm.map { "每分钟 \(Int($0.rounded())) 拍" } ?? "等待拍点")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "测速结果"))
                .accessibilityValue(Text(verbatim: viewModel.bpm.map { "每分钟 \(Int($0.rounded())) 拍" } ?? "还没有结果"))

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 42))
                        .accessibilityHidden(true)
                    Text(verbatim: "测速区域")
                        .font(.title2.bold())
                    Text(verbatim: "连续单击记录拍点")
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)
                TapTempoPad(tapCount: viewModel.tapCount) {
                    viewModel.tap(hapticsEnabled: appModel.tapTempoHapticsEnabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: 260, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 24))

            Text(verbatim: "已记录 \(viewModel.tapCount) 拍")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Button {
                viewModel.tap(hapticsEnabled: appModel.tapTempoHapticsEnabled)
            } label: {
                Text(verbatim: "记录一拍")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "记录一拍"))
            .buttonStyle(.bordered)

            Button {
                if let bpm = viewModel.bpm {
                    metronome.applyTapTempo(bpm)
                }
            } label: {
                Text(verbatim: "应用到节拍器")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "应用到节拍器"))
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.bpm == nil)

            Button {
                viewModel.reset()
            } label: {
                Text(verbatim: "重新测速")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "重新测速"))
            .buttonStyle(.bordered)

            Toggle(isOn: $appModel.tapTempoHapticsEnabled) {
                Text(verbatim: "拍点触觉反馈")
            }

            Text(verbatim: "可使用音量键记录拍点；该能力仍需真机验证，失败时请使用屏幕区域或“记录一拍”按钮。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top)
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
