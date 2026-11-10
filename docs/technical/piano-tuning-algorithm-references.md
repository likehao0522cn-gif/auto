# 钢琴调律算法参考资料（公开来源）

版本：0.1
状态：参考资料，非本仓库代码
用途：为 `docs/technical/piano-stretch-tuning-design.md` 提供公开、可引用的
算法依据。实现时用 Swift 重写，不复制第三方代码。

## 0. 结论先说

- **算法（数学方法）本身不是版权保护对象**，可以自由学习和实现。
- **第三方开源项目的具体代码是受版权保护的**（Entropy Piano Tuner 是
  GPLv3）。直接抄它的 C++ 到闭源 Swift app 会触发 GPL 义务。
- 因此本项目的做法：**用公开的物理原理与标准方法，自己写 Swift 实现。**
- 本文件记录的是**方法和公式**，不是可粘贴的代码。

## 1. 主要参考来源

### 1.1 Entropy Piano Tuner（EPT）
- 地址：https://github.com/levush/Entropy-Piano-Tuner （官方镜像）
- 原项目：https://www.entropypianotuner.org
- 许可证：**GNU GPL v3**（见各源文件头部声明）
- 作者：Haye Hinrichsen, Christoph Wick（2016）
- 价值：一个完整、学术级的开源钢琴调律实现，明确写出了
  非谐性测量、外推、拉伸曲线构造的全部公式。
- 引用方式：**只取其公开的公式与流程，Swift 重写。**
  若将来有人要求，可注明"方法参考 EPT 论文/公开描述"。

### 1.2 经典钢琴声学结论（公开知识）
- 非谐性泛音公式：`f_n = n · f1 · sqrt((1 + B·n^2) / (1 + B))`
  这是钢琴弦刚性模型的教科书结论（Fletcher、Rossing《The Physics of
  Musical Instruments》等都有）。
- Railsback 曲线：1941 年 O. L. Railsback 实测的钢琴拉伸曲线，
  被后续所有调律软件当作参照。属公开学术数据。

## 2. 关键公式（本项目将采用的）

### 2.1 非谐性泛音的频率
```
f_n = f1 · n · sqrt( (1 + B·n^2) / (1 + B) )
```
- `f1` 基频，`n` 泛音序号，`B` 非谐性系数
- 注意分母 `(1+B)`：这是"以实测基频为基准"的写法，
  即基频本身也已经包含非谐性修正。

### 2.2 由两个泛音反解 B
已知 `f1` 与某高次泛音 `f_n`，由 2.1 反解：
```
令 x = (f_n / (n · f1))
x^2 = (1 + B·n^2) / (1 + B)
=> B = (x^2 - 1) / (n^2 - x^2)
```
（工程上用两个以上泛音取平均，剔除离群。）

### 2.3 第 n 泛音相对平均律的拉伸偏差（音分）
对某键，其第 n 泛音的非谐偏移为：
```
cents(key, n) = (600 / ln2) · ln( (1 + n^2·B(key)) / (1 + B(key)) )
```
（EPT 用 `600/LOG2 · log(...)`，`LOG2 = ln2`，等价于上式。）

### 2.4 非谐性随频率的经验模型（默认兜底）
当某键的 B 没实测时，用公开的经验关系（EPT 的
`Piano::getExpectedInharmonicity` 采用的形式）：
```
f > 100 Hz：  B(f) = exp(-15.45 + 1.354 · ln(f))
f <= 100 Hz： B(f) = exp(-2.622 - 1.431 · ln(f))
```
（`f` 为频率 Hz。这是一条被广泛使用的钢琴 B–f 关系曲线。）

### 2.5 非谐性外推（对数线性回归）
实测只覆盖部分键。对低音段（bass）和高音段（treble）分别做
**对数线性回归**：
```
ln B(k) ≈ a + b·k      （k 为键序号）
```
用最小二乘拟合 `a, b`，再回代补全未测的键。
- 用 `ln B` 而不是 `B`：因为 B 随键号近似指数衰减。
- 分段（低音/高音）而非一条直线：因为两段斜率不同。
- 离群剔除：若某实测 `B` 与回归预测的比值超出阈值（EPT 用
  `|ln(B/B_est)| > 0.2`），判为不可信，改用回归值。

