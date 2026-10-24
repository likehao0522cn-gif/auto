# 调音节拍器

面向盲人和低视力用户的 iPhone 听觉优先调音与节拍器应用。

## 当前状态

- 功能规格：`docs/product/functional-spec.md`
- 技术架构：`docs/technical/architecture.md`
- 实现状态：`docs/technical/implementation-status.md`
- 术语表：`GLOSSARY.md`
- 设计决策：`docs/adr/`
- iOS 工程：由 `project.yml` 通过 XcodeGen 生成
- 自动化测试：GitHub Actions macOS runner

当前代码是待云端编译验证的 MVP 骨架，包含：

- 调音器页面和音高检测基础实现
- 钢琴目标音选择
- 节拍器页面和基础点击声
- 测速区域
- VoiceOver 标签和焦点顺序
- 核心音高、预设和节拍时序测试

## 本地生成 Xcode 工程

需要在 macOS 上安装 Xcode 和 XcodeGen：

```bash
brew install xcodegen
xcodegen generate
open TuneMetronome.xcodeproj
```

## 云端测试

推送代码到 GitHub 后，`iOS CI` 工作流会：

1. 安装 XcodeGen
2. 生成 `.xcodeproj`
3. 在 macOS runner 上选择可用 iPhone 模拟器
4. 运行单元测试

真机麦克风、VoiceOver 语音、触觉和后台节拍器仍需要 TestFlight 真机验收。


