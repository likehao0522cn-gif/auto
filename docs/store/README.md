# SideStore / AltStore 更新源

发布标签形如 `v0.5.0` 时，iOS CI 会构建未签名 IPA，并创建 GitHub Release，上传以下文件：

- `TuneMetronome.ipa`
- `source.json`
- `icon.png`

SideStore/AltStore 源地址：

```text
https://github.com/likehao0522cn-gif/auto/releases/latest/download/source.json
```

## 使用步骤

1. 第一次必须在电脑上通过 USB 安装 SideStore 本体并完成配对。
2. 在 iPhone 上打开 SideStore，添加上面的源地址。
3. 从源中安装“调音节拍器（测试）”。
4. 以后发布新版本时，在 SideStore 的更新页刷新并更新即可，不需要数据线。

SideStore 使用免费 Apple ID 签名时，应用通常需要每 7 天续签一次。iOS 26.6.2 上的 SideStore 兼容性需要真机确认。
