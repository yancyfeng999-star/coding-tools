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
| 0 | 产品和安全契约 | 3–5 d | ✅ 已完成计划文档，初始化工程骨架 |
| 1 | 工程骨架 | 3–5 d | ⏳ Tuist 工程已建，待 tuist generate 验证 |
| 2 | 目录与安全目录 | 1–2 w | ⬜ 未开始 |
| 3 | 安装、检测、启动 | 2–3 w | ⬜ 未开始 |
| 4 | 主界面 | 1.5–2 w | ⬜ 未开始 |
| 5 | 内容中心 | 1–1.5 w | ⬜ 未开始 |
| 6 | 多语言、主题、可访问性 | 3–5 d | ⬜ 未开始 |
| 7 | Sparkle 自动更新 | 1–2 w | ⬜ 未开始 |
| 8 | 内部 Beta + 稳定版 | 1.5–2 w | ⬜ 未开始 |

## 已完成（本轮）

- [x] 完成完整开发计划（[CODING_TOOLS_MACOS_DEVELOPMENT_PLAN.md](./CODING_TOOLS_MACOS_DEVELOPMENT_PLAN.md)）
- [x] 创建项目根目录结构
- [x] 建立 14 个 Tuist 模块占位（Domain / Catalog / ManifestSecurity / Installers / ProcessExecution / Detection / Launching / Content / Persistence / Localization / Theme / Updates / App / UI）
- [x] 建立 Catalog 子目录（tools / content / schemas / revocations）
- [x] 建立脚本目录（Scripts/ + Apps/Mac/scripts/）
- [x] 建立 CI workflow 占位（.github/workflows/）
- [x] 建立多代理协作文档总线占位（.multi-agent-collaboration/）
- [x] 写基线产品文档（README / PRODUCT / PRODUCT_SPEC / SECURITY_MODEL / CATALOG_SCHEMA / STAGE0_TOOLS / QA_MATRIX / RELEASE_WORKFLOW）
- [x] 写 AGENTS.md（Agent 协作入口）

## 进行中

- [ ] Tuist 工程 `tuist generate` 验证可启动
- [ ] 多代理协作 init_run 启动（3 个子代理）
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
