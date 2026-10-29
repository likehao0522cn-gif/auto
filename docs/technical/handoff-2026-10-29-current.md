# 交接文档（2026-10-29 当前）

> 新会话请先完整阅读本文件，再继续操作。不要只看旧文件 `handoff-2026-10-29.md`，那份已经过时。

## 1. 项目与用户目标

项目路径：`D:\调音节拍器`

项目是 iOS SwiftUI 调音节拍器，面向盲人和低视力用户。当前用户最关心：

- 真机 VoiceOver 能否正确朗读按钮名称，而不是只读“按钮”。
- 界面是否全部为中文。
- 能否调节应用语音的语速、音调和音量。
- 测速页能否在旁白开启或关闭时都单指单击打拍。
- 以后能否不插数据线直接更新测试版。

## 2. 当前分支与提交状态

- 分支：`fix/tuner-lifecycle`
- 本地 HEAD：`aa2b30a Publish-SideStore-update-source`，以及包含本文件的交接提交。
- 远端 `origin/fix/tuner-lifecycle`：`3499257 Add-speech-volume-and-large-tap-tempo-pad`
- 本地比远端多 2 个提交：`aa2b30a` 和交接文档提交。
- 这两个提交都已成功本地提交，但 `git push` 多次因 GitHub HTTPS 连接重置失败，尚未推送。
- 工作区只剩一个未跟踪文件：`sideloadlydaemon.log`。不要提交它。
- 远端仓库：`https://github.com/likehao0522cn-gif/auto.git`
- 仓库是 public，GitHub Pages 未启用。当前无数据线更新方案使用 GitHub Release 资产作为源，不依赖 Pages。

`aa2b30a` 新增：

- `.github/workflows/ios.yml` 的 Release 发布步骤。
- `scripts/generate_store_source.py`。
- `docs/store/icon.png`。
- `docs/store/README.md`。

## 3. 已验证的最新构建

最新成功 CI：

- Run：`40831091402`
- 提交：`3499257`
- 结论：成功
- `Package unsigned IPA` 和 `Upload unsigned IPA` 均通过。
- URL：`https://github.com/likehao0522cn-gif/auto/actions/runs/40831091402`

本地已下载并校验的 0.5.0 IPA：

```text
D:\调音节拍器\artifacts\TuneMetronome-latest-3499257.ipa
```

- SHA-256：`1D64981A37F0270917EAD3C8CD729DAF9A97C6BEAA82D68937FCA58D73553310`
- 大小：`522638` 字节
- 显示名：`调音节拍器（测试）`
- 版本：`0.5.0`
- 构建号：`5`
- Bundle ID：`com.shm06.TuneMetronome`
- 开发语言：`zh-Hans`
- 主二进制已确认包含：`SPEECH_AND_TAP_PAD_2026_10_29`、“语音和测速测试版”、“语音语速”、“测速拍点区域”。

注意：0.5.0 还没有在 iPhone 上覆盖安装验证；真机上次安装记录是 0.4.0。

## 4. 已完成的功能

### 4.1 中文与 VoiceOver 标签

已修改：

- 首页、调音器、节拍器、测速、选择器、设置页、帮助页的主要控件增加明确中文标签。
- 调音器和节拍器移除了 `AccessibilityFocusState`、自定义转子和 `accessibilityAction`，恢复自然焦点顺序。
- 主要按钮统一使用 `Text(verbatim:)`、`accessibilityElement(children: .ignore)` 和显式标签。
- 可见英文中文化：BPM → 每分钟拍数，Hz → 赫兹，VoiceOver → 旁白，English → 英语。
- `project.yml` 已设置开发语言 `zh-Hans`、中文麦克风权限说明、中文显示名。

### 4.2 语音设置

相关文件：

- `App/Sources/SpeechSettings.swift`
- `App/Sources/SpeechFeedback.swift`
- `App/Sources/AppModel.swift`
- `App/Sources/SettingsViews.swift`

功能：

- 设置首页“声音”下直接有“语音语速、音调和音量”入口。
- 支持三种播报方式：
  - 应用语音
  - 自动：旁白开启时使用旁白
  - 旁白播报
- 应用语音支持语速、音调和音量。
- 支持“试听当前语音”。
- 设置持久化到 `UserDefaults`。
- 应用语音默认值：语速 `0.48`、音调 `1.0`、音量 `1.0`。
- 旁白播报模式下，应用使用 `UIAccessibility.post(.announcement)`，并使用估算时长恢复调音器内部状态；这不是系统精确的“朗读完成回调”，真机需要重点验证。

### 4.3 测速页大区域单击打拍

相关文件：

- `App/Sources/TapTempoView.swift`
- `App/Sources/TapTempoPad.swift`

设计：

- 测速页下方是大块测速区域。
- 使用 `UIViewRepresentable` 包一个 `UIView`，自身响应单击。
- 关闭旁白时，直接单击该区域记录一拍。
- 开启旁白时，该区域带有 `.allowsDirectInteraction`，期望可直接单指单击，而不是要求双击。
- 同时保留“记录一拍”按钮作为替代操作。
- 该交互尚未在 iPhone 真机验证，必须验证旁白开启和关闭两种状态。

