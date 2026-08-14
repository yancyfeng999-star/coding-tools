# 用户支持

这里用于 Coding Tools 的使用问题、可复现故障和功能建议分流。请先阅读 [`README.md`](./README.md)、[`docs/SECURITY_MODEL.md`](./docs/SECURITY_MODEL.md) 和 [`docs/RELEASE_WORKFLOW.md`](./docs/RELEASE_WORKFLOW.md)，再创建合适类型的 Issue。

## 请求分流

| 问题类型 | 入口 | 注意事项 |
| --- | --- | --- |
| 文档或使用疑问 | 阅读 README 和现有文档后创建 Issue | 说明你查过的文档章节 |
| 可复现 Bug | [Bug report](./.github/ISSUE_TEMPLATE/bug_report.yml) | 提供版本、macOS、架构和最小复现 |
| 功能建议 | [Feature request](./.github/ISSUE_TEMPLATE/feature_request.yml) | 说明使用场景、替代方案、权限和隐私影响 |
| 安全漏洞 | [`SECURITY.md`](./SECURITY.md) | 只使用私密安全报告，不要公开漏洞细节 |
| 目录内容、许可或商标 | 创建 Issue 并说明来源 | 不上传供应商安装包、Logo、付费内容或私有资料 |

## 诊断信息

提交诊断信息前，请删除或替换：

- Token、API Key、私钥、Cookie 和其他凭证；
- 用户名、家庭目录、绝对路径和设备标识；
- 原始安装日志、用户配置、目录缓存和数据库内容；
- 任何第三方私有内容或未公开下载链接。

可以提供脱敏后的版本、macOS 版本、CPU 架构、操作步骤、期望结果、实际结果和相关错误码。不要为了复现问题关闭目录验签、复制私钥或执行未经确认的 `sudo`。

## 支持范围

支持请求不等于产品承诺或法律意见。我们会根据可复现性、影响范围、版本状态和维护资源进行处理；纯文档问题不需要构建或打开 App。代码测试、App 构建、签名、公证、GitHub Release 和应用内更新是不同状态，请不要将本地构建成功写成正式发布完成。

如果问题涉及第三方工具、Homebrew、mise、官方安装包、教程或服务，请同时提供对应的官方来源，并遵守 [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md) 说明的权利边界。
