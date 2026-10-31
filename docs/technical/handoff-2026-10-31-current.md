# 交接文档（2026-10-31 当前）

> 新会话请先读本文件。`handoff-2026-10-30-current.md` 仍包含发布与安装背景，但部分状态已过时。

## 1. 当前目标

- 继续完善无障碍调音节拍器。
- 解决 SideStore 无线刷新，避免以后每次更新都插数据线。
- 验证最新测试版的 VoiceOver、语音设置和测速单击打拍。

## 2. 已完成的发布与真机安装

- 分支：`fix/tuner-lifecycle`
- Release：`v0.5.0`，Latest，发布源校验通过。
- SideStore 源地址：
  - `https://github.com/likehao0522cn-gif/auto/releases/latest/download/source.json`
- 2026-10-30 已用 Sideloadly 把 0.5.0 安装到 iPhone。
- 手机应用列表确认：
  - 显示名：调音节拍器（测试）
  - 版本：0.5.0
  - 构建号：5
- 当前这台手机上的 0.5.0 是 Sideloadly 签名版本，免费 Apple ID 通常 7 天后需要续签。

## 3. SideStore 状态

- SideStore `0.7.0-20260911.328+6032424a` 已通过 iloader 安装到手机。
- 配对文件已由 iloader 放入。
- SideStore 的 Apple ID 登录报 `-80045 / -1005`。
- 社区验证过的临时修复步骤：
  1. Settings → User Customizations。
  2. 关闭 On-Device Anisette，选择 Restart Now。
  3. 进入 Anisette Client Configuration。
  4. 选择 SideStore (New) 服务器。
  5. 关闭 Enable Auto Rotation。
  6. 进入 Anisette Client Configuration → Remote server sync，点 Fetch，然后 Save as Overrides。
  7. 回到 User Customizations，点 Reset adi.pb。
  8. 重新登录 Apple ID。
- 用户已完成第 1 步并重启 SideStore；第 2 步之后尚未完成。
- 手机当前可能不在电脑旁，下一步需要用户回来说“继续无线更新”。

### 重要限制

- 在 SideStore 登录和刷新真正成功前，不能宣称已经实现无线更新。
- 当前更新 0.5.0 仍然需要数据线。
- SideStore 官方文档：`https://docs.sidestore.io/docs/installation/install`

## 4. 2026-10-31 新增的软件改动

新增并接入：

- `App/Sources/AdjustableValueRow.swift`
- `App/Sources/SettingsViews.swift`
- `App/Sources/MetronomeView.swift`

改动内容：

- 语音语速、语音音调、语音音量、标准音高、节拍器速度都显示大号“减 / 加”按钮。
- 中间显示当前值。
- 加减按钮有独立中文 VoiceOver 标签。
- 到达上下限时对应按钮自动禁用。
- VoiceOver 开启时，每次调整后播报新的数值。

状态：

- 本地静态括号检查通过。
- 尚未运行 XCTest、Xcode 构建或真机 VoiceOver 验证。
- 尚未推送或上传。
- 下一步需要推送后在 GitHub Actions 构建，再安装到手机验证。

## 5. 已知风险

- 不要把 Apple ID 密码、验证码、token 或配对文件内容写入文件/提交/聊天。
- 不要在 SideStore 成功刷新前承诺无线更新已经可用。
- 不要用旧版 0.3.0/0.4.0 验证 0.5.0 的 VoiceOver 和测速问题。
- GitHub Release 资产在当前网络偶尔超时，可用 `gh-proxy.com` 镜像先获取源文件，但正式源仍以 GitHub Release 为准。
- Sideloadly 每次安装前要确认 IPA 名称是 `TuneMetronome-v0.5.0.ipa`，不要误装旧包。

## 6. 下次开场提示

```text
请先完整阅读 docs/technical/handoff-2026-10-31-current.md，然后继续。
优先继续 SideStore 的 Anisette 修复和无线刷新验证；当前已安装 0.5.0，尚未确认 SideStore 登录成功。
另外，2026-10-31 的本地代码改动尚未推送：语音语速、音调、音量、标准音高和节拍器速度已改为大号加减按钮，需要构建和真机验证。
```