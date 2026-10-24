# 调音节拍器：技术架构草案

版本：0.1  
状态：功能基线已确认，进入技术设计  
目标：用原生 iOS 实现可验证的盲人调音与节拍器 MVP

## 1. 技术栈

- Swift + SwiftUI
- AVAudioEngine / AVAudioSession
- Accelerate / vDSP
- Core Haptics
- AVSpeechSynthesizer
- Swift Testing / XCTest
- 首版 iPhone，建议最低 iOS 17+
- 端上处理，不录音、不上传

不建议首版使用 Flutter 或 React Native。音频延迟、后台节拍器和 VoiceOver 行为是核心能力，原生实现更容易控制和验证。

## 2. 总体分层

```text
AppShell
├─ Navigation / Home
├─ TunerFeature
│  ├─ TunerStateMachine
│  ├─ PresetCatalog
│  ├─ TargetSelection
│  └─ ResultPresentation
├─ PianoFeature
│  ├─ AutoPitchMode
│  └─ LockedTargetMode
├─ MetronomeFeature
│  ├─ MetronomeStateMachine
│  ├─ TempoController
│  └─ TapTempoController
├─ AudioCore
│  ├─ AudioSessionCoordinator
│  ├─ InputCapture
│  ├─ PitchDetector
│  ├─ ToneGenerator
│  └─ MetronomeScheduler
├─ FeedbackCore
│  ├─ SpeechFeedback
│  ├─ EarconPlayer
│  └─ HapticFeedback
├─ AccessibilityCore
├─ Persistence
└─ Diagnostics
```

功能视图只依赖抽象状态和事件，不直接操作 AVAudioEngine。这样可以独立测试音高计算、状态转换和时序。

## 3. 调音器状态机

```text
idle
  -> listening
  -> noteDetected
  -> analyzing
  -> presentingResult
  -> listening
  -> paused
```

关键事件：

- enterTuner
- startListening
- pauseListening
- resumeListening
- pluckDetected
- pitchStabilized
- pitchChanged(> 5 cents)
- queryResult
- leavePage
- audioInterruption
- routeChanged

规则：

- 页面打开后自动进入 listening。
- 一次拨弦产生一次检测会话，约 1 秒稳定窗口。
- 同一检测会话最多自动更新 3 次。
- 连续静音约 300 毫秒后才接受下一次拨弦事件。
- 离开页面释放麦克风。
- 打开帮助、设置或参考音时暂停分析。
- 电话或 Siri 中断结束后，调音器自动恢复监听。

## 4. 音高检测

### 4.1 输入

- 单声道输入。
- 目标采样率 44.1 kHz 或 48 kHz。
- 使用约 4096 采样窗口起步；低音区根据频率使用更长窗口。
- 音频回调中只复制数据，不在实时线程做重计算。

### 4.2 算法

首版采用单音基频检测：

1. 高通/噪声门限预处理。
2. 用能量包络检测起音。
3. 用 YIN、McLeod 或自相关类算法估计基频。
4. 用抛物线插值提高音分分辨率。
5. 用多帧中位数和置信度过滤瞬态、泛音和噪声。
6. 根据十二平均律映射音名和音分偏差。

代码应把算法实现为纯 Swift 核心，不依赖 SwiftUI，以便在 Linux/macOS 或普通单元测试中验证。

### 4.3 音高映射

- 默认 A4 = 440 Hz。
- 音分公式：`1200 * log2(f / targetFrequency)`。
- 自动模式取最近的十二平均律音名。
- 自动模式结果接近半音边界时，应附加相邻音提示。
- 锁定模式只计算相对用户选定目标音的偏差。

### 4.4 准确度目标

- 实验室稳定正弦音：±1 音分。
- 真实安静环境稳定单音：通常达到 ±3 音分。
- 低音区允许更低置信度，并明确提示“请再弹一次”。
- 不允许用不可靠的高置信度结果误导用户。

### 4.5 钢琴特殊处理

- 自动识别和锁定目标音两种模式。
- 低音区使用更长分析窗口。
- 检测到多个明显基频且不符合单一泛音列时，拒绝猜测，提示一次弹一个音。
- 首版不做拍频、同度调整和拉伸调律。

## 5. 节拍器

### 5.1 调度

- 使用 AVAudioEngine + AVAudioPlayerNode。
- 基于采样时间提前调度，不使用 Timer 驱动节拍。
- 主线程只处理 UI 和状态通知。
- 后台音频通过 Audio background mode 持续。

### 5.2 状态机

```text
stopped
  -> countingIn
  -> playing
  -> pausedByInterruption
  -> stopped
```

- 开始前可选预备拍。
- 中断时暂停，不自动恢复。
- 停止只能由用户明确操作。
- 离开页面和锁屏不改变播放状态。

### 5.3 测速

- 测速区域使用直接触摸，不要求双击。
- 音量键拦截作为增强能力，必须真机验证。
- 每次拍点记录高精度时间戳。
- 满 3 拍计算初步 BPM，之后滚动更新。
- 约 3 秒无拍点重置。
- 结果需要用户确认才应用到当前节拍器。

## 6. 音频会话与冲突

