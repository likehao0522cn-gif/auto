# 钢琴拉伸调律设计（曲线引擎）

版本：0.1（草案，待用户确认）
状态：技术设计，未实现
目标：在现有 iOS 调音节拍器里，新增「钢琴专业调律」能力——
非谐性测量、拉伸曲线、过拉，全部自研，不依赖任何第三方数据。

## 0. 边界声明（重要）

- 本项目**不复制、不反编译、不提取**任何第三方调律软件（如 TuneLab）
  的代码或数据。
- 全部算法基于公开的钢琴声学原理自研实现。
- 结果与商业软件**同级别**，但**不保证逐条曲线数值相同**，
  也不追求相同。专业调律软件之间本就不完全一致（Reyburn / TuneLab /
  PianoMeter 各算各的）。

## 1. 背景与原理

### 1.1 为什么需要拉伸曲线

钢琴弦不是理想弦。弦的劲度使各次泛音**比整数倍偏高**：

```
第 n 次泛音频率 ≈ n · f0 · sqrt(1 + B · n^2)
```

- `f0`：基频
- `B`：非谐性系数（inharmonicity coefficient），由弦长、张力、直径、
  材质决定
- 低音弦又粗又硬，B 大；高音弦细，B 小

调音时人耳听的是**拍音**（两个音的泛音差频）。若严格按十二平均律调：

- 低音区第 2 泛音与相邻音基音对不齐 → 有拍音
- 高音区基音与低音泛音对不齐 → 有拍音

为消除拍音，专业调律把**低音压低、高音抬高**，这就是「拉伸」
（stretch）。Railsback 曲线是最早的实测总结，现代软件用每架琴的实测
非谐性生成专属曲线。

### 1.2 三个核心量

| 量 | 含义 | 本项目的取法 |
|---|---|---|
| `B`（非谐性系数） | 弦的物理属性 | 现场实测各弦，或取琴型模板 |
| 拉伸曲线 | 每个音相对于平均律的偏差（音分） | 由 B 值按模型生成 |
| 过拉量 | 调律时先拉过头的补偿量 | 由曲线 + 目标差值、弦区模型算出 |

## 2. 算法设计

### 2.1 非谐性系数 B 的测量

对某根弦，测基频 `f0` 与第 2 泛音 `f2`：

```
n = 2
B = (f2^2 - (n · f0)^2) / (n^2 · f0^2)
```

更稳的做法是同时测第 2、第 3 泛音，对 B 取加权平均，剔除明显离群值。

**测量流程（盲人友好）**：

1. 用户选择要测的弦（或按顺序走完整台琴）。
2. 弹一次该弦，应用录一段持续音。
3. 对采样做 FFT / 泛音分析，找出前 3 个泛音峰。
4. 用峰频率解出 B，记录置信度（峰值是否清晰、是否偏离合理区间）。
5. 语音回报「这根弦测好了，非谐性中等」这类**可理解的话**，
   而不是只报一个 0.00021。

**B 的合理区间（用于校验）**：

| 音区 | 典型 B |
|---|---|
| 最低音区（最粗弦） | 0.0002 – 0.0008 |
| 中音区 | 0.0001 – 0.0003 |
| 高音区 | 0.00002 – 0.0001 |

超出区间视为测量失败，提示重测。

### 2.2 拉伸曲线生成

输入：一组按音区分布的 B 值（可实测，可用模板）。
输出：88 键每个音的**目标偏差（音分）**。

模型（公开做法，自研实现）：

1. 对每个音算出其 B（缺失处按相邻音插值）。
2. 用「泛音对齐」约束求解：相邻音之间的 4:2 或 2:1 泛音应尽量重合。
3. 中音区（约 A3–A4）作为锚点，偏差接近 0。
4. 低音区向下逐渐压低，高音区向上逐渐抬高，形状平滑单调。

实现上采用**参数化的平滑曲线**（例如以 B 为自变量、用若干控制点 +
单调插值），保证：

- 无异常跳变
- 曲线可解释、可复现
- 便于单元测试（给定 B → 期望偏差落在区间内）

### 2.3 过拉（overpull）

调律时把弦拉高会回弹。补偿模型：

```
过拉目标 = 最终目标 × (1 + k(音区) · 还差音分数)
```

- 还差得越多，过拉越多
- 低音区回弹大，`k` 更大
- 最大过拉量限制在约 3–6 音分，避免过拉损伤弦

`k` 的取值是本模型的**经验参数**，需真机调律验证后调整，
初期用保守值并明确告知用户。

## 3. 数据模型（Swift 类型草案）

放在 `Core/Sources/`，纯逻辑、无 SwiftUI 依赖，可在单元测试里验证。

```swift
/// 单根弦的非谐性测量结果。
public struct InharmonicityMeasurement: Codable, Equatable, Sendable {
    public let midi: Int          // 是哪个音
    public let b: Double          // 非谐性系数
    public let confidence: Double // 0..1
    public let partials: [Double] // 实测各次泛音频率，便于诊断
}

/// 整台琴的 B 值剖面（按音区，允许稀疏）。
public struct InharmonicityProfile: Codable, Equatable, Sendable {
    public let measurements: [Int: InharmonicityMeasurement] // midi -> 测量
    public let modelName: String?   // 若是模板，记录模板名
}

/// 一条拉伸曲线：88 键，每个音相对平均律的偏差（音分）。
public struct StretchCurve: Codable, Equatable, Sendable {
    public let centsByMIDI: [Int: Double]  // midi -> 偏差音分
    public let sourceProfileName: String
    public let isMeasured: Bool            // 实测 or 模板
}

/// 调律方案：把琴、曲线、基准音高绑在一起。
public struct TuningPlan: Codable, Equatable, Sendable {
    public let id: String
    public let name: String             // 用户起的名字，如「家里的三角琴」
    public let concertA: Double
    public let profile: InharmonicityProfile
    public let curve: StretchCurve
}

/// 内置琴型模板（B 值按音区的典型值）。
public struct PianoModelTemplate: Identifiable, Sendable {
    public let id: String
    public let displayName: String      // 如「小型立式琴」「三角琴」
    public let bByRegion: [PianoRegion: Double]
}
```

