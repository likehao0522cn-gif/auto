# 交接文档（2026-10-30 当前）

> 新会话请先完整阅读本文件。`handoff-2026-10-29-current.md` 和更早的交接文档已经过时。

## 1. 项目与用户目标

项目路径：`D:\调音节拍器`

这是一个面向盲人和低视力用户的 iOS SwiftUI 调音节拍器。用户最关心：

- 真机 VoiceOver 是否朗读明确的中文控件名称，而不是只读“按钮”。
- 界面是否全部为中文。
- 应用语音的语速、音调和音量能否调节。
- 测速页能否在旁白开启或关闭时都单指单击打拍。
- 以后能否不插数据线直接更新测试版。
- 用户不接受反复插拔数据线；首次安装只应要求一次 USB 连接。

## 2. 分支与发布状态

- 分支：`fix/tuner-lifecycle`
- 上一个已确认提交：`d215579 Add-current-session-handoff`
- 远端同名分支曾成功推送；本次新增的发布校验提交和本交接提交需要再次推送。
- 标签：`v0.5.0`，已推送到远端。
- Release：`v0.5.0`，已发布且为 Latest。
- Release 页面：`https://github.com/likehao0522cn-gif/auto/releases/tag/v0.5.0`
- 标签触发的最新成功 CI：Run `40862124863`
  - `https://github.com/likehao0522cn-gif/auto/actions/runs/40862124863`
- 工作区中的 `sideloadlydaemon.log` 已加入 `.gitignore`，不要提交。

### v0.5.0 Release 资产

- `TuneMetronome.ipa`：522638 字节，SHA-256 `24619c80682f63a399c76ec8d4cdda7ad5cfe1dc37492d607b59fd2a1cdf0b6f`
- `source.json`：1566 字节
- `icon.png`：16628 字节，SHA-256 `2308170cbd5ec1e33be227390e52893f9b6d11f0389c033be35e7e830bb714c2`
- SideStore 源地址：
  - `https://github.com/likehao0522cn-gif/auto/releases/latest/download/source.json`
- 源地址和三个资产已通过实际下载校验。

注意：`artifacts/TuneMetronome-latest-3499257.ipa` 是较早的 CI 构建，SHA-256 为 `1D6498...`。Release 中的 IPA 由标签构建重新生成，以 GitHub Release 资产为准。

## 3. v0.5.0 已完成功能

- 首页、调音器、节拍器、测速、选择器、设置和帮助页的主要控件都有中文 VoiceOver 标签。
- 调音器和节拍器移除了自定义转子和 `AccessibilityFocusState`，恢复自然焦点顺序。
- 设置 → 声音 → “语音语速、音调和音量”可进入应用语音设置。
- 应用语音支持语速、音调、音量和试听。
- 支持应用语音、自动、旁白播报三种播报方式。
- 测速页有独立大区域单击打拍，并保留“记录一拍”按钮。
- 首页显示测试版标记“语音和测速测试版 2026-10-29”。

旁白播报模式的完成状态仍是按文本长度估算，不是系统精确的朗读完成回调，必须真机验证。

## 4. 新增：发布源自动校验

新增文件：

- `scripts/verify-store-release.mjs`
- `.github/workflows/ios.yml` 中的发布后校验步骤
- `docs/store/README.md` 中的校验说明

CI 在标签发布并创建 Release 后会自动检查：

- Release 已发布且为 Latest；
- `TuneMetronome.ipa`、`source.json`、`icon.png` 齐全；
- `source.json` 的版本、大小、Bundle ID 和下载地址正确；
- `releases/latest/download/source.json` 可访问且内容一致；
- 下载后的 IPA 和图标 SHA-256 与 GitHub 资产摘要一致。

本地命令：

```powershell
node scripts/verify-store-release.mjs v0.5.0 likehao0522cn-gif/auto
```

该命令已对 v0.5.0 实际运行通过。

## 5. 下一步：首次 SideStore 安装

用户 2026-10-29 不在电脑旁，安装因此暂停。SideStore 官方文档当前不再推荐先用 Sideloadly 装 SideStore，而是推荐：

1. iPhone 先安装并连接 LocalDevVPN。
2. Windows 安装 iTunes 和官方 iloader。
3. 只用一次 USB 连接 iPhone，解锁并信任电脑。
4. 用 iloader 登录 Apple Account，选择设备，安装 SideStore Stable。
5. iPhone 信任开发者 App；iOS 18 及以上按提示开启开发者模式。
6. 打开 LocalDevVPN，再打开 SideStore，登录同一 Apple Account。
7. 在 SideStore 的“我的 App”里刷新 SideStore 自身，完成初次设置。
8. 添加项目源地址，安装“调音节拍器（测试）”。
9. 以后只在 SideStore 里无线刷新和更新。

