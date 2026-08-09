# Coding Tools · 目录 JSON Schema

> v1.0.0 草案。远程签名目录的正式定义。

## 1. 设计原则

1. **强类型 + 显式**：所有字段必须有明确含义，不允许「未指定」。
2. **零任意 Shell**：schema 中不存在 `command` / `script` / `postInstall` 等可执行字段。
3. **签名必需**：每个 `CatalogSnapshot` 必须带 `keyID` + `signature`。
4. **过期检测**：`expiresAt` 必须存在；过期后只能浏览，不能安装。
5. **可撤销**：`revokedItems` 列出已撤销的工具 ID。

## 2. 顶层结构

```json
{
  "schemaVersion": "1.0.0",
  "catalogVersion": "2026.08.09-001",
  "createdAt": "2026-08-09T00:00:00Z",
  "expiresAt": "2026-08-16T00:00:00Z",
  "keyID": "ed25519:8a3f...",
  "signature": "base64-ed25519-signature",
  "tools": [Tool, ...],
  "contentRefs": [ContentRef, ...],
  "revokedItems": ["tool-id-1"]
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `schemaVersion` | string | ✅ | semver，App 内置 |
| `catalogVersion` | string | ✅ | 目录自身的版本（日期 + 序号） |
| `createdAt` | ISO8601 | ✅ | 目录生成时间 |
| `expiresAt` | ISO8601 | ✅ | 过期时间；过期后只能浏览 |
| `keyID` | string | ✅ | 签名 Key ID（8 字节 hex） |
| `signature` | base64 | ✅ | Ed25519 签名（针对 canonical JSON） |
| `tools` | array | ✅ | 工具列表（≤ 500 项/v1.0.0） |
| `contentRefs` | array | ❌ | 教程 / 视频元数据引用 |
| `revokedItems` | array | ❌ | 已撤销工具 ID |

## 3. Tool 结构

```json
{
  "id": "nodejs",
  "slug": "nodejs",
  "name": "Node.js",
  "localizedName": { "en": "Node.js", "zh-Hans": "Node.js" },
  "description": "JavaScript runtime built on V8",
  "localizedDescription": {
    "en": "JavaScript runtime built on V8",
    "zh-Hans": "基于 V8 的 JavaScript 运行时"
  },
  "category": "language-runtime",
  "tags": ["javascript", "node", "runtime"],
  "homepageURL": "https://nodejs.org",
  "documentationURL": "https://nodejs.org/en/docs",
  "installOptions": [InstallOption, ...],
  "launchCapability": {
    "type": "cli",
    "command": "node",
    "openInTerminal": true
  },
  "supportedArchitectures": ["arm64", "x86_64"],
  "minimumMacOS": "14.0",
  "status": "active",
  "riskLevel": "low"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | 全局唯一，slug 形式 |
| `slug` | string | ✅ | URL 友好标识 |
| `name` | string | ✅ | 工具名（默认 en） |
| `localizedName` | map | ✅ | 多语言名称 |
| `description` | string | ✅ | 简介（默认 en） |
| `localizedDescription` | map | ✅ | 多语言简介 |
| `category` | enum | ✅ | 分类（见 §6） |
| `tags` | array | ❌ | 标签 |
| `homepageURL` | URL | ✅ | 官方网站 |
| `documentationURL` | URL | ❌ | 官方文档 |
| `installOptions` | array | ✅ | 安装方式（≥1） |
| `launchCapability` | object | ❌ | 启动能力（见 §4） |
| `supportedArchitectures` | array | ✅ | `arm64` / `x86_64` |
| `minimumMacOS` | semver | ✅ | 最低 macOS 版本 |
| `status` | enum | ✅ | `active` / `deprecated` / `experimental` |
| `riskLevel` | enum | ✅ | `low` / `medium` / `high` |

## 4. InstallOption 结构

按安装来源的强类型映射：

```json
{
  "type": "homebrew-formula",
  "packageName": "node",
  "versionRule": ">=22.0.0",
  "riskLevel": "low"
}
```

或：

```json
{
  "type": "homebrew-cask",
  "packageName": "visual-studio-code",
  "versionRule": ">=1.90.0",
  "riskLevel": "low"
}
```

或：

```json
{
  "type": "mise-tool",
  "toolName": "node",
  "version": "22",
  "riskLevel": "low"
}
```

或：

```json
{
  "type": "official-artifact",
  "url": "https://nodejs.org/dist/v22.7.5/node-v22.7.5.pkg",
  "sha256": "8a3f...",
  "bundleID": "org.nodejs.node.pkg",
  "teamID": "EA7RXK7B3K",
  "supportedArchitectures": ["arm64", "x86_64"],
  "minimumMacOS": "14.0",
  "requiresAuthorization": true,
  "riskLevel": "medium"
}
```

### 4.1 InstallOption 字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | enum | ✅ | `homebrew-formula` / `homebrew-cask` / `mise-tool` / `official-artifact` |
| `packageName` | string | ✅ (formula/cask) | Homebrew 包名 |
| `versionRule` | semver | ❌ | 最低推荐版本 |
| `toolName` | string | ✅ (mise) | mise 工具名 |
| `version` | string | ❌ (mise) | 推荐版本（不指定则用 latest） |
| `url` | URL | ✅ (artifact) | 必须 HTTPS |
| `sha256` | hex | ✅ (artifact) | 64 字符 |
| `bundleID` | string | ❌ | App Bundle ID（用于校验） |
| `teamID` | string | ❌ | Apple Team ID（10 字符） |
| `supportedArchitectures` | array | ❌ | 默认继承 Tool |
| `minimumMacOS` | semver | ❌ | 默认继承 Tool |
| `requiresAuthorization` | bool | ❌ | 是否需要用户授权（PKG 默认 true） |
| `riskLevel` | enum | ✅ | 见 §5 |

### 4.2 禁止字段（解析器直接拒绝）

```text
command
shell
script
sudo
pipe
redirect
postInstall
environment
workingDirectory
preInstall
```

任何目录出现这些字段 → 拒绝加载 + 提示用户「目录异常，请稍后重试」。

## 5. 风险等级

| 等级 | 含义 | UI 提示 |
| --- | --- | --- |
| `low` | 官方源 + Homebrew / mise | 绿色徽标 + 默认安装 |
| `medium` | 官方 PKG / DMG，需要用户授权 | 黄色徽标 + 明确告知需要授权 |
| `high` | 包含可疑行为（如修改 shell 配置） | 红色徽标 + 必须勾选确认框 |

v1.0.0 不允许出现 `high` 风险等级的工具。

## 6. 分类枚举

```text
editor
terminal
git-collaboration
node
python
go
rust
java
database
api-debug
docker
ai-coding
frontend
backend
devops
cli-utility
language-runtime
```

## 7. 启动能力（launchCapability）

```json
{
  "type": "cli",
  "command": "node",
  "openInTerminal": true
}
```

或：

```json
{
  "type": "app",
  "bundleID": "com.microsoft.VSCode"
}
```

或：

```json
{
  "type": "url",
  "url": "https://github.com"
}
```

或：

```json
{
  "type": "none"
}
```

## 8. 教程/视频引用（contentRefs）

```json
{
  "contentID": "nodejs-getting-started",
  "type": "article",
  "url": "https://nodejs.org/en/learn/getting-started/introduction-to-nodejs",
  "language": "en"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `contentID` | string | ✅ | 内容 ID（与 ContentItem 对应） |
| `type` | enum | ✅ | `article` / `video` / `docs` / `rss` |
| `url` | URL | ✅ | 原文链接（必须 HTTPS） |
| `language` | string | ✅ | BCP 47 |

## 9. 签名验证流程

```text
1. 解析 JSON
2. 验证 schemaVersion 与 App 内置版本匹配
3. 计算 canonical JSON（去除 keyID + signature）的 SHA-256
4. 用 keyID 在 PublicKeys/ 找到对应公钥
5. Ed25519 验签
6. 验证 expiresAt > now
7. 检查 revokedItems 中是否包含目标 tool.id
8. 通过 → 写入 SQLite 缓存
9. 失败 → 保留旧目录快照 + 提示用户
```

## 10. 演进策略

- `schemaVersion` 主版本变化 = 破坏性变更；App 必须升级
- 副版本变化 = 新增可选字段；旧 App 仍能加载
- 修订版本变化 = 修复；旧 App 仍能加载

## 11. 评审记录

| 日期 | 评审人 | 结果 | 备注 |
| --- | --- | --- | --- |
| 2026-08-09 | Coordinator (Mavis) | 初稿 | 阶段 2 实施前需子代理 A + 子代理 C 共同复核 |