- 调音器模式需要麦克风输入和参考音输出。
- 节拍器模式需要可后台的播放会话。
- 切换模式时必须显式重建/配置 AudioSession。
- 参考音播放期间暂停或忽略音高分析。
- 任何应用提示音、语音或参考音期间，都不应把应用自身输出当作输入。
- 需要验证扬声器外放时的回声/自激风险。
- 不做单耳模式；所有应用声音从两侧输出。

## 7. 反馈层

### 7.1 语音

- 进入调音器时播报一次当前乐器、弦位和监听状态。
- 首次结果播报完整结果。
- 自动更新可以配置为数字 + 触觉或仅短音型 + 触觉。
- 查询结果只重播最近一次稳定结果。
- 不做连续播报。

### 7.2 音型

- 偏高：上行两音。
- 偏低：下行两音。
- 准了：单声确认音。
- 音型要短，避免遮住乐器声。

### 7.3 触觉

- 偏高：两次短震。
- 偏低：一次长震。
- 准了：两次短震。
- Core Haptics 不支持时降级为 UIFeedbackGenerator。

## 8. 无障碍

- 所有交互元素提供 VoiceOver 标签、值、提示和 traits。
- 调节类控件使用 adjustable trait。
- 页面使用稳定焦点顺序。
- 自定义转子只作为快捷方式，不能成为唯一入口。
- 测速区域使用 direct interaction，并保留替代操作。
- 兼容 Voice Control、Switch Control、盲文显示器和屏幕 curtain。
- 视觉界面高对比、大字、不依赖颜色。
- 不自动播放无法停止的长语音。

## 9. 持久化

使用 AppStorage/UserDefaults 保存：

- 上次乐器。
- 上次弦位或目标音。
- A4 标准音高。
- 准音容差。
- 音名读法。
- 自动更新播报方式。
- 参考音音色。
- 节拍器 BPM、拍号、重音、细分拍和预备拍。
- 界面语言。
- 触觉和语音设置。

不保存音频，不保存钢琴检查历史。

## 10. 诊断

由于开发环境可能没有 Mac，应用需要提供开发诊断入口：

- 当前音频路由。
- 麦克风权限状态。
- 输入采样率和缓冲大小。
- 当前检测频率、音名、音分和置信度。
- 节拍器调度偏差。
- 最近一次错误。

诊断信息以可朗读文本显示，便于盲测时反馈。

## 11. 测试策略

### 11.1 单元测试

- 频率到音名/音分映射。
- A4 校准。
- 容差边界。
- 乐器预设音高数据。
- 稳定窗口和更新次数。
- BPM 计算和拍点重置。
- 节拍器时序计算。

### 11.2 音频测试

- 合成正弦波、锯齿波和衰减音。
- 录制的吉他、提琴、二胡和钢琴样本。
- 低音、泛音、噪声和多人环境测试。
- 不把“能检测到”误当成“准确”。

### 11.3 真机测试

- 麦克风权限和中断。
- VoiceOver 焦点和朗读顺序。
- 屏幕 curtain。
- 后台/锁屏节拍器。
- 蓝牙、有线和外放音频路由。
- 音量键测速。
- 触觉反馈。

### 11.4 盲测

按功能规格中的 5 个任务进行，至少 3–5 位真实盲人或低视力用户。

## 12. 构建与分发

当前开发环境为 Windows，无法运行 Xcode 或 iOS 模拟器。可选路线：

1. GitHub Actions macOS 构建 + TestFlight 上传。
2. 云端 Mac 进行关键阶段调试。
3. 借用或购买 Mac mini 进行真机调试。

建议采用：

- 日常：Windows 写代码，GitHub Actions macOS 编译并上传 TestFlight。
- 关键阶段：短期使用云 Mac 处理 Xcode 项目配置、签名、音频和 VoiceOver 调试。
- 测试：用户在 iPhone 上通过 TestFlight 安装。

需要准备：

- GitHub 私有仓库。
- Apple Developer Program 账号。
- App Store Connect App 记录。
- 签名证书和 Provisioning Profile。
- GitHub Actions Secrets 或 App Store Connect API Key。

## 13. 建议的首个技术验证

在完整开发前，只验证 6 件事：

1. 能在 iPhone 上安装并启动 TestFlight 构建。
2. 能请求麦克风权限并稳定播放测试音。
3. 能检测一个稳定音高并给出音名和音分。
4. VoiceOver 能按预期读到结果并操作暂停/继续。
5. 节拍器能后台播放且离开页面不停止。
6. 音量键测速和触觉反馈在目标设备上的实际行为。

验证通过后再实现全部预设、钢琴低音处理、完整设置和盲测版本。

## 14. 主要风险

- Windows 无法本地编译 iOS，云端构建反馈慢。
- 音量键拦截可能受 iOS 系统限制。
- VoiceOver/语音/提示音与麦克风输入可能互相干扰。
- 低音区和真实乐器泛音导致误判。
- 蓝牙音频延迟影响节拍器精度。
- 后台和锁屏时触觉不可保证。
- 不同盲人用户的交互习惯差异较大，必须真实测试。
