# Coding Tools

> macOS 开发者工具中心：可信安装源 + 教程知识库 + 工具启动器 + 环境检测 + 自动更新。

Coding Tools 把 Homebrew、mise、官方安装包、官方文档和精选教程整合到一个签名化的目录中，帮助开发者安全安装、启动和持续更新开发工具。

> 当前源码版本：v1.5.6（build 29）；最近公开 Release 为 v1.5.6（build 29）。应用更新只通过「检查更新」按钮触发，找到新版本后退出、静默安装并重新打开。PKG 仍未用 Developer ID 签名，公证未做。

英文入口见 [`README.md`](./README.md)。

## 界面、更新、反馈与隐私

- 四个标签保持 **首页 / 工具 / 内容 / 设置**。字体、间距、颜色和表面使用同一套令牌。工具卡片没有渐变底、重阴影或悬停缩放。
- 工具卡片、详情、安装弹窗和菜单栏使用同一套展示状态映射。缺少最新版本查询不会显示「已是最新」；探测失败不会显示「未安装」。
- **应用更新**（Sparkle）和 **工具更新** 文案与状态分离。设置页和菜单栏始终提供「检查更新」，不会自动检查或后台安装。点按钮后若有新版本，会下载、退出软件、静默安装，然后重新打开。
- 设置 → 支持与反馈：报告问题、功能建议、项目主页、帮助、复制诊断摘要。Issue 只预填应用版本、构建号、macOS 版本和 CPU 架构。日志和诊断不会自动上传；复制前会先显示预览。
- 首次启动会说明四个标签、可信安装源，以及应用更新和工具更新的区别。设置 → 诊断可查看目录缓存、最近崩溃、打开崩溃文件夹，并按用户操作导出/导入收藏、最近使用、主题、语言和更新偏好。便携文件不含用户主目录、Token 或日志。
- 外观支持浅色、深色和跟随系统。从固定浅色/深色切回跟随系统时，会清除已写入的 App/窗口外观，后续系统外观变化会生效。
- 设置 → **本地环境检查** 覆盖七个 Agent CLI：Claude Code、Codex、Gemini CLI、Grok Build、OpenCode、OpenClaw、Hermes。检测只枚举已知目录，不会修改 PATH。每张卡显示当前版本、最新稳定版、来源/渠道和只读冲突列表。安装/更新按钮只走目录里的可信强类型选项；Hermes 以及只有远程脚本的 Grok 只显示官方说明，不执行安装脚本。「全部升级」先预览、再确认，然后逐个工具顺序执行。需要报问题时，从设置复制脱敏诊断。

本项工作的证据：`local_tests` 来自框架测试 scheme。`runtime_verified`、`remote_release`、`update_verified`、`user_installed` 在对应门禁实际跑过之前保持 `not_run`。

## 快速开始

```bash
brew install tuist
cd Apps/Mac && tuist install && tuist generate
open CodingTools.xcworkspace
./scripts/run-tests.sh
```

纯文档贡献不要求在本地构建或打开 macOS App。不要提交 `.app`、`build/`、DerivedData、临时截图、用户配置、原始日志或凭证。

## 许可证

[Apache License 2.0](./LICENSE)。
