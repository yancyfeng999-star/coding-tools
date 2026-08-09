# Coding Tools · Stage 0 工具验证表

> 阶段 3 实施前必须完成 8 个工具的真实安装 + 检测 + 启动测试。
> 此表是验收基线，Agent 填写后必须用真实 Homebrew / mise / 官方包测试。

## 1. Stage 0 目标

覆盖 6 种安装场景 + 2 种架构 + 启动能力：

| 安装场景 | 工具 |
| --- | --- |
| Homebrew Formula | git, node, python, go, rust |
| Homebrew Cask | iterm2, visual-studio-code |
| mise Runtime | node, python, go, rust |
| 官方安装包 (DMG/PKG) | docker |
| GUI App | visual-studio-code, iterm2, docker |
| CLI 工具 | git, node, python, go, rust |
| 多架构 | rust, node, python, go, docker |

## 2. 8 个 Stage 0 工具

### 2.1 Git

| 字段 | 值 |
| --- | --- |
| ID | `git` |
| Name | `Git` |
| Category | `git-collaboration` |
| 首选安装 | `homebrew-formula: git` |
| 备用安装 | `official-pkg: https://sourceforge.net/projects/git-osx-installer/` |
| 最低 macOS | 14.0 |
| 支持架构 | arm64, x86_64 |
| 风险等级 | low |
| 启动 | cli (`git --version`) |
| Bundle ID | — (CLI) |
| 验证命令 | `git --version` |
| 风险说明 | Homebrew 源；安装到 /opt/homebrew |

### 2.2 Node.js

| 字段 | 值 |
| --- | --- |
| ID | `nodejs` |
| Name | `Node.js` |
| Category | `language-runtime` |
| 首选安装 | `mise-tool: node@22` |
| 备用安装 | `homebrew-formula: node` |
| 最低版本 | 22.x |
| 最低 macOS | 14.0 |
| 支持架构 | arm64, x86_64 |
| 风险等级 | low |
| 启动 | cli (`node --version`) |
| 验证命令 | `node --version` + `npm --version` |
| 风险说明 | 多版本时用 mise 隔离 |

### 2.3 Python

| 字段 | 值 |
| --- | --- |
| ID | `python` |
| Name | `Python` |
| Category | `language-runtime` |
| 首选安装 | `mise-tool: python@3.12` |
| 备用安装 | `homebrew-formula: python@3.12` |
| 最低版本 | 3.12 |
| 最低 macOS | 14.0 |
| 支持架构 | arm64, x86_64 |
| 风险等级 | low |
| 启动 | cli (`python3 --version`) |
| 验证命令 | `python3 --version` + `pip3 --version` |
| 风险说明 | macOS 自带 Python 3.x；用 mise 隔离避免污染系统 |

### 2.4 Go

| 字段 | 值 |
| --- | --- |
| ID | `go` |
| Name | `Go` |
| Category | `language-runtime` |
| 首选安装 | `mise-tool: go@1.23` |
| 备用安装 | `homebrew-formula: go` |
| 最低版本 | 1.23 |
| 最低 macOS | 14.0 |
| 支持架构 | arm64, x86_64 |
| 风险等级 | low |
| 启动 | cli (`go version`) |
| 验证命令 | `go version` + `go env GOROOT` |
| 风险说明 | — |

### 2.5 Rust

| 字段 | 值 |
| --- | --- |
| ID | `rust` |
| Name | `Rust` |
| Category | `language-runtime` |
| 首选安装 | `homebrew-formula: rustup-init` |
| 备用安装 | `official-script: https://sh.rustup.rs` (v1.0.0 不支持) |
| 最低版本 | 1.80 |
| 最低 macOS | 14.0 |
| 支持架构 | arm64, x86_64 |
| 风险等级 | medium (rustup 修改 PATH) |
| 启动 | cli (`rustc --version`) |
| 验证命令 | `rustc --version` + `cargo --version` |
| 风险说明 | rustup-init 会修改 `~/.cargo/env`；需提示用户 |

### 2.6 Visual Studio Code

