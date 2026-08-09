# Coding Tools · 安全威胁模型

> v1.0.0 目标：**零任意远程 Shell** + **签名化目录** + **强类型安装参数** + **结构化日志**。
> 本文档是所有安装路径、目录加载、日志、网络请求的审查基准。

## 1. 信任边界

```text
┌─────────────────────────────────────────────────────────┐
│  Coding Tools App（沙盒）                                │
│  ├─ UI（SwiftUI）                                        │
│  ├─ AppModel（业务编排）                                  │
│  ├─ Catalog（目录解析）                                    │
│  ├─ ManifestSecurity（签名/过期/撤销）                     │
│  ├─ Installers（Homebrew/mise/官方）                      │
│  ├─ ProcessExecution（受控进程）                          │
│  └─ Persistence（SQLite / 缓存）                         │
└─────────────────────────────────────────────────────────┘
        │                       │
        │ HTTPS（签名）         │ Process / NSWorkspace
        ▼                       ▼
┌──────────────────────┐  ┌──────────────────────────┐
│ 远程签名目录          │  │ Homebrew / mise / 官方包  │
│ GitHub Pages / CDN   │  │ 受白名单限制的子进程       │
└──────────────────────┘  └──────────────────────────┘
```

**不可信输入**：

- 远程目录 JSON（必须签名 + 校验）
- Homebrew 公式名 / Cask 名（仅来自签名目录）
- 官方安装包 URL（必须 HTTPS + SHA-256）

**可信来源**：

- 用户点击（UI 事件）
- 沙盒内 SQLite / Keychain

## 2. 威胁与缓解（STRIDE）

| 威胁 | 攻击路径 | 缓解 | 残余风险 |
| --- | --- | --- | --- |
| **Spoofing**（伪造工具） | 远程目录被中间人篡改，指向假工具 | HTTPS + Ed25519 签名 + Key ID 校验 | 私钥泄露（不在本文档范围，需线下管控） |
| **Tampering**（篡改安装包） | 下载的 DMG 被替换 | SHA-256 校验 + Apple 代码签名 | Apple Developer ID 私钥泄露 |
| **Repudiation**（抵赖） | 用户拒绝承认执行过的操作 | OperationLog 结构化记录 + 时间戳 | 日志被本地篡改（缓解：定期备份日志到只读位置） |
| **Information Disclosure**（信息泄露） | 日志中含 Token / 用户路径 | 自动脱敏（Token / Cookie / 环境变量 / 隐私路径） | 误关脱敏；Code Review 必查 |
| **Denial of Service**（拒绝服务） | 大目录 / 大量并发安装 | 队列 + 取消 + 超时 + 磁盘空间检查 | 网络/磁盘完全耗尽（用户需手动恢复） |
| **Elevation of Privilege**（权限提升） | 静默 sudo / 后台持久化 | 显式授权 + 沙盒 + 拒绝任意 Shell | 系统级漏洞（按 Apple 安全更新） |

## 3. 强类型安装参数（核心安全设计）

**禁止**通过字符串拼接构造任何 shell 命令。安装动作必须通过强类型 enum：

```swift
public enum InstallAction: Equatable, Sendable {
    case homebrewFormula(name: String)
    case homebrewCask(name: String)
    case miseTool(name: String, version: String?)
    case officialArtifact(
        url: URL,
        sha256: String,
        bundleID: String?,
        teamID: String?
    )
}
```

`ProcessExecution` 接收 `InstallAction` 后：

- Homebrew：`brew install <name>` 由 enum → 参数化调用，**不**走 `/bin/sh -c`
- mise：`mise use <tool>@<version>` 由 enum → 参数化调用
- 官方包：下载到 `~/Library/Caches/CodingTools/downloads/` → 校验 SHA-256 → 调用 `NSWorkspace` 打开 DMG / 解压 ZIP / 运行 PKG

任何新增安装来源必须：

1. 加入 enum case
2. 实现 `InstallAdapter` 协议
3. 写单元测试 + 集成测试
4. 写安全评审（不执行任意 shell、不静默 sudo、不写用户 shell 配置）

## 4. 目录 Schema 禁字段