### 4.4 无数据线更新方案（已完成代码，未部署）

目标是 SideStore/AltStore 源：

```text
https://github.com/likehao0522cn-gif/auto/releases/latest/download/source.json
```

计划流程：

1. 推送包含 Release 发布步骤的提交。
2. 打标签 `v0.5.0` 并推送。
3. GitHub Actions 构建 IPA。
4. 自动创建 GitHub Release，上传：
   - `TuneMetronome.ipa`
   - `source.json`
   - `icon.png`
5. iPhone 首次通过 USB 安装 SideStore 本体并配对。
6. SideStore 添加上述源，安装/更新应用。
7. 后续只在 SideStore 中刷新和更新，不再插数据线。

重要限制：

- SideStore/AltStore 本体第一次安装仍需要一次 USB 配对，这一点无法靠免费 Apple ID 完全绕过。
- 如果用户完全拒绝任何一次 USB，则只能改用 TestFlight（需要付费 Apple Developer Program），或继续使用 Sideloadly 有线安装。
- 免费 Apple ID 通常每 7 天需要续签。
- iOS 26.6.2 与 SideStore 的兼容性尚未真机确认。

## 5. 需要下一步做的事（按顺序）

### 第一步：推送本地两个未推送提交

先重试：

```powershell
git push origin fix/tuner-lifecycle
```

如果 GitHub HTTPS 仍重置，可用 GitHub API 创建树和引用，或在新会话中继续重试。不要把本地提交丢掉。

### 第二步：创建并推送 `v0.5.0` 标签

推送成功后：

```powershell
git tag v0.5.0
git push origin v0.5.0
```

标签会触发 `.github/workflows/ios.yml` 中的 Release 步骤。

### 第三步：检查 Release 资产

检查：

- GitHub Release `v0.5.0` 存在且标记为 Latest。
- 资产名准确为 `TuneMetronome.ipa`、`source.json`、`icon.png`。
- `source.json` 中 version 为 `0.5.0`，size 与实际 IPA 大小一致。
- `downloadURL` 可以公开下载。
- 源地址可以公开访问：

```text
https://github.com/likehao0522cn-gif/auto/releases/latest/download/source.json
```

### 第四步：首次 SideStore 安装

使用电脑和 USB 安装 SideStore 本体，完成配对。然后：

1. iPhone 打开 SideStore。
2. 添加源地址。
3. 安装“调音节拍器（测试）”。
4. 以后从 SideStore 更新。

### 第五步：真机验证 0.5.0

重点检查：

- 首页显示“语音和测速测试版 2026-10-29”。
- 设置 → 声音 → “语音语速、音调和音量”能进入。
- 语速、音调、音量 Stepper 能被旁白正确朗读和调整。
- 试听语音正常。
- 旁白播报模式能播放。
- 测速页下方大区域在旁白关闭时可单击打拍。
- 开启旁白时可直接触摸该区域单击打拍。
- 记录拍数、BPM、应用到节拍器均正常。

## 6. 已知风险与不要重复踩的坑

- 不要因为 CI 成功就认为真机安装的是最新代码；必须检查 IPA 的 `Info.plist` 和二进制标记。
- 不要在旧 IPA 上继续验证 VoiceOver。
- 不要把 `sideloadlydaemon.log` 提交进 Git。
- 不要把 Apple ID 密码、验证码或 token 写入文档、提交或发给任何人。
- 不要假设 `UIAccessibility.announcement` 能精确回调朗读结束；当前语音完成状态是估算的。
- 不要在没有真机验证的情况下宣称“大区域单击打拍”在旁白模式下已经成功。
- 不要直接把 GitHub Pages 当作已启用；当前方案使用 Release 资产源。
- `docs/store/source.json` 是发布时生成的，不要把它误认为已经存在于仓库。

## 7. 关键路径

```text
D:\调音节拍器\App\Sources\SpeechSettings.swift
D:\调音节拍器\App\Sources\SpeechFeedback.swift
D:\调音节拍器\App\Sources\SettingsViews.swift
D:\调音节拍器\App\Sources\TapTempoView.swift
D:\调音节拍器\App\Sources\TapTempoPad.swift
D:\调音节拍器\.github\workflows\ios.yml
D:\调音节拍器\scripts\generate_store_source.py
D:\调音节拍器\docs\store\README.md
D:\调音节拍器\docs\store\icon.png
D:\调音节拍器\artifacts\TuneMetronome-latest-3499257.ipa
```

## 8. 新会话开场提示词

可直接对下一位助手说：

```text
请先完整阅读 docs/technical/handoff-2026-10-29-current.md，然后继续处理这个项目。
当前目标是：先推送本地未推送提交（含 aa2b30a 和交接文档），创建 v0.5.0 Release 和 SideStore 源；再指导我做一次 USB SideStore 首次配对，之后实现无线更新。不要让我反复插拔数据线。需要选择 IPA 或点击 Sideloadly Start 时，直接操作。不要把任何 Apple ID 密码、验证码或 token 写入文件。
```