| 字段 | 值 |
| --- | --- |
| ID | `vscode` |
| Name | `Visual Studio Code` |
| Category | `editor` |
| 首选安装 | `homebrew-cask: visual-studio-code` |
| 备用安装 | `official-dmg: https://code.visualstudio.com/Download` |
| 最低 macOS | 14.0 |
| 支持架构 | arm64 (Apple Silicon), x86_64 (Intel) |
| 风险等级 | low |
| 启动 | app (`com.microsoft.VSCode`) |
| Bundle ID | `com.microsoft.VSCode` |
| Team ID | `UBF8T346G9` |
| 验证命令 | `code --version` + 启动 App |
| 风险说明 | 官方 cask；安装到 /Applications |

### 2.7 Docker Desktop

| 字段 | 值 |
| --- | --- |
| ID | `docker-desktop` |
| Name | `Docker Desktop` |
| Category | `docker` |
| 首选安装 | `homebrew-cask: docker` |
| 备用安装 | `official-dmg: https://desktop.docker.com/mac/main/...dmg` |
| 最低 macOS | 14.0 |
| 支持架构 | arm64, x86_64 |
| 风险等级 | medium (需要授权安装 helper) |
| 启动 | app (`com.docker.docker`) |
| Bundle ID | `com.docker.docker` |
| Team ID | `9BNSXJN65R` |
| 验证命令 | `docker --version` + 启动 App |
| 风险说明 | 需要用户授权安装系统 helper；占用资源 |

### 2.8 iTerm2

| 字段 | 值 |
| --- | --- |
| ID | `iterm2` |
| Name | `iTerm2` |
| Category | `terminal` |
| 首选安装 | `homebrew-cask: iterm2` |
| 备用安装 | `official-dmg: https://iterm2.com/downloads.html` |
| 最低 macOS | 14.0 |
| 支持架构 | arm64, x86_64 |
| 风险等级 | low |
| 启动 | app (`com.googlecode.iterm2`) |
| Bundle ID | `com.googlecode.iterm2` |
| Team ID | `H7V7XYUQ7F` |
| 验证命令 | 启动 App |
| 风险说明 | — |

## 3. 验收测试清单（每个工具必跑）

```text
[ ] 安装前显示预览（工具名、版本、来源、风险）
[ ] 用户点击「安装」后实际执行
[ ] 安装过程中显示实时输出
[ ] 安装完成后版本号正确
[ ] 路径检测正确
[ ] 架构检测正确（arm64 / x86_64）
[ ] CLI 工具：launch capability 正确
[ ] App 工具：能通过 NSWorkspace 启动
[ ] 离线时显示「已安装」状态
[ ] 失败时回滚到原始状态
[ ] OperationLog 写入完整
```

## 4. 真实环境测试矩阵

| 环境 | 状态 |
| --- | --- |
| macOS 14 Apple Silicon | ⬜ |
| macOS 14 Intel | ⬜ |
| macOS 15+ Apple Silicon | ⬜ |
| 已装 Homebrew | ⬜ |
| 未装 Homebrew | ⬜ |
| 已装 mise | ⬜ |
| 未装 mise | ⬜ |
| /Applications 不可写 | ⬜ |
| 用户无 sudo | ⬜ |

## 5. 真实测试记录模板

每个工具一条记录：

```markdown
### Git（2026-08-XX）

- 测试机：MacBook Pro M3，macOS 15.0
- 安装方式：homebrew-formula
- 命令：brew install git
- 输出：git version 2.46.0
- 路径：/opt/homebrew/bin/git
- 架构：arm64
- 启动：git --version → 2.46.0
- OperationLog ID：LOG-20260809-001
- 测试人：子代理 A
- 结果：✅ 通过 / ❌ 失败（原因）
```

## 6. 评审记录

| 日期 | 评审人 | 结果 | 备注 |
| --- | --- | --- | --- |
| 2026-08-09 | Coordinator (Mavis) | 初稿 | 阶段 3 实施前需子代理 A 补全 Bundle ID / Team ID 真实值 |
