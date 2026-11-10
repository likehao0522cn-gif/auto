# 交接文档（2026-11-10 当前）

> 开新会话时，请先完整阅读本文件，再继续操作。

## 1. 项目与用户目标

项目路径：`D:\调音节拍器`

这是一个面向盲人和低视力用户的 iOS SwiftUI 调音节拍器。

用户当前最关心：

- 调音器要**专业**，每种乐器按真实声学特性处理
- 旁白朗读简短准确，不要读奇怪英文
- 节拍器单手好按，常用速度好找
- SideStore 能无线更新

## 2. 当前分支与提交状态

- 分支：`fix/tuner-lifecycle`
- 本地 HEAD：`0e0a950 Compute peak magnitudes in one pass to cut detection time`
- 工作区：干净（两个 APK 文件未纳入版本控制，正常）
- 已发布标签：`v0.6.5` 到 `v0.6.11`

### 关键：本地与远端可能不一致

**Git 直连 `github.com:443` 经常被重置。** 推送失败时用 API 推送，
这会产生**内容相同但 SHA 不同**的提交，导致本地显示
`ahead N, behind N`。

处理方式：
1. `git fetch origin fix/tuner-lifecycle`
2. 对比 tree：`git rev-parse HEAD^{tree}` 与 `git rev-parse origin/fix/tuner-lifecycle^{tree}`
3. **tree 相同**说明内容一致，可 `git rebase origin/fix/tuner-lifecycle`
4. **tree 不同**则先确认差异，不要盲目 reset

## 3. 版本与发布流程

- 版本号在 `project.yml`：
  - `CFBundleShortVersionString` / `MARKETING_VERSION`
  - `CFBundleVersion` / `CURRENT_PROJECT_VERSION`
- 构建标记在 `App/Sources/HomeView.swift` 的 `accessibilityIdentifier`，
  必须与 `.github/workflows/ios.yml` 里两处 `grep` 一致
- 当前：版本 0.6.11，构建号 17，标记 `NOTE_BOUNDARY_2026_11_06`
- **每发一版都要换新的版本号和构建标记**
- 发布命令：

```bash
git push origin fix/tuner-lifecycle
git tag -a vX.Y.Z -m "TuneMetronome X.Y.Z"
git push origin vX.Y.Z
```

- 推送超时时加：
  `-c http.version=HTTP/1.1 -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=30 -c http.postBuffer=524288000`

### CI 运行环境（重要）

- workflow 用 `runs-on: macos-15`
- **不要改回 `macos-14`**：该仓库会把它解析成不支持的 arm64 池，
  导致 job 分配不到 runner（`runner: none`，直接 cancelled）

### 发布后常见现象

- 最后一步 `Verify published SideStore source` 常因 CDN 延迟失败，
  **但 Release 资产通常已经正常生成**，需手工核对
- 核对方式：查 `releases/tags/vX.Y.Z` 的 assets 和 `releases/latest/download/source.json`
- GitHub 直连下载慢时用镜像：`https://gh-proxy.com/https://github.com/...`
  或 `https://ghfast.top/https://github.com/...`

## 4. 已完成的功能

### 调音器主界面

- 显示模式（锁定目标音 / 自动识别）
- 乐器选择：点击弹出选择页，旁白聚焦后上下清扫切换
- 弦位 / 目标音选择
- 当前结果卡片
- 操作按钮：播放参考音、查询结果、开始或暂停聆听、帮助
- 右上角齿轮进入调音器设置

### 乐器列表顺序（0.6.10 起）

```
钢琴 → 吉他 → 尤克里里 → 小提琴 → 大提琴 → 二胡 → 古筝 → 琵琶 → 任意音高
```

- 钢琴排第一，也是新用户默认
- 「半音模式」已改名「任意音高」，移到最后（它是兜底选项）
- ID 仍是 `chromatic`，老用户设置不丢

### 按乐器分类的检测参数

`Core/Sources/DetectionProfile.swift` 定义四类：

| 类别 | 乐器 | 多音门槛 | 置信度 | 允许抖动 | 降噪倍数 |
|---|---|---|---|---|---|
| 弓弦乐 | 二胡 | 0.65 | 0.50 | 0.06 | 3.0 |
| 钢琴 | 钢琴 | 0.45 | 0.55 | 0.04 | 2.2 |
| 弹拨弦乐 | 吉他、尤克里里、小提琴、大提琴、古筝、琵琶 | 0.40 | 0.58 | 0.035 | 2.5 |
| 任意音高 | 任意音高 | 0.30 | 0.62 | 0.03 | 2.5 |