### 2.6 拉伸曲线构造（4:2 / 2:1 / 6:3 / 10:5 混合八度法）

以 A4 为重心，中音区先铺一段线性过渡，再向两端迭代外推。

**中音线性段**（A3—A5 之间）：
```
pitchA5 = cents(A4, 2)                    // A4 的第 2 泛音偏差
pitchA3 = cents(A4, 2) - cents(A3, 4)     // 4:2 关系
// A3..A4 之间线性插值到 0；A4..A5 之间线性插值到 pitchA5
```

**向右（高音）迭代**，键 k 由 k-12 推得：
```
pitch42  = pitch(k-12) + cents(k-12, 4) - cents(k, 2)   // 4:2 八度
pitch21  = pitch(k-12) + cents(k-12, 2)                 // 2:1 八度
pitch(k) = 0.3 · pitch42 + 0.7 · pitch21
```

**向左（低音）迭代**，键 k 由 k+12 推得：
```
pitch42  = pitch(k+12) + cents(k+12, 2) - cents(k, 4)    // 4:2 八度
pitch105 = pitch(k+12) + cents(k+12, 5) - cents(k, 10)   // 10:5 八度
fraction = k / keyA3
pitch(k) = pitch42 · fraction + pitch105 · (1 - fraction)
```

**过拉（pitch raise 变体）**：同一套迭代，只是权重略不同
（EPT 的 PitchRaise 在高音段用 `0.3·4:2 + 0.7·2:1`，
低音段从 4:2 平滑过渡到 10:5）。这就是"整体升音时先拉过头"
所依据的曲线。

**关键点**：这套 4:2 / 2:1 / 6:3 / 10:5 混合八度法是**钢琴调律的
行业标准做法**，多本调律教材（如 Reblitz《Piano Servicing, Tuning,
and Rebuilding》）都有描述，不是某一家软件专有。

### 2.7 过拉量（cents）
EPT 的 Key 里 overpull 直接以音分存储，且**限制在 ±25 音分**：
```
overpull = clamp(cents, -25, +25)
```
实际过拉量由"目标音高与当前音高之差"决定，升音越多过拉越大。

### 2.8 频率 ↔ 音分换算
```
cents(f, f_ref) = 1200 · log2(f / f_ref)
```
第 k 键的平均律频率（A4=440）：
```
f_ET(k) = 440 · 2^((k - keyA4) / 12)
```
（本仓库 `PitchMath` 已有等价实现。）

## 3. 敏感度与量级参考（用于校验实现）

- 低音区 B 典型 1e-4 ~ 1e-3 量级；高音区 1e-5 ~ 1e-4。
- 拉伸曲线全长偏差量级：低音端约 **-10 ~ -30 音分**，
  高音端约 **+10 ~ +40 音分**（视琴与 B 而定）。
- 中音区（A3—A4 附近）偏差接近 0。
- 若实现得到的曲线在中音区偏离 0 超过几个音分，多半是算错了。

## 4. 许可证与合规

| 来源 | 许可证 | 能否直接用代码 |
|---|---|---|
| Entropy Piano Tuner | GPLv3 | ❌ 直接抄会传染 GPL；✅ 学方法后自写 |
| 钢琴声学教科书公式 | 公开知识 | ✅ 公式不受版权保护 |
| Railsback 曲线数据 | 学术公开 | ✅ 可引用，注明出处 |

**本项目立场**：所有 Swift 实现均为独立编写，公式来自公开物理原理；
不使用任何第三方软件的私有数据（包括 TuneLab）。

## 5. 与本仓库的衔接

- 非谐性测量 → 新增 `Core/Sources/Inharmonicity.swift`
- 拉伸曲线 → 新增 `Core/Sources/StretchCurve.swift`
- 过拉 → 新增 `Core/Sources/Overpull.swift`
- 默认 B 模型与琴型模板 → 新增 `Core/Sources/PianoModelTemplates.swift`
- 目标频率 → 扩展 `Core/Sources/PitchMath.swift`

详见 `docs/technical/piano-stretch-tuning-design.md`。
