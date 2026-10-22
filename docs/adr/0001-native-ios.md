# 使用原生 iOS 技术栈

产品需要低延迟音频、稳定的后台节拍器、可靠的 VoiceOver 交互和麦克风实时分析，因此决定采用 SwiftUI、AVAudioEngine、AVAudioSession、Core Haptics 和 AVSpeechSynthesizer 组成的原生 iOS 方案。跨平台框架会把这些核心能力推到插件层，增加音频时序和无障碍行为不一致的风险；首版也不同时支持 Android。
