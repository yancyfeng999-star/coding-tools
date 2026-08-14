# Coding Tools · 项目状态

> 单一事实源：当前阶段、已完成项、未完成项、下一动作。
> 每次发版后更新本文件。

## 当前状态

- **阶段**：v1.5.0 发布候选；阶段 9 架构就位、阶段 11 目录签名已接通、阶段 12 本地 Crash 落盘已起步
- **版本**：v1.5.0（build 23）
- **最近更新**：2026-08-14

## 阶段路线

| 阶段 | 名称 | 计划周期 | 状态 | Owner |
| --- | --- | --- | --- | --- |
| 0 | 产品和安全契约 | 3–5 d | ✅ 已完成 | Coordinator |
| 1 | 工程骨架 | 3–5 d | ✅ 已完成 | Coordinator |
| 2 | 目录与安全目录 | 1–2 w | ✅ 已完成（Ed25519 验签已接通） | 子代理 A |
| 3 | 安装、检测、启动 | 2–3 w | ✅ 已完成 | 子代理 A |
| 4 | 主界面 | 1.5–2 w | ✅ 已完成 | 子代理 B |
| 5 | 内容中心 | 1–1.5 w | ✅ 已完成 | 子代理 B |
| 6 | 多语言、主题、可访问性 | 3–5 d | ✅ 已完成 | 子代理 B |
| 7 | Sparkle 自动更新 | 1–2 w | ✅ 已完成 | 子代理 C |
| 8 | 持续发布 v1.2.x | — | ✅ 已完成（v1.2.4 Latest） | Coordinator |
| 9 | Sandbox + XPC Helper | 2–3 w | 🟡 **架构就位**（待 Apple ID 开 sandbox） | Coordinator |
| 10 | Apple Developer ID + 签名 / 公证 | 1–2 w（依赖外部） | ⬜ 未开始 | Coordinator |
| 11 | 目录签名接通（ManifestSecurity 接到 Catalog 加载链） | 1 w | ✅ 已完成（工具与内容目录均验签） | 子代理 A + C |
| 12 | Post-release 闭环（遥测 / 反馈 / Crash） | 2 w | 🟡 **Crash 本地落盘起步** | 子代理 B |

## 已完成（本轮 · 2026-08-14）

### v1.5.0 发布候选收口
- [x] 24 个工具目录与内容目录加入 Ed25519 签名，Bundle 内置公钥，Catalog/Content 加载链默认验签并拒绝失败数据。
- [x] 安装链按真实 `InstallAction` 透传到 Homebrew / mise / npm / official-artifact，移除 `curl | bash` 回退；取消会停止任务并支持 Helper 兜底。
- [x] FileJSONStore 持久化收藏、最近使用与安装状态；进度日志统一脱敏。
- [x] 菜单栏启动入口按 CLI / App / 白名单 URL 分发；首页、详情页、安装弹窗显示真实来源、风险和状态。
- [x] Coding Tools logo 接入菜单栏状态项、菜单头部、关于卡片和 AppIcon；支持 PNG 1:1 资源。
- [x] 9 个测试 scheme 共 194 个测试通过；Debug / Release Universal Binary 构建通过。

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

- [ ] Apple Developer ID 申请（外部流程，阶段 10 阻塞 sandbox + 公证 + 上架）
- [ ] Sandbox 实际开启（等阶段 10 完成）
- [ ] NpmGlobalAdapter 切换到走 HelperClient（阶段 9 二期）
- [ ] HomebrewAdapter / MiseToolAdapter / OfficialArtifactAdapter 迁移到 Helper（阶段 9 三期）

## 未完成（按优先级）

### 阶段 9 二期（NpmGlobalAdapter → Helper）
- [ ] `NpmGlobalAdapter.execute` 改为走 `HelperClient`
- [ ] fallback：Helper 不可用时回到进程内 executor
- [ ] 回归：在 sandbox 关的情况下跑通 npm install -g

### 阶段 9 三期（其他 Adapter 迁移）
- [ ] HomebrewAdapter → Helper
- [ ] MiseToolAdapter → Helper
- [ ] OfficialArtifactAdapter → Helper
- [ ] 全 Adapter 走 Helper 后，App 进程可开 sandbox