远程目录 JSON **禁止**出现以下字段；解析器直接拒绝：

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
```

完整 schema 见 [CATALOG_SCHEMA.md](./CATALOG_SCHEMA.md)。

## 5. 签名与密钥轮换

| 阶段 | 算法 | Key ID | 轮换策略 |
| --- | --- | --- | --- |
| 目录签名 | Ed25519 | 8 字节 hex | 支持多 Key；过期 Key 在撤销列表中保留 90 天 |
| 安装包校验 | SHA-256 | — | 与官方同步更新；本地缓存旧哈希作为离线 fallback |
| 应用更新签名 | EdDSA (Sparkle) | 8 字节 hex | 与 Sparkle 工具链一致；私钥不入库 |

密钥存储：

- 公钥硬编码在 `App/Resources/PublicKeys/`（多 Key）
- 私钥保存在本地密码管理器（开发期）
- CI 中私钥通过 GitHub Secrets 注入

## 6. 网络白名单

App 仅允许访问以下域名（`NSAppTransportSecurity`）：

```text
github.com
*.githubusercontent.com
objects.githubusercontent.com
homebrew.org
raw.githubusercontent.com
api.github.com
（视频站只允许 iframe 嵌入，不允许 API Key 调用）
```

HTTP 明文请求：被 ATS 阻止；本地回环需要单独配置。

## 7. 日志脱敏规则

`ProcessExecution.redact(_:)` 规则：

- `Authorization: Bearer <token>` → `Authorization: Bearer ***`
- `https://user:pass@host` → `https://user:***@host`
- `~/Users/<name>/...` → `~/Users/***/...`
- `process.env.*` 整体替换为 `***`
- Homebrew tap URL 中的 token → `***`

任何新增脱敏规则必须：

1. 加入单元测试（10+ 个真实场景）
2. Code Review 验证
3. 加入 `docs/QA_MATRIX.md`

## 8. 进程执行边界

| 操作 | 允许方式 | 禁止方式 |
| --- | --- | --- |
| 调用 Homebrew | `Process` 直接传参数 | `/bin/sh -c "brew install <name>"` |
| 调用 mise | `Process` 直接传参数 | 字符串拼接 |
| 打开 DMG | `NSWorkspace.shared.open(dmgURL)` | 自定义解包逻辑 |
| 打开 URL | `NSWorkspace.shared.open(url)` | 私有 API |
| 写文件 | 仅限沙盒容器 | 写 `/usr/local` / `~/.zshrc` |
| 修改 PATH | 仅在 UI 提示用户手动改 | 程序直接修改 |

## 9. 撤销与降级

- **工具撤销**：目录 JSON 中 `revokedItems: ["tool-id-1"]`；UI 显示「已下架」
- **版本撤销**：`installOption.versionRule` 中标记 `blacklisted: ["1.2.3"]`
- **目录过期**：`expiresAt < now` → 只能浏览，不能安装
- **应用降级**：Sparkle 支持 delta 包；本地保留上一版本

## 10. 已知风险与接受

| 风险 | 接受原因 | 缓解 |
| --- | --- | --- |
| Homebrew 自身被供应链攻击 | Homebrew 是事实标准 | 信任 Homebrew 社区；不执行未审核的 tap |
| Apple Developer ID 私钥泄露 | Apple 控 | Apple 安全更新 |
| YouTube 嵌入内容被污染 | 视频内容变化不可控 | 仅元数据，UI 提示「来源不可控」 |
| 用户手动 `sudo` 装错工具 | 不在 App 控制内 | 文档提示；操作日志记录 |

## 11. 审查清单（每次发版前）

- [ ] 没有新增可执行任意 Shell 的路径
- [ ] 新增安装来源走 enum + adapter
- [ ] 日志脱敏覆盖新增场景
- [ ] 签名验证覆盖新增目录字段
- [ ] Bundle ID / Team ID 校验在所有官方包路径生效
- [ ] 没有把 API Key / 私钥写进代码或 commit
- [ ] 撤销列表已刷新
- [ ] 应用更新签名通过

## 12. 评审记录

| 日期 | 评审人 | 结果 | 备注 |
| --- | --- | --- | --- |
| 2026-08-09 | Coordinator (Mavis) | 初稿 | 阶段 0 验收前需 Reviewer + Security 子代理复核 |
