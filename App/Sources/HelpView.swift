import SwiftUI

struct HelpTopic: Identifiable {
    let id: String
    let title: String
    let body: String
}

struct HelpView: View {
    private let topics: [HelpTopic] = [
        HelpTopic(
            id: "tune-string",
            title: "如何调一根弦",
            body: "进入调音器，选择乐器和弦位。应用会自动开始聆听。拨动琴弦，等待语音播报音名和音分偏差。偏低时把弦调高，偏高时把弦调低，再次拨弦即可得到新的结果。"
        ),
        HelpTopic(
            id: "voiceover",
            title: "如何用旁白调音",
            body: "打开旁白后，进入调音器会自动播报当前乐器、弦位和监听状态。左右滑动浏览控件，双击激活按钮；使用可调节控件上下滑动修改数值。当前结果会优先出现在焦点顺序中。"
        ),
        HelpTopic(
            id: "piano",
            title: "如何检查钢琴音高",
            body: "在调音器中选择钢琴。默认自动识别，弹一个键后会播报音名和音分偏差。如果低音区结果不稳定，可以切换到锁定目标音模式，先选择八度和音名，再弹奏该键。"
        ),
        HelpTopic(
            id: "metronome",
            title: "如何用节拍器",
            body: "进入节拍器，设置速度、拍号、重音和细分拍，然后点击开始。离开页面或锁屏后节拍器会继续播放。首页会显示播放状态和停止按钮。测速页可以单击测速区域记录拍点，也可以使用音量键。"
        ),
        HelpTopic(
            id: "faq",
            title: "常见问题",
            body: "如果听不到结果，请确认麦克风权限已开启，并靠近乐器。没有检测到稳定音高时应用会保持安静，可以点击查询结果了解当前状态。电话或语音助手中断后，节拍器需要重新点击开始。"
        )
    ]

    var body: some View {
        List(topics) { topic in
            NavigationLink {
                HelpArticleView(topic: topic)
            } label: {
                Text(verbatim: topic.title)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: topic.title))
        }
        .navigationTitle("帮助")
    }
}

struct HelpArticleView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            Text(verbatim: topic.body)
                .font(.body)
                .lineSpacing(6)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(topic.title)
    }
}

struct MetronomeHelpView: View {
    @EnvironmentObject private var metronome: MetronomeViewModel

    var body: some View {
        List {
            Section("播放状态") {
                Text(verbatim: metronome.isPlaying ? "节拍器仍在播放。" : "节拍器当前已停止。")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "播放状态"))
                    .accessibilityValue(Text(verbatim: metronome.isPlaying ? "正在播放" : "已停止"))
            }

            Section {
                NavigationLink {
                    HelpView()
                } label: {
                    Text(verbatim: "打开完整帮助")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "打开完整帮助"))
            }
        }
        .navigationTitle("节拍器帮助")
    }
}
