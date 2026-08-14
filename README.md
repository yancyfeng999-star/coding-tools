# Coding Tools

> macOS 开发者工具中心：可信安装源 + 教程知识库 + 工具启动器 + 环境检测 + 自动更新。

Coding Tools 把 Homebrew、mise、官方安装包、官方文档和精选教程整合到一个签名化的目录中，帮助开发者安全安装、启动和持续更新开发工具。

> 当前状态：v1.5.0（build 23）已发布到 GitHub。已接通 24 个工具目录、Ed25519 验签、安装链、持久化收藏/最近使用、菜单栏入口和 Coding Tools 品牌资源；当前构建为本地 ad-hoc 签名，Developer ID / 公证仍待外部流程。

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
