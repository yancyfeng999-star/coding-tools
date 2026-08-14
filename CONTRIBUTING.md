# 贡献指南

感谢你为 Coding Tools 提交改进。本项目欢迎代码、目录元数据、文档、测试和问题修复，但所有贡献都必须遵守项目的安全边界与第三方权利边界。

## 开始之前

1. 阅读 [`AGENTS.md`](./AGENTS.md)、[`docs/SECURITY_MODEL.md`](./docs/SECURITY_MODEL.md) 和 [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md)。
2. 从最新的 `main` 创建一个主题分支；一个 Pull Request 只处理一个主题。
3. 先搜索已有 Issue 和 Pull Request，避免重复工作。
4. 不要把 Token、API Key、私钥、Cookie、用户配置、原始日志或本机绝对路径提交到仓库。

## 允许的贡献类型

### 代码与测试

- 遵守现有模块边界和 Swift 风格，避免无关重构。
- 目录数据不得出现远程任意 Shell 字段：`command`、`script`、`sudo`、`pipe`、`redirect`、`postInstall`。
- 安装动作必须显示来源、版本和风险，并由用户明确确认；不得静默执行 `sudo`。
- 不自动修改 `.zshrc` 或 `PATH`，不把 API Key 放入客户端。
- 代码变更应由 CI 执行既有测试；若本地具备工具链，可按 `Apps/Mac/scripts/run-tests.sh` 的说明运行对应测试。

### Catalog 与外部内容

Catalog 变更必须在 Pull Request 中说明：

- 工具名称、版本、官方 URL 和元数据来源；
- 许可证、商标、Logo、教程或视频链接的权利来源；
- 目录签名、撤销列表和兼容性影响；
- 是否新增外部下载、权限或隐私风险。

不得上传供应商安装包、付费视频、私有内容、未经授权的 Logo 或任何凭证。目录签名证明的是目录完整性与发布者身份，不代表 Coding Tools 拥有第三方品牌或内容。

### 文档与纯文档变更

纯文档变更至少运行：

```bash
git diff --check
```

纯文档变更不要求在维护者机器上构建或打开 macOS App；不要生成、注册或提交 `.app`、`build/`、DerivedData、临时截图或用户数据。

## 提交与 Pull Request

提交信息使用现有前缀，并用一句话说明实际变更：

```text
feat: add catalog source validation
fix: prevent duplicate menu item
docs: explain open-source contribution flow
chore: update dependency metadata
```

Pull Request 描述应包含：

1. 变更范围与动机；
2. 验证命令及结果，或说明为什么没有运行某项验证；
3. 是否改变 Catalog 签名、权限、隐私或第三方内容；
4. 是否涉及许可证、NOTICE、商标或外部内容；
5. 是否产生过本地构建物，并确认它们没有进入提交。

请使用 [Pull Request 模板](./.github/PULL_REQUEST_TEMPLATE.md) 完成自检。代码变更的 CI、签名、公证、GitHub Release 和应用内更新是不同的证据状态；不要把其中一项写成另一项已经完成。

## 许可证与贡献者声明

本项目第一方代码、脚本和文档使用 [Apache License 2.0](./LICENSE)，第一方归属见 [`NOTICE`](./NOTICE)。提交 Pull Request 表示你有权提交所提供的内容，并同意新增的第一方贡献按 Apache-2.0 发布；Apache-2.0 中的版权和专利条款适用于该贡献。

第三方代码、依赖、工具名称、Logo、教程、视频、安装包和商标不因提交到本仓库而转为 Coding Tools 内容。无法确认权利来源的内容不要提交；项目当前不要求额外 CLA。

## 安全问题

不要在公开 Issue 或 Pull Request 中披露可利用的安全漏洞、凭证或完整利用细节。请阅读 [`SECURITY.md`](./SECURITY.md)，使用 GitHub 私密安全报告入口。

## 发布边界

纯文档贡献不升版本、不运行 `release.sh`、不创建 Release。代码和产品发布继续遵循 [`docs/RELEASE_WORKFLOW.md`](./docs/RELEASE_WORKFLOW.md) 与 [`AGENTS.md`](./AGENTS.md)；本项目会分别记录本地构建、签名、公证、Release 和应用内更新证据。