低音区（<120 Hz）在所属类别基础上再加 0.20。

**这些是推导的初始值，尚未真机校准。**

### 音高检测（PitchDetector）

- YIN 算法，最小频率 27.5 Hz，最大 5000 Hz
- 捕获缓冲 **16384 样本**（约 372ms），保证低音有足够周期
- **八度纠错**：若 tau/2 或 tau/3 处最小值接近，优先取短的
- **在差分曲线上做抛物线插值**（精度比归一化曲线好，E7 以上 0.1-0.7 音分）
- 弱信号拒判：
  - `rms >= 0.002` 才进入检测
  - `rms < 0.003` 直接丢弃
  - `rms < 0.006` 且置信度 < 0.90 丢弃

### 多音检测（MultiplePitchDetector）

- **自适应扫描网格**：步长 `max(2.0, min(10.0, 基频 * 0.02))`
  - 低频细（1-2 Hz），高频粗（10 Hz）
  - 固定 10 Hz 会把 B1 量化到 G1 泛音上，这是低音误报的根因
- **子谐波排除**：只排除真正的 1/2、1/3（不能一刀切 <= 0.75，
  否则 YIN 锁到高音时真实低音会被误删）
- **分析窗口按基频长度**：`sampleRate / 基频 * 12`，最少 4096 样本
- **谐波支持作为兜底**：
  - 强峰（超过门槛）直接采信
  - 弱峰需自证有第二/第三泛音
  - 只检查最强 3 个峰（性能）
- **单遍计算振幅**（性能，避免重复 O(n) 扫描）

### 朗读与显示

- **显示单位可选**：音分 / 赫兹，**旁白朗读与屏幕显示使用同一文本生成函数**
  （`TuningFeedback.resultLine`），保证两者不会不一致
- 音名与数值之间**加空格**：`C7， 2093.0 赫兹`，避免中文 TTS 连读
- 黑键朗读为「升C四」（界面仍显示 `C#4`）
- **重复音名省略**：同一音名在窗口内重复只朗读数值
  - 可选 关闭 / 3 / 5 / 8（默认）/ 15 / 30 秒
  - 查询结果时始终读全
- 首次进入调音器显示「**开始聆听**」，不是「继续聆听」

### 调音器设置（在调音器页面内）

- 标准音高：**每个乐器独立**，10 个预设 + 自定义输入（392-466）
  - 老数据自动迁移：原全局值成为默认值
- 准音容差、显示单位、重复音名省略
- 音名读法、自动更新反馈
- 「进入后自动开始检测」开关
- 键盘「确定」在**输入框右侧同一行**（紧贴键盘上方，仿微信发送栏）

### 节拍器

- 主界面：大号 BPM、拍号清扫选择、测速、输入速度、底部播放控制
- 底部控制区上移（留白 32pt，按键间距 22pt）
- 播放中改参数只重建节拍，**不再朗读「节拍器开始」**
- 调速有 180ms 防抖
- **常用速度**（上限 10 个）：
  - 手动添加：一键加入当前速度 / 输入其他速度
  - 自动加入：使用 5 次 **且** 累计播放 2 分钟
  - 三种排序：速度从小到大 / 使用次数从多到少 / 使用时间从多到少
  - 列表全屏显示
  - 滑动删除
- 输入速度时**输入框为空**（不需要先删除）

## 5. 真机状态

- 手机 iPhone（可爱喵），iOS 26.6.2
- 已确认安装 0.6.11 之前的某个版本
- SideStore 已登录，无线更新可用
- **更新时如果看不到新版本**：删源重加
  `https://github.com/likehao0522cn-gif/auto/releases/latest/download/source.json`

## 6. 已知问题（用户真机反馈，尚未解决）

### 高音区

- **E7 以上仍时好时坏**，E7/F7 偶尔能测
- 根因：E7 的 tau≈17，相邻整数 lag 差 **105 音分**，逼近算法极限
- 已做的改进：差分曲线插值、缓冲翻倍、八度纠错
- **效果待用户复测**

### 低音区

- **G1 往左时好时坏**，且仍会被判为「多个音」
- 已做的改进：自适应网格、分析窗口按基频、低音门槛分层
- **效果待用户复测**

### 延迟权衡（需用户判断）

