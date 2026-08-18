# Coding Tools

> macOS 开发者工具中心：可信安装源 + 教程知识库 + 工具启动器 + 环境检测 + 自动更新。

Coding Tools 把 Homebrew、mise、官方安装包、官方文档和精选教程整合到一个签名化的目录中，帮助开发者安全安装、启动和持续更新开发工具。

> 当前源码版本：v1.5.4（build 27）；最近公开 Release 为 v1.5.4（build 27）。已纳入首次启动说明、诊断与导出导入、目录缓存重置、崩溃恢复提示，以及统一界面令牌和工具展示状态映射。PKG 仍未用 Developer ID 签名，公证未做。

中文说明见 [`README.zh-CN.md`](./README.zh-CN.md)。

---

## 项目说明

- **代码仓库**：[`yancyfeng999-star/coding-tools`](https://github.com/yancyfeng999-star/coding-tools)
- **首发平台**：macOS 14 Sonoma 及以上
- **架构**：Apple Silicon + Intel Universal Binary
- **首发语言**：简体中文、English
- **首发版本策略**：v0.1.0（工程原型）→ v0.5.0（内部可用）→ v0.9.0（内部 Beta）→ v1.0.0（稳定发布）

完整开发计划：[`CODING_TOOLS_MACOS_DEVELOPMENT_PLAN.md`](./CODING_TOOLS_MACOS_DEVELOPMENT_PLAN.md)

---

## 目录速览

```text
Coding Tools/
├── Apps/Mac/                # Tuist + Swift 工程
│   ├── Project.swift
│   ├── Sources/             # 14 个模块（Domain/Catalog/Installers/UI/…）
│   ├── Tests/               # 单元测试
│   ├── Resources/           # 资源
│   ├── Tuist/               # Tuist 内部 Package
│   └── scripts/             # build/test/release/appcast 脚本
├── Catalog/                 # 工具目录与内容
│   ├── tools/               # 工具清单
│   ├── content/             # 教程 / 视频元数据
│   ├── schemas/             # 目录 JSON Schema
│   └── revocations/         # 撤销列表
├── Scripts/                 # 仓库级脚本
├── docs/                    # 产品 / 安全 / 测试 / 发布文档
├── .github/workflows/       # CI
└── .multi-agent-collaboration/  # 多代理协作文档总线
```

---

## 快速开始

```bash
# 1. 装工具链
brew install tuist

# 2. 生成 Xcode 工程
cd Apps/Mac && tuist install && tuist generate

# 3. 打开
open CodingTools.xcworkspace

# 4. 运行测试
./scripts/run-tests.sh
```

纯文档贡献不要求在本地构建或打开 macOS App。不要提交 `.app`、`build/`、DerivedData、临时截图、用户配置、原始日志或凭证；贡献流程见 [`CONTRIBUTING.md`](./CONTRIBUTING.md)。

---

## Interface, updates, feedback, and privacy

- Four tabs stay **Home / Tools / Content / Settings**. Shared design tokens cover type, spacing, color, and surfaces. Tool cards do not use gradient fills, heavy drop shadows, or hover scale.
- Tool cards, tool detail, the install sheet, and the menu bar render one presentation mapping. Missing latest version is never “up to date”; a failed probe is never “not installed”.
- **App Updates** (Sparkle) and **tool updates** are separate copy and separate state. Settings and the menu bar always expose **Check for Updates**. The app never checks or installs in the background. After you click the button, a found update downloads, then the app quits, installs silently, and reopens.
- Settings → Support & Feedback includes report issue, feature idea, homepage, help, and copy diagnostic summary. Issue URLs prefill only app version, build, macOS version, and CPU architecture. Logs and diagnostics are never uploaded automatically; copy-diagnostics shows a preview first.
- First launch explains the four tabs, trusted install sources, and the split between app updates and tool updates. Settings → Diagnostics shows catalog cache status, last crash, crash-folder access, and a user-triggered export/import of favorites, recents, theme, language, and update preferences. The portable file never includes home paths, tokens, or logs.
- Appearance supports Light, Dark, and Follow System. Switching back to Follow System clears a previously pinned app/window appearance so new system changes apply.

---

## 核心约束（铁律）

| 规则 | 说明 |
| --- | --- |
| 禁止远程任意 Shell | 目录里不能出现 `command` / `script` / `sudo` / `pipe` / `redirect` / `postInstall` |
| 工具安装必须显式 | 安装前显示来源、版本、风险；用户必须确认 |
| 不静默 sudo | 永不在用户不知情时执行 sudo |
| 不修改 Shell | 不自动改 `.zshrc`、不自动覆盖 `PATH` |
| 目录必须签名 | HTTPS + Ed25519 签名 + SHA-256 + 过期时间 + 撤销列表 |
| 不重打包 | 不下载视频、不重写付费内容、不二次分发 |
| 应用更新走 Sparkle | Coding Tools 自身更新用 Sparkle 2 + Appcast，工具更新分开 |
| 本地 ≠ 发布 | 本地构建通过不等于公证/发布/应用内更新通过 |

---

## 核心文档

| 文档 | 内容 |
| --- | --- |
| [PRODUCT.md](./PRODUCT.md) | 产品定位、目标用户、核心场景 |
| [PROJECT_STATUS.md](./PROJECT_STATUS.md) | 当前阶段、未完成项、下一动作 |
| [CHANGELOG.md](./CHANGELOG.md) | 版本历史 |
| [AGENTS.md](./AGENTS.md) | Agent 协作入口（必读） |
| [docs/PRODUCT_SPEC.md](./docs/PRODUCT_SPEC.md) | 详细产品合同 |
| [docs/SECURITY_MODEL.md](./docs/SECURITY_MODEL.md) | 安全威胁模型与缓解措施 |
| [docs/CATALOG_SCHEMA.md](./docs/CATALOG_SCHEMA.md) | 工具目录 JSON Schema |
| [docs/STAGE0_TOOLS.md](./docs/STAGE0_TOOLS.md) | 8 个 Stage 0 工具验证表 |
| [docs/QA_MATRIX.md](./docs/QA_MATRIX.md) | 测试矩阵 |
| [docs/RELEASE_WORKFLOW.md](./docs/RELEASE_WORKFLOW.md) | 发版流程 |
| [docs/AGENT_RELEASE_WORKFLOW.md](./docs/AGENT_RELEASE_WORKFLOW.md) | Agent 发版详细步骤 |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | 贡献流程、验证和安全边界 |
| [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) | 社区行为准则 |
| [SECURITY.md](./SECURITY.md) | 私密安全报告和支持版本 |
| [SUPPORT.md](./SUPPORT.md) | 用户支持与问题分流 |
| [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) | Sparkle、Catalog 和外部内容边界 |
| [docs/OPEN_SOURCE_GUIDE.md](./docs/OPEN_SOURCE_GUIDE.md) | 维护者开源协作与证据指南 |

---

## 许可证

[Apache License 2.0](./LICENSE)。Copyright © 2026 YancyFeng；第一方归属见 [`NOTICE`](./NOTICE)。Apache-2.0 适用于本项目明确创作并随仓库发布的第一方源代码、脚本和文档，不会重新授权 Sparkle、Homebrew、mise、Catalog 中的第三方内容、工具名称、Logo、教程、安装包或商标。相关来源与分发边界见 [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md)。
