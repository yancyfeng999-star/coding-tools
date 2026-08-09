# Coding Tools · 项目状态

> 单一事实源：当前阶段、已完成项、未完成项、下一动作。
> 每次发版后更新本文件。

## 当前状态

- **阶段**：阶段 0 — 产品和安全契约
- **版本**：v0.0.0（工程原型，尚未发版）
- **最近更新**：2026-08-09

## 阶段路线

| 阶段 | 名称 | 计划周期 | 状态 |
| --- | --- | --- | --- |
| 0 | 产品和安全契约 | 3–5 d | ✅ 已完成（基线文档齐全） |
| 1 | 工程骨架 | 3–5 d | ✅ 已完成（tuist generate + xcodebuild + tests） |
| 2 | 目录与安全目录 | 1–2 w | ⬜ 未开始 |
| 3 | 安装、检测、启动 | 2–3 w | ⬜ 未开始 |
| 4 | 主界面 | 1.5–2 w | ⬜ 未开始 |
| 5 | 内容中心 | 1–1.5 w | ⬜ 未开始 |
| 6 | 多语言、主题、可访问性 | 3–5 d | ⬜ 未开始 |
| 7 | Sparkle 自动更新 | 1–2 w | ⬜ 未开始 |
| 8 | 内部 Beta + 稳定版 | 1.5–2 w | ⬜ 未开始 |

## 已完成（本轮 · 2026-08-09）

### 阶段 0 — 产品和安全契约
- [x] 完整开发计划 `CODING_TOOLS_MACOS_DEVELOPMENT_PLAN.md`
- [x] 产品合同 `docs/PRODUCT_SPEC.md`
- [x] 安全威胁模型 `docs/SECURITY_MODEL.md`（12 条 STRIDE 缓解）
- [x] 目录 JSON Schema `docs/CATALOG_SCHEMA.md` + `Catalog/schemas/catalog.schema.json`
- [x] 8 个 Stage 0 工具验证表 `docs/STAGE0_TOOLS.md`（待子代理 A 补全真实参数）
- [x] 测试矩阵 `docs/QA_MATRIX.md`
- [x] 发版流程 `docs/RELEASE_WORKFLOW.md` + Agent 详细步骤 `docs/AGENT_RELEASE_WORKFLOW.md`

### 阶段 1 — 工程骨架
- [x] Tuist 4 工程：14 个 framework + 5 个 unit test target + 1 个 .app
- [x] Sparkle 2.9.5 依赖解析成功
- [x] 14 个 framework 全部编译通过（arm64 / macOS 14+）
- [x] `Coding Tools.app` 完整构建产物（沙盒开启 + entitlements）
- [x] 4 个单元测试模块全部通过：DomainTests / CatalogTests / InstallerTests / ManifestSecurityTests
- [x] 5 个 test target + 4 个显式 test scheme（AppTests 待阶段 3 子代理 B 处理）
- [x] 9 个发布脚本（build / run-tests / bump-version / package-release / sign-release / notarize-release / generate-appcast / release / run-tests）
- [x] CI workflow 占位：`.github/workflows/ci.yml` + `release.yml`

### 协作基础
- [x] AGENTS.md（Agent 协作入口）
- [x] `.multi-agent-collaboration/` v3 文档总线
  - `project.yaml`（项目身份）
  - `protocol.yaml`（事件 / 角色 / 治理）
  - `runs/run-001/`（agents.yaml + 12 个任务 + state.yaml + next-action.md）
  - 3 个子代理：A=Catalog+Installer / B=UI+Content+i18n / C=Release+Update+Security

### 仓库
- [x] `.gitignore`（Xcode / Tuist / Sparkle / 密钥）
- [x] git 仓库初始化，初始 commit `f1b76c2`
- [x] 默认分支 main

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