- 缓冲从 8192 翻倍到 **16384**，延迟约 372ms
- 低音更准，但可能感觉「反应慢半拍」
- 如果用户觉得迟钝，可考虑**高音区单独用短缓冲**

### 低音双音

- 门槛提到 0.75 能防误报
- 但用户**同度校准低音弦**时可能反而检不出
- 需确认用户是否有这个使用场景

## 7. 待实现功能

用户已确认要做的：

1. **常用速度**：已完成（见 4）
2. **每乐器独立标准音高**：已完成（见 4）
3. **按乐器类型优化检测参数**：已完成框架，**参数待真机校准**

用户提过但未开始的：

- 专业调律方向：拉伸曲线、泛音分析（参考 TuneLab 的做法）

## 8. 工作区里的两个 APK（2026-11-10 新增）

用户放了两个自己写的 Android 安装包，要求分析能否修改：

| 文件 | 包名 | 情况 |
|---|---|---|
| `调音大师.apk.1.1` | `com.lipuzhisheng.pianotuner` | 13.17MB，**有 SecShell 加固**，dex 只有 14 个壳类，业务代码被加密 |
| `钢琴调音.apk.1.1` | `com.realtimespecialties.tunelab` | 1.04MB，**无加固**，623 个类可反编译 |

### 已完成的 APK 分析

- 已用 Python 写出 DEX 解析器，能读类名、方法、字符串
- 钢琴调音核心类：`FFTLib`（音高）、`EdPartials`（泛音）、
  `CustomStretch`/`DCurveV`/`TCurveV`（拉伸曲线）、`Overpull`（过拉）、
  `IHRes`（非谐性系数）
- 调音大师有优量汇广告、SecShell 加固

### 待用户确认的问题（重要）

1. **这两个是谁写的？** 用户说「是我写的」，但包名是
   `com.lipuzhisheng.pianotuner` 和 `com.realtimespecialties.tunelab`，
   且有商业加固和广告
2. **有没有原始源码工程？** 有源码就不用反编译
3. **想改哪个包、改什么？**

### 反编译所需的工具（本机都没有）

- `jadx`（反编译成 Java）
- `apktool`（拆包回包）
- `Android SDK + JDK`（重新编译签名）
- 合计约 1.5GB，网络可下载

**调音大师需要先脱壳**才能看到业务代码，难度大。

## 9. 已知风险与注意事项

- 不要声称任何版本已在真机验证，除非真的装过并确认
- 不要复用已发布的版本号或构建标记
- 旁白相关改动必须真机验证，模拟器和静态检查都不能代替
- **本机没有 Xcode 和 Swift**，只能靠 GitHub Actions 构建
- 本机也没有 Java/Android SDK，Android 相关工作需要先下载工具
- 新增 Swift 文件后 XcodeGen 会自动纳入，不需要改 `project.yml` 的 sources
- `AccessibilityTraits` 没有 `.isAdjustable`；可调整控件只靠
  `.accessibilityAdjustableAction`，不要加那个 trait
- **Swift 类型推断容易超时**：视图 body 太长或 `onChange` 链太长会编译失败，
  需要拆成独立属性
- **XCTAssertEqual 的 `accuracy` 是绝对值不是音分**（曾经因此测试失败）
- 不要用 `let` 声明之后要重新赋值的变量
- 密钥、Apple ID、验证码、配对文件内容不要写进任何文件或聊天

## 10. 下一步建议

1. **先让用户在真机复测 0.6.11 的高低音表现**
   - E7 以上是否能稳定识别
   - G1 附近是否还误报多音
   - 延迟是否可接受
2. 根据反馈校准 `DetectionProfile` 的参数
3. 确认 APK 的来龙去脉，再决定是否反编译
4. 如果用户确认要借鉴 TuneLab：分析 `FFTLib` 的算法思路，
   应用到 iOS 项目的 `PitchDetector`

## 11. 新会话开场提示

```text
请先完整阅读 docs/technical/handoff-2026-11-10-current.md，然后继续处理这个项目。

当前分支 fix/tuner-lifecycle，v0.6.11 已发布。
工作区有两个 APK 待分析（用户说是自己写的 Android 应用）。

下一步：
1. 让用户复测 0.6.11 的高低音检测效果，据此校准 DetectionProfile 参数
2. 确认两个 APK 的来源和修改需求，再决定是否反编译

注意：Git 直连经常失败，推送要用 API 备用方案；
CI 必须用 macos-15，不能用 macos-14；
不要声称已真机验证；每发新版本都要换版本号和构建标记。
```
