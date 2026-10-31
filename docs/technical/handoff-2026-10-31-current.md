# 交接文档（2026-10-31 当前）

> 开新会话时，请先完整阅读本文件，再继续操作。

## 1. 项目与用户目标

项目路径：`D:\调音节拍器`

这是一个面向盲人和低视力用户的 iOS SwiftUI 调音节拍器。当前用户最关心：

- 所有固定可调数值都要有清楚、可触达的“减 / 加”按钮。
- 节拍器速度既可以加减，也可以直接输入数字。
- 击拍定速时，每敲一拍都应及时刷新速度，而不是只测一次。
- SideStore 以后能无线刷新和更新，不必每次插数据线。
- 真机 VoiceOver 能正确朗读按钮名称、数值和状态。

## 2. 当前分支与提交状态

- 分支：`fix/tuner-lifecycle`
- 本地 HEAD：`f34939b Add-explicit-plus-minus-adjustment-buttons`
- 远端跟踪分支：`origin/fix/tuner-lifecycle` = `3d3f366`
- 本地比远端多 **1 个提交**（`f34939b`），**尚未推送**。
- 工作区当前没有未提交的代码改动。
- 用户明确要求：先不要上传这批新改动。

### 已推送到远端的发布状态

- Release：`v0.5.0`，GitHub 标记为 Latest。
- Release 页面：`https://github.com/likehao0522cn-gif/auto/releases/tag/v0.5.0`
- SideStore 源地址：
  - `https://github.com/likehao0522cn-gif/auto/releases/latest/download/source.json`
- 发布源自动校验脚本已在远端 CI 中启用：
  - `scripts/verify-store-release.mjs`
- 已确认 v0.5.0 的三个 Release 资产、公开源地址、IPA 大小与 SHA-256 正确。

## 3. 真机安装状态

- 2026-10-30 已用 Sideloadly 把 **0.5.0** 覆盖安装到 iPhone。
- 手机应用列表确认：
  - 显示名：调音节拍器（测试）
  - 版本：0.5.0
  - 构建号：5
- 这台手机当前使用的是 Sideloadly 免费签名，通常 7 天后需要续签。
- **在 SideStore 登录和刷新成功之前，更新 0.5.0 仍然需要连接数据线。**
- 不要说“无线更新已经完成”。

## 4. SideStore 卡点与下一步

### 当前状态

- SideStore `0.7.0-20260911.328+6032424a` 已通过 iloader 安装到手机。
- 配对文件已由 iloader 放入。
- SideStore 登录 Apple ID 时出现：
  - `Failed to Sign In`
  - `-80045`
  - 或 `kCFErrorDomainCFNetwork error -1005`
- 这是 SideStore 0.7.0 已知的 Anisette / Apple 登录兼容问题，不是用户密码错误。

### 社区验证过的修复步骤

1. 打开 SideStore 底部 **Settings**。
2. 进入 **User Customizations**。
3. 关闭 **On-Device Anisette**，选择 **Restart Now**。
4. 重开 SideStore 后，进入 **Anisette Client Configuration**。
5. 在 **Anisette Servers** 中选择 **SideStore (New)**。
6. 下滑到页面底部，关闭 **Enable Auto Rotation**。
7. 在同一配置页找到 **Remote server sync**，点 **Fetch**，再点 **Save as Overrides**。
8. 返回 **User Customizations**，点 **Reset adi.pb**，确认退出账号并清除旧 Anisette 数据。
9. 再回到登录页，重新登录 Apple ID，输入手机收到的新验证码。
10. 登录成功后，刷新 SideStore 自身一次，再加入项目源。

### 用户已完成

- 已关闭 **On-Device Anisette**。
- 已按提示重启 SideStore。
- 尚未完成后面的服务器选择、Fetch / Save as Overrides 和 Reset adi.pb。

### 重要限制

- 当前手机可能不在电脑旁，用户说连接手机得明天。
- 在没有确认 SideStore 登录成功、源能刷新、应用能更新之前，不要宣称无线更新已解决。
- 官方安装文档：`https://docs.sidestore.io/docs/installation/install`

## 5. 已在本地完成的功能

提交 `f34939b` 包含：

