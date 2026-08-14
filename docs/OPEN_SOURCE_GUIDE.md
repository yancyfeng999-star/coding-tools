# 开源维护与证据指南

本文档面向 Coding Tools 的维护者和协作者，说明如何审阅公开贡献、处理第三方内容、保护本地数据，以及区分开发验证和正式发布证据。

## 公开入口

| 事项 | 入口 |
| --- | --- |
| 项目定位与快速开始 | [`README.md`](../README.md) |
| 代码、文档和 Catalog 贡献 | [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| 社区行为 | [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) |
| 安全问题 | [`SECURITY.md`](../SECURITY.md) |
| 用户支持 | [`SUPPORT.md`](../SUPPORT.md) |
| 第一方许可证 | [`LICENSE`](../LICENSE) 与 [`NOTICE`](../NOTICE) |
| 第三方声明 | [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) |
| 版本发布 | [`docs/RELEASE_WORKFLOW.md`](./RELEASE_WORKFLOW.md) |

## 维护者审阅顺序

每个公开变更先按下面顺序审阅，避免把代码正确性、权限安全和许可证权利混成一个结论：

1. **范围**：确认 PR 只处理声明的主题，没有混入 `.app`、`build/`、DerivedData、临时截图或无关重构。
2. **产品行为**：确认安装、启动、目录加载、更新和菜单栏行为仍遵守 [`AGENTS.md`](../AGENTS.md) 与 [`docs/SECURITY_MODEL.md`](./SECURITY_MODEL.md) 的约束。
3. **权限与隐私**：确认没有远程任意 Shell、静默 `sudo`、自动修改 `.zshrc`/`PATH`、客户端 API Key 或未经说明的数据收集。
4. **Catalog 安全**：确认新增字段、来源 URL、版本、哈希、签名、撤销列表和风险说明完整；目录签名只证明完整性与发布者身份。
5. **许可证**：确认第一方内容按 Apache-2.0，第三方依赖和外部品牌仍按各自条款，必要时同步 [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)。
6. **验证证据**：确认命令、环境、结果和未验证项分别记录，不把“本地通过”写成“已发布”。

## Apache-2.0 与归属

第一方代码、脚本和文档使用 Apache License 2.0，完整文本见 [`LICENSE`](../LICENSE)，第一方归属见 [`NOTICE`](../NOTICE)。Apache-2.0 为贡献者提供许可证规定的版权和专利授权范围，但不授予 Coding Tools 或贡献者使用第三方商标、安装包、教程、Logo 或私有内容的权利。

提交贡献前必须确认拥有相应权利。贡献者提交未明确标记为排除的内容时，应按仓库 Apache-2.0 贡献；如果内容受独立许可证、供应商条款或其他协议约束，必须在 PR 中明确说明并先获得维护者确认。

依赖、工具目录和外部内容的来源、版本、许可证入口和分发注意事项记录在 [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)。不要把第三方完整许可证文本复制到该文件，也不要用 Apache-2.0 覆盖第三方内容。

## Catalog 与目录签名

- 目录元数据只能使用允许公开的描述、版本、官方 URL、安装来源和教程链接。
- 不得加入 `command`、`script`、`sudo`、`pipe`、`redirect` 或 `postInstall` 等任意执行字段。
- 不上传供应商安装包、付费视频、私有教程、未经授权的 Logo、API Key 或目录签名私钥。
- 修改目录后，PR 必须说明签名生成/验证、撤销列表、来源可信度和兼容性影响。
- 签名私钥只进入受控的发布环境，不进入仓库、Issue、日志、截图或普通配置文件。

## 本地数据与隐私

当前产品的设置、缓存、日志和安装状态默认保存在用户本机；维护者审阅时不得要求用户上传完整配置、数据库、缓存、原始日志或凭证。诊断信息只收集复现问题所需的最小脱敏内容。

这段说明不是对未来功能的永久承诺，也不表示可以默认为收集诊断信息。任何新增遥测、诊断上传、账号系统或远程服务都必须先单独进行隐私与安全审查，并在面向用户的文档中公开说明数据类别、目的、保留、访问和退出方式。

## 证据状态

以下状态必须分别记录：

| 状态 | 能证明什么 | 不能替代什么 |
| --- | --- | --- |
| 文档检查通过 | Markdown/YAML/链接和敏感信息门禁通过 | 代码测试或 App 发布 |
| 本地测试通过 | 指定测试目标在指定环境通过 | 签名、公证或 Release |
| 本地构建通过 | 当前环境生成了可运行构建物 | Developer ID、公证或 GitHub Release |
| 签名通过 | 指定身份签署了指定产物 | 公证、下载分发或应用内更新 |
| 公证通过 | Apple 公证服务接受了指定产物 | GitHub Release 或用户安装验收 |
| GitHub Release 发布 | 指定版本产物已上传到 Release | 应用内更新链和用户验收 |
| 应用内更新通过 | 已验证更新器从 Appcast 完成更新 | 其他版本、架构或渠道 |

纯文档变更只需要文档门禁，不运行 `xcodebuild`、`tuist build`、`release.sh` 或 App 启动，也不升版本号或创建 Release。

## 文档与发布流程

文档变更完成后：

1. 运行 `git diff --check`、Markdown 相对链接检查和 GitHub YAML 解析；
2. 扫描 `.app`、`build/`、DerivedData、私钥和用户数据，确认无新增生成物；
3. 提交清晰的 `docs:` commit，确认工作树只包含本次范围；
4. 纯文档变更推送 `main`，不调用 [`Apps/Mac/scripts/release.sh`](../Apps/Mac/scripts/release.sh)；
5. 在交付说明中列出已验证的状态，并明确没有验证的构建、签名、公证、Release 或应用内更新状态。

代码或正式产品发布必须遵循 [`docs/RELEASE_WORKFLOW.md`](./RELEASE_WORKFLOW.md) 和 [`AGENTS.md`](../AGENTS.md)，不能用本指南替代发版流程。

## 安全与支持分流

安全问题只走 [`SECURITY.md`](../SECURITY.md) 的 GitHub 私密报告入口；不要通过公开 Issue、Pull Request 或普通支持请求披露完整利用细节。一般问题按 [`SUPPORT.md`](../SUPPORT.md) 分流，目录许可、商标和外部内容问题必须提供来源并保留权利边界。