官方安装文档：

`https://docs.sidestore.io/docs/installation/install`

### 已准备好的本地文件

- SideStore 官方 IPA（当前 release `0.7.0-alpha`）：
  - `artifacts/sidestore/SideStore-0.7.0-alpha.ipa`
  - 27770821 字节
  - SHA-256 `e334f86e6ceeab2e0d886c07611246533f474bb18838cf13ebc09ed1f0d622b5`
  - 仅作备用；官方流程中由 iloader 安装 SideStore。
- iloader 官方 Windows MSI：
  - `artifacts/iloader/iloader-windows-x64-v2.4.1.msi`
  - 8888320 字节
  - SHA-256 `8bfe528197db1b82f51fbcdb74652f355e7ae025e616e07a10a819d60f7d2691`
- 两个文件都位于被 Git 忽略的 `artifacts/` 目录，不要提交。

### 设备与账户状态

- iPhone 名称：`可爱喵`，系统 iOS 26.6.2，已能在 Sideloadly 中通过 USB 识别。
- 电脑上已有这台设备的 Apple 配对记录，位置在 `C:\ProgramData\Apple\Lockdown\`；不要把内容写入仓库或聊天。
- Sideloadly v0.71.2 和 sideloadlydaemon 已安装，但不再作为首选 SideStore 安装路径。
- 最后一次看到设备上安装的是旧版调音节拍器 `0.3.0`；`0.5.0` 尚未真机安装。
- 免费 Apple Account 的 App ID 额度和 7 天刷新时间会变化，不要写入任何账户邮箱、密码、验证码或 token。
- iOS 26.6.2 与 SideStore 的兼容性仍需真机确认。如果 iloader 无法识别设备，先检查 iTunes、Apple Mobile Device Service 和 Windows USB 驱动，不要反复要求用户插拔。

## 6. 真机验证 0.5.0 清单

安装后重点验证：

- 首页显示“语音和测速测试版 2026-10-29”。
- 设置 → 声音 → “语音语速、音调和音量”能进入。
- 语速、音调、音量 Stepper 能被旁白正确朗读和调整。
- “试听当前语音”正常。
- 旁白播报模式能播放，且不会让调音器状态卡死。
- 测速页在旁白关闭时，大区域单指单击可记录一拍。
- 测速页在旁白开启时，直接触摸大区域单指单击可记录一拍。
- “记录一拍”、BPM 更新、“应用到节拍器”均正常。
- 主要按钮不会被旁白念成“按钮”而没有名称。
- 界面中没有遗留英文（A4、Hz 等约定写法除外）。

真机结果没有确认前，不要宣称这些问题已经修复成功。

## 7. 已知风险与不要踩的坑

- 不要因为 CI 成功就认为真机装的是最新代码；检查 IPA 版本、构建号和二进制标记。
- 不要在旧版 0.3.0 上验证 0.5.0 的旁白和测速问题。
- 不要把 `sideloadlydaemon.log` 提交进 Git。
- 不要把 Apple ID 密码、验证码、配对文件内容或 token 写入文件、提交或发给他人。
- 不要假设 `UIAccessibility.announcement` 能精确回调朗读结束。
- 不要在没有真机验证的情况下宣称旁白模式下大区域单击打拍已经成功。
- GitHub Release 资产下载偶尔会超时；发布源校验脚本已加入重试。
- SideStore 官方流程可能变化；安装前重新查看官方文档。

## 8. 关键路径

```text
D:\调音节拍器\App\Sources\SpeechSettings.swift
D:\调音节拍器\App\Sources\SpeechFeedback.swift
D:\调音节拍器\App\Sources\SettingsViews.swift
D:\调音节拍器\App\Sources\TapTempoView.swift
D:\调音节拍器\App\Sources\TapTempoPad.swift
D:\调音节拍器\scripts\verify-store-release.mjs
D:\调音节拍器\.github\workflows\ios.yml
D:\调音节拍器\docs\store\README.md
D:\调音节拍器\artifacts\sidestore\SideStore-0.7.0-alpha.ipa
D:\调音节拍器\artifacts\iloader\iloader-windows-x64-v2.4.1.msi
```

## 9. 新会话说开词

```text
请先完整阅读 docs/technical/handoff-2026-10-30-current.md，然后继续处理这个项目。
当前目标：我准备插好 iPhone，用一次 USB 完成 SideStore 首次安装和配对，然后添加测试源、安装 0.5.0，并进行真机 VoiceOver、语音设置和测速打拍验证。
请先检查最新提交、CI 和 Release 校验是否通过；需要点击 iloader 或选择安装包时直接操作，但 Apple ID 密码和验证码由我自己输入。不要把账户凭据或配对文件内容写入任何文件或聊天。
```