### 阶段 10（签名 / 公证）
- [ ] Apple Developer ID 申请 + 加入 Apple Developer Program
- [ ] `sign-release.sh` 接通 Developer ID Application + Installer
- [ ] `notarize-release.sh` 接通 `xcrun notarytool`
- [ ] 公证 staple 到 DMG / PKG
- [ ] 替换 ad-hoc 签名为 Developer ID

### 阶段 11（目录签名）
- [x] Ed25519 公钥随 App 入库，私钥仅保留在本机 `.keys/`
- [x] `ManifestCanonicalizer` 接到 `CatalogLoader` 与 `ContentLoader`
- [x] 现有 24 个 `tools/*.json` 与 `content/*.json` 已签名
- [x] Catalog 加载时验签、检查过期并检查撤销列表
- [ ] `Catalog/revocations/` 维护流程持续补齐

### 阶段 12 二期（Crash 报告访问 + Sentry 可选）
- [ ] Settings 加「打开 crash log 文件夹」按钮
- [ ] 关于页加「最近一次 crash 时间」指示
- [ ] v2.0 路线：Sentry SDK 集成（云端 dedup / 告警 / 需新建 Sentry 账号 + DSN）

## 发布节点

| 版本 | 目标 | 状态 |
| --- | --- | --- |
| v0.1.0 | 工程原型（Debug 可启动） | ✅ 已发布 |
| v0.5.0 | 内部可用版（Stage 0 工具全通过） | ⚠️ 跳过（路线已合并到 v1.0） |
| v1.0.0 | 第一版稳定发布 | ✅ 已发布 |
| v1.1.0 | UI 打磨（教程 / 菜单栏 / ToolCard） | ✅ 已发布 |
| v1.2.0 | 多语言扩展 + Settings 关于 + Toast | ✅ 已发布 |
| v1.2.1 | 文档清理 patch | ✅ 已发布 |
| v1.2.2 | UpdatesTests 修复 + 反馈问题 + 工具扩充 | 🔄 历史文档待归档 |
| v1.5.0 | 目录安全、安装链、持久化、菜单栏与品牌资源收口 | 🔄 本轮发布 |
| v2.0.0 | Apple Developer ID + 公证 + App Store 上架 | ⬜ 待启动 |

## 风险登记

| 风险 | 状态 | 缓解 |
| --- | --- | --- |
| Apple Developer ID 申请 | 🔴 未开始 | 阶段 10；外部流程阻塞（无 Apple ID） |
| Sandbox 关闭 | 🔴 v1.0.0 起一直未恢复 | 阶段 9：引入 XPC Helper 后再开 |
| 目录签名未接通 | 🟢 已修复 | 24 个工具与内容 manifest 已签名；加载链 fail-closed |
| Post-release 闭环缺失 | 🟡 本地 Crash 已落盘，云端收集未接 | 阶段 12 后续评估 Sentry / 反馈闭环 |
| Catalog 工具数低于承诺 | 🟢 24 个工具 | 后续按目录治理流程扩充 |
| 测试覆盖率 ~22.5% | 🟡 偏低 | 关键模块补 AppTests / CatalogTests |
| Sparkle 端到端更新未真实验证 | 🟡 release 成功 ≠ 用户装机成功 | 需要真实装机记录 |
| CFBundleLocalizations 与 .xcstrings 不一致 | 🟢 已修复（v1.2.2） | Info.plist 补 5 种语言 |
| LICENSE 决定 | 🟢 MIT | v1.2.2 README 已更新 |
| Apple Silicon / Intel 兼容性 | 🟢 Universal Binary | Release 配置 `arm64+x86_64` |
| macOS 14+ 兼容性 | 🟢 LSMinimumSystemVersion 14.0 | — |
| 第三方依赖供应链（Sparkle 2.9.5 SPM） | 🟡 已知 | 锁定 commit hash；升级走 PR 评审 |

## 下一动作

1. 完成 v1.5.0 GitHub Release 与远程资产核验
2. 申请 Apple Developer ID（独立流程，外部阻塞）
3. 全 Adapter 迁移到 Helper 后重新开启 App Sandbox
4. 在独立机器完成安装与 Sparkle 端到端升级验收

## 维护规则

- 发版后必须更新本文件 + CHANGELOG.md
- 阶段变化时更新「阶段路线」表
- 新风险登记到「风险登记」表
