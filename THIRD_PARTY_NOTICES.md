# 第三方声明

本文件只记录 Coding Tools 当前已知的第三方依赖、目录元数据和外部品牌边界。它不是第三方许可证的替代品，也不改变任何上游许可证、服务条款、商标权或内容权利。

Coding Tools 第一方源代码、脚本和文档使用 [Apache License 2.0](./LICENSE)，第一方归属见 [`NOTICE`](./NOTICE)。Apache-2.0 不会把下列第三方内容重新授权为 Coding Tools 的内容。

## Sparkle

- 来源声明：[`Apps/Mac/Tuist/Package.swift`](./Apps/Mac/Tuist/Package.swift)
- 解析版本：`2.9.5`
- 固定 revision：`79bc9e872948e47877e76f194cb0c8e0412b0b90`
- 上游项目：[Sparkle](https://github.com/sparkle-project/Sparkle)
- 权利边界：Sparkle 的源代码、二进制、许可证、NOTICE、名称和商标属于相应上游权利人。
- 分发说明：如果构建或分发物包含 Sparkle，应同时遵守 Sparkle 随其源代码、二进制或发行物提供的许可证和 NOTICE 要求；本仓库不复制或改写上游法律文本。

## Catalog 与外部品牌

`Catalog/` 中的工具名称、Logo、官方 URL、教程链接、发行包信息和商标属于相应供应商或作者。目录签名只证明目录内容的完整性与发布者身份，不证明 Coding Tools 拥有或背书第三方品牌、软件或教程内容。

目录贡献者必须有权提交新增的描述和元数据。仓库不上传供应商安装包、付费视频、私有内容、API Key 或未经授权的 Logo；Homebrew、mise、官方安装包、外部教程、视频和服务均按各自条款使用。

## 新增依赖记录规则

后续新增直接依赖或随发行物分发的第三方组件时，应在本文件记录：

1. 依赖名称、来源文件和解析版本或 revision；
2. 上游项目链接与许可证/NOTICE 入口；
3. 是否随 App、安装器或其他发行物分发；
4. 需要保留的归属、商标或分发声明。

除必要的归属摘要外，不要把第三方完整许可证文本复制到本文件；分发时应以相应上游提供的法律文件为准。