### 3.1 目标频率计算

现在 `PitchMath.frequency(forMIDI:concertA:)` 只算平均律。
新增：

```swift
/// 应用拉伸曲线后的目标频率。
static func stretchedFrequency(
    forMIDI midi: Int,
    concertA: Double,
    curve: StretchCurve
) -> Double {
    let ideal = frequency(forMIDI: Double(midi), concertA: concertA)
    let cents = curve.centsByMIDI[midi] ?? 0
    return ideal * pow(2, cents / 1200)
}
```

偏差仍用现有 `cents(from:to:)` 计算，只是 target 换成拉伸后的频率。

## 4. 无障碍设计（与现有规范一致）

现有项目已经有一套旁白/触觉规范。曲线功能必须**完全遵守**，
且新增点了几个特殊要求：

### 4.1 不能只靠图形

曲线是二维图形，对全盲用户**完全不可用**。因此：

- 曲线**必须有语音与数字表达**：
  - 「这台琴的曲线：低音区比标准低 8 音分，中音区接近标准，高音区高 12 音分」
  - 支持逐音查询：「第 3 八度的 C，目标比标准高 2 音分」
- 可选的曲线「形状朗读」（用单调性、极值点描述），不做逐点朗读。

### 4.2 测量流程的语音

- 每测完一根弦播报：弦名 + 结果等级（好 / 一般 / 失败）。
- 失败时明确说明原因（信号太弱 / 泛音不清 / 数值异常）。
- 不做连续自动播报，用户按「下一根」推进。

### 4.3 交互

- 选弦：沿用现有 `StringPickerView` 的模式（旁白聚焦后上下扫）。
- 所有按钮用 `accessibilityIdentifier` 稳定标识，便于测试。
- 调节类控件（如过拉强度）用 adjustable action。

### 4.4 音频与语音冲突

参照架构文档第 6 节：应用自身输出期间不做音高分析。
测弦时若播报，则暂停分析，播完再继续。

## 5. 分层与落点

```
Core/Sources/
  Inharmonicity.swift        // B 测量 + 剖面（新增）
  StretchCurve.swift         // 曲线生成 + 目标频率（新增）
  Overpull.swift             // 过拉模型（新增）
  PianoModelTemplates.swift  // 内置琴型模板（新增）
  PitchMath.swift            // 扩展：stretchedFrequency（改）
Core/Tests/
  InharmonicityTests.swift   // 新增
  StretchCurveTests.swift    // 新增
  OverpullTests.swift        // 新增
App/Sources/
  PianoTuningFlowView.swift  // 测弦流程（新增）
  StretchCurveView.swift     // 曲线展示 + 无障碍朗读（新增）
  TunerViewModel.swift       // 接入曲线模式（改）
```

XcodeGen 会自动纳入新文件，无需改 `project.yml` 的 sources。

## 6. 实施顺序（每步可单独验证）

1. **Inharmonicity**：B 测量 + 单元测试（用合成泛音验证）
2. **StretchCurve**：生成 + 单元测试（给定 B → 偏差在合理区间）
3. **PitchMath 扩展**：拉伸目标频率 + 测试
4. **过拉**：模型 + 测试
5. **琴型模板**：内置几类，给未实测的琴兜底
6. **UI：测弦流程**（盲人可用）
7. **UI：曲线朗读与逐音查询**
8. **接入调音主界面**：曲线模式
9. **无障碍真机验证**

## 7. 现实约束（照抄交接文档）

- 本机**没有 Xcode/Swift**，只能靠 GitHub Actions（macos-15）构建。
- 旁白相关改动**必须真机验证**，模拟器和静态检查都不能代替。
- 不要声称任何版本已真机验证。
- 每发一版换新版本号与构建标记。
- **XCTAssertEqual 的 `accuracy` 是绝对值不是音分。**
- Swift 类型推断易超时，视图 body 要拆。

## 8. 待用户确认

1. 内置琴型模板先做哪几类？（建议：小型立式、大型立式、三角琴）
2. 曲线数据是否需要**导出/导入**（换手机时带走？）
3. 测量流程：一次测几根弦？全琴 88 根太久，建议**每音区测 3–5 根**，
   其余插值。是否接受？
4. 过拉功能是否**首版就要**，还是先做曲线、过拉放第二版？

## 9. 单元测试策略（纯逻辑，可本机/CI 验证）

- 给定已知 B 与泛音频率，B 反解误差 < 1e-6。
- 合理 B 区间外应判失败。
- 给定 B 剖面，曲线中音区接近 0、低音为负、高音为正、单调平滑。
- 拉伸频率与平均律频率的差值，等于曲线给出的音分（往返一致）。
- 过拉在「还差 0 音分」时为 0，超限时被钳制。
- 曲线的 Codable 往返一致。