- 新增 `App/Sources/AdjustableValueRow.swift`。
- 语音语速：大号“减 / 加”按钮。
- 语音音调：大号“减 / 加”按钮。
- 语音音量：大号“减 / 加”按钮。
- 标准音高：大号“减 / 加”按钮。
- 节拍器速度：大号“减 / 加”按钮。
- 中间显示当前值。
- 到达边界时对应按钮自动禁用。
- 每个按钮有独立中文 VoiceOver 标签。
- 旁白开启时，每次调整后播报新数值。

### 验证状态

- `node scripts/check_braces.js` 已通过。
- `git diff --check` 已通过。
- 尚未运行 XCTest。
- 尚未运行 Xcode 构建。
- 尚未推送，因此 GitHub Actions 尚未构建这批改动。
- 尚未在真机验证新按钮的布局和旁白焦点。

## 6. 用户最新提出、尚未实现的需求

这两项还没写进代码，下一步应优先完成：

### 6.1 节拍器速度允许手动输入

目标：

- 在节拍器页面提供一个数字输入框。
- 输入范围 **20–300** 每分钟拍数。
- 提供明确的中文“应用输入的速度”按钮。
- 输入非法、为空或超出范围时，显示中文错误提示。
- 应用成功后更新 `metronome.configuration.bpm`，并让旁白播报新速度。
- 保留现有大号“减 / 加”按钮。

建议实现位置：

- `App/Sources/MetronomeView.swift`
- 可使用 `TextField` + `.keyboardType(.numberPad)` + 本地 `@State` 字符串。
- 可调用已有的 `metronome.setBPM(_:)`，但它当前只设置值、不播报；需要增加一个用户操作后的播报方法，或在视图里调用 `SpeechFeedback`。

### 6.2 击拍定速持续刷新

用户原话：

> 激拍定速的时候，希望可以及时刷新速度，而不是只测一次

当前实现：

- `TapTempoViewModel.tap` 只有在超过初始拍数后才设置一次 `bpm`。
- 之后每次敲击会更新 `tapCount` 和估算器，但不会重新赋值 `bpm`。
- 因此界面上的速度不会随后续拍点持续刷新。

目标：

- 每敲一拍，只要估算器能算出速度，就立即更新 `bpm`。
- 保留 3 秒无新拍点后自动重置。
- 旁白不要每一拍都重复完整句子，避免吵；可在结果变化时用短提示或只更新可访问值，具体策略需要真机验证。
- 保留“应用到节拍器”按钮，测速结果不应自动覆盖节拍器速度。

建议修改：

- `App/Sources/TapTempoViewModel.swift`
- 在 `tap` 中，每次 `estimator.record` 后计算 `let newBPM = estimator.bpm`，并更新 `bpm = newBPM`。
- 把 `announcedInitialResult` 改成只在第一次或明显变化时播报。
- 现有 `TapTempoEstimator` 位于 `Core/Sources/MetronomeTiming.swift`，每拍更新是支持的。

## 7. 下一步建议顺序

1. 先实现“节拍器速度手动输入”。
2. 再修复“击拍定速每拍刷新”。
3. 运行本地静态检查。
4. 推送后等待 GitHub Actions 构建。
5. 用 Sideloadly 安装新构建做真机验证。
6. 回到 SideStore，完成 Anisette 修复和无线刷新验证。
7. 最后再决定是否发布新的 Release。

## 8. 已知风险与不要踩的坑

- 不要把 Apple ID 密码、验证码、token 或配对文件内容写入任何文件、提交或聊天。
- 不要在 SideStore 成功刷新前承诺无线更新已经可用。
- 不要把 0.5.0 的旧安装结果当作新代码已验证。
- 不要误装旧的 `TuneMetronome-latest-a803748.ipa` 或其他旧包。
- 当前本地新增提交尚未推送；不要在新会话里直接假设远端已有加减按钮。
- 网络访问 GitHub Release 资产偶尔超时，可用 `gh-proxy.com` 作为临时下载镜像，但正式发布仍以 GitHub Release 为准。

## 9. 新会话开场提示

可直接对下一位助手说：

```text
请先完整阅读 docs/technical/handoff-2026-10-31-current.md，然后继续处理这个项目。
当前本地 HEAD 是 f34939b，已提交但未推送；请保留这些改动。
下一步优先实现两个需求：节拍器速度支持手动输入 20–300；击拍定速每次敲击都要及时刷新速度，而不是只测一次。
之后再继续 SideStore 的 Anisette 修复和无线刷新验证。当前手机已安装 0.5.0，但不要宣称无线更新已经完成。
不要把 Apple ID 密码、验证码或配对文件内容写入任何文件或聊天。
```