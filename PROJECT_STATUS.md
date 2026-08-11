# Coding Tools · 项目状态

> 单一事实源：当前阶段、已完成项、未完成项、下一动作。
> 每次发版后更新本文件。

## 当前状态

- **阶段**：阶段 7 — Sparkle 自动更新（已上线）；阶段 8 待启动
- **版本**：v1.2.1（build 16，文档清理 patch）
- **最近更新**：2026-08-11

## 阶段路线

| 阶段 | 名称 | 计划周期 | 状态 | Owner |
| --- | --- | --- | --- | --- |
| 0 | 产品和安全契约 | 3–5 d | ✅ 已完成 | Coordinator |
| 1 | 工程骨架 | 3–5 d | ✅ 已完成 | Coordinator |
| 2 | 目录与安全目录 | 1–2 w | ✅ 已完成 | 子代理 A |
| 3 | 安装、检测、启动 | 2–3 w | ✅ 已完成 | 子代理 A |
| 4 | 主界面 | 1.5–2 w | ✅ 已完成 | 子代理 B |
| 5 | 内容中心 | 1–1.5 w | ✅ 已完成 | 子代理 B |
| 6 | 多语言、主题、可访问性 | 3–5 d | ✅ 已完成 | 子代理 B |
| 7 | Sparkle 自动更新 | 1–2 w | ✅ 已完成 | 子代理 C |
| 8 | 内部 Beta + 稳定版 | 1.5–2 w | 🔄 待启动 | Coordinator |

## 已完成（本轮 · 2026-08-11）

### 阶段 7 — Sparkle 自动更新 + 发版管道
- [x] Sparkle 2.x appcast `xml:lang` 强要求适配（v1.0.3 → v1.0.9）
- [x] 自定义 `SPUUserDriver` 静默更新（v1.0.2）
- [x] ZIP + PKG 双 enclosure（v1.0.1 / v1.0.2）
- [x] Settings 检查更新按钮 + 实时下载进度（v1.0.0 / v1.1.0）
- [x] MenuBarExtra 检查更新快捷入口（v1.1.0）
- [x] 端到端发版脚本 `release.sh`：bump → tests → build → DMG+ZIP+PKG → `sign_update` → `generate_appcast` → commit+tag+push → `gh release create`
- [x] EdDSA appcast 签名（`.keys/ed25519_private_key` → `SUPublicEDKey`）

### 阶段 6 — 多语言、主题、可访问性（v1.2.0）
- [x] Localizable.xcstrings：7 种语言（en / zh-Hans / ja / ko / fr / de / es），452 条翻译
- [x] 浅色 / 深色 / 跟随系统
- [x] 顶部 Toast banner（info / success / warning / error）+ 自动消失 + 重试

### 阶段 4 — 主界面（v1.1.0）
- [x] ToolCard 视觉升级（风险标 / tool id / 进度环 / hover）
- [x] Home 可更新区接 Sparkle
- [x] Settings 关于卡片（app icon gradient + 名字 + 副标题 + 版本/最低系统/架构 + GitHub + 致谢）

### 阶段 5 — 内容中心（v1.1.0）
- [x] Content 教程 12 条（仅元数据 + 原文链接，不下载视频）

### 阶段 1 — 工程骨架
- [x] Tuist 4 工程：14 个 framework + 5 个 unit test target + 1 个 .app
- [x] Sparkle 2.9.5 依赖解析成功
- [x] 14 个 framework 全部编译通过（arm64 / macOS 14+）
- [x] `Coding Tools.app` 完整构建产物
- [x] 单元测试模块：DomainTests / CatalogTests / InstallerTests / ManifestSecurityTests
- [x] 9 个发布脚本
- [x] CI workflow 占位：`.github/workflows/ci.yml` + `release.yml`

### 协作基础
- [x] AGENTS.md（Agent 协作入口）
- [x] `.multi-agent-collaboration/` v3 文档总线
- [x] `.gitignore`（Xcode / Tuist / Sparkle / 密钥）
- [x] git 仓库初始化，初始 commit `f1b76c2`

### v1.2.1 文档清理 patch（本轮）
- [x] CHANGELOG.md 去重：移除 `release.sh` 多次发版留下的「暂未发布」重复段，每版本只保留一条 `### Changed`；补全 `compare` 链接脚注
- [x] `release.sh` Python 段修复：去掉重复生成 `## [Unreleased]` 模板的逻辑，每次发版只插入新版本段、不污染既有结构
- [x] PROJECT_STATUS.md 阶段状态对齐：阶段 2–7 标 ✅，阶段 8 待启动；本轮 v1.2.1 记录到「已完成」

## 进行中

- [ ] 子代理 A 启动 T001（Stage 0 工具真实参数补全）
- [ ] 子代理 A 启动 T002（SECURITY_MODEL / CATALOG_SCHEMA 评审）
- [ ] 子代理 C 启动 T009（已通过 → 关闭）
- [ ] Apple Developer ID 申请状态确认（v0.5 之前）

## 未完成（按优先级）

### 阶段 0 剩余
- [ ] PRODUCT_SPEC 验收评审
- [ ] SECURITY_MODEL 验收评审
- [ ] CATALOG_SCHEMA 验收评审
- [ ] 8 个 Stage 0 工具详细参数表（每个工具的官方 URL、Homebrew 名称、版本规则、Bundle ID、Team ID、SHA-256、架构支持）

### 阶段 1（工程骨架）
- [ ] CodingToolsApp 入口 + AppDelegate + AppModel
- [ ] MenuBarExtra 入口占位
- [ ] Settings 窗口占位
- [ ] SQLite 初始化（GRDB 或 SQLite.swift）
- [ ] CI 配置（build + test + lint）

### 阶段 2（目录）
- [ ] 远程目录下载 + 签名验证
- [ ] 本地 SQLite 缓存
- [ ] 撤销列表
- [ ] 过期检测

### 阶段 3（安装）
- [ ] Homebrew Adapter
- [ ] mise Adapter
- [ ] 官方安装包 Adapter
- [ ] 安装队列 + 取消
- [ ] 版本检测 + 架构检测

## 发布节点

| 版本 | 目标 |
| --- | --- |
| v0.1.0 | 工程原型（Debug 可启动） |
| v0.5.0 | 内部可用版（Stage 0 工具全通过） |
| v0.9.0 | 内部 Beta |
| v1.0.0 | 第一版稳定发布 |

## 风险登记

| 风险 | 状态 | 缓解 |
| --- | --- | --- |
| Apple Developer ID 申请 | 未开始 | v0.5 之前完成 |
| Sparkle 2 集成复杂度 | 未评估 | 先做最小集成，再扩展 |
| 远程目录分发方案 | 未决定 | 自建 GitHub Pages + Ed25519 |
| YouTube Data API Key 不能放客户端 | 已知 | 服务端聚合元数据，客户端只读快照 |

## 下一动作

1. `tuist generate` 验证工程能起来
2. 启动多代理协作 run-001（3 个子代理：Catalog+Installer / UI+Content+Localization / Release+Update+Security）
3. 子代理 A 开始 Stage 0 工具参数表
4. 评审 SECURITY_MODEL 草案

## 维护规则

- 发版后必须更新本文件 + CHANGELOG.md
- 阶段变化时更新「阶段路线」表
- 新风险登记到「风险登记」表
