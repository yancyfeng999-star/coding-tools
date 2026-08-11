# Coding Tools · 更新日志

> 所有显著变更都记录在这里。格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

### Changed

- 暂未发布

## [1.2.1] - 2026-08-11

### Changed

- v1.2.1 文档清理：CHANGELOG 去重 + release.sh Python 段修复（每次发版不再追加重复块）。

## [1.2.0] - 2026-08-11

### Changed

- SettingsView：新增「关于」卡片（app icon gradient + 名字 + 副标题 + 版本/最低系统/架构 + GitHub 链接 + Sparkle/Tuist/SwiftUI 致谢）。
- ToastCenter：顶部 banner 系统（info / success / warning / error），支持自动消失 + 重试 + 关闭按钮；`AppState.loadCatalogIfNeeded` / `loadContentIfNeeded` 失败时自动 emit。
- Localizable.xcstrings：补齐 5 种语言（日 / 韩 / 法 / 德 / 西）+ 452 条翻译，覆盖所有现有 key；新增 11 个 key（`settings.section.about` / `toast.*` / `settings.about.*`）。

## [1.1.0] - 2026-08-11

### Changed

- Content 教程：内置 12 条精选条目（仅元数据 + 原文链接，不下载视频、不二次分发）。
- Home 可更新区接 Sparkle：在首页露出当前版本 / 最新版本 / 下载进度。
- 菜单栏快捷：检查更新入口放进 menu bar。
- ToolCard 视觉升级：风险标 / tool id / 进度环 / hover 反馈。

## [1.0.9] - 2026-08-10

### Changed

- 端到端演练：从 v1.0.8 自动升到 v1.0.9。
- appcast：`xml:lang` 重复段修复，最终只走单一 sed。

## [1.0.8] - 2026-08-10

### Changed

- appcast：`xml:lang` 处理收敛到一处 sed，去掉前序重复 sed。

## [1.0.7] - 2026-08-10

### Changed

- appcast：zip 与 pkg 两条 `<enclosure>` 都带上 `xml:lang`。

## [1.0.6] - 2026-08-10

### Changed

- appcast：两个 `<enclosure>` 都补 `xml:lang`（Sparkle 2.x 强要求）。

## [1.0.5] - 2026-08-10

### Changed

- appcast：`xml:lang` 全覆盖。

## [1.0.4] - 2026-08-10

### Changed

- appcast：补 `<enclosure xml:lang="…">`（Sparkle 2.x 强要求）。

## [1.0.3] - 2026-08-10

### Changed

- appcast：补 `xml:lang` 属性（Sparkle 2.x 强要求）；端到端跑通静默更新链。

## [1.0.2] - 2026-08-10

### Changed

- 静默更新：自定义 `SPUUserDriver`，不再弹窗；Settings 实时显示本地版本、最新版本、下载进度（0–100% + 字节数）、解压与安装状态。
- 启动后立即拉 appcast。
- PKG 同步上架，appcast 同时挂 zip + pkg。

## [1.0.1] - 2026-08-10

### Changed

- 安装按钮显示修复（Localization cache bug + 迁移到 Xcode String Catalog `.xcstrings`）。
- 新增 PKG 分发（`pkgbuild` 未签名）。
- Sparkle appcast 同时挂 zip + pkg。

## [1.0.0] - 2026-08-10

### Added

- 首次发布：7 个 AI CLI 工具（npm-global 安装）+ 3 个传统 CLI 工具。
- 菜单栏入口（`MenuBarExtra`）+ SwiftUI 主窗口。
- Sparkle 2 自动静默更新：`SUFeedURL` 指向 GitHub Releases 的 appcast，`SUMinimumAutoupdateVersion` 0.5.0，EdDSA 公钥已配置。
- Settings 面板含「检查更新」按钮。
- 本地签名（ad-hoc）+ EdDSA appcast 签名。
- 发版脚本端到端：bump → tests → build → package（DMG + ZIP）→ `sign_update` → `generate_appcast` → commit + tag + push → `gh release create`。

### Changed

- Sandbox 在 dev 模式下临时关闭，方便 `npm-global` 路径调用。

## [0.0.0] - 2026-08-09

### Added

- 项目初始化：完整开发计划文档 `CODING_TOOLS_MACOS_DEVELOPMENT_PLAN.md`、14 个 Tuist 模块占位、Catalog 子目录（tools / content / schemas / revocations）、基线产品文档（README / PRODUCT / PROJECT_STATUS / AGENTS）、产品合同 `docs/PRODUCT_SPEC.md`、安全威胁模型 `docs/SECURITY_MODEL.md`、目录 JSON Schema `docs/CATALOG_SCHEMA.md`、8 个 Stage 0 工具验证表 `docs/STAGE0_TOOLS.md`、测试矩阵 `docs/QA_MATRIX.md`、发版流程 `docs/RELEASE_WORKFLOW.md`、Agent 发版详细步骤 `docs/AGENT_RELEASE_WORKFLOW.md`、多代理协作文档总线 `.multi-agent-collaboration/`。

[Unreleased]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.9...v1.1.0
[1.0.9]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/yancyfeng999-star/coding-tools/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/yancyfeng999-star/coding-tools/releases/tag/v1.0.0
[0.0.0]: https://github.com/yancyfeng999-star/coding-tools/releases/tag/v0.0.0
