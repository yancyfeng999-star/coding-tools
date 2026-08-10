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
| 应用更新签名 | EdDSA (Sparkle) | 8 字节 hex | 与 Sparkle 工具链一致；私钥不入库；详见 §13 |

应用更新签名（Sparkle EdDSA）补充：

- 公钥在构建时通过 `PlistBuddy` 注入 `Info.plist` 的 `SUPublicEDKey`
- 占位符 `__SPARKLE_PUBLIC_KEY__` 永远不应包含真实公钥，避免被无意提交
- 私钥仅存在于本地密码管理器（开发期）与 GitHub Actions Secrets（CI 期）
- 公钥可公开；泄露不影响安全

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
| 2026-08-10 | 子代理 C (owner-release-update-security) | 阶段 7 补充 | 新增 §13 Sparkle EdDSA / Keychain / GitHub Actions Secrets / 风险登记 |

---

## 13. 阶段 7 — Sparkle 集成与发版安全

### 13.1 应用更新信任链

```text
┌──────────────────────┐     HTTPS       ┌──────────────────────────┐
│ Sparkle 调度循环     │ ─────────────► │ Appcast (GitHub Release) │
│ (SPUStandardUpdater) │                 │ appcast.xml              │
└──────────────────────┘                 │   ├─ sparkle:edSignature │
        ▲                                │   └─ <enclosure url/>   │
        │ EdDSA verify                   └──────────────────────────┘
        │ (SUPublicEDKey 硬编码)                       │
        ▼                                               ▼
   SUPublicEDKey                                ZIP / DMG (下载)
   (Info.plist 嵌入)                                    │
                                                        ▼
                                              Apple Code Signature
                                              + Hardened Runtime
                                              + Notarization
                                              + Staple
```

### 13.2 Sparkle Info.plist 注入

阶段 7 写入 `Apps/Mac/Sources/App/Info.plist` 的字段：

| Key | 类型 | 值 / 占位 | 说明 |
| --- | --- | --- | --- |
| `SUFeedURL` | string | `https://github.com/yancyfeng999-star/coding-tools/releases/latest/download/appcast.xml` | appcast 下载地址（HTTPS 必需） |
| `SUPublicEDKey` | string | `__SPARKLE_PUBLIC_KEY__`（构建期由 `release.sh` 注入） | EdDSA 公钥 base64 |
| `SUEnableAutomaticChecks` | bool | `true` | 默认开启自动检查 |
| `SUEnableAutomaticDownloading` | bool | `false`（v1.0 前不自动下载） | 用户必须显式触发下载 |
| `SUScheduledCheckInterval` | int | `86400` | 24 小时 |
| `SUAllowsAutomaticUpdates` | bool | `true` | Sparkle 提示重启安装 |
| `SUMinimumAutoupdateVersion` | string | `0.5.0` | 低于此版本强制走完整更新流 |

**注入流程**（`scripts/release.sh`）：

1. `release.sh` 校验 `SPARKLE_PUBLIC_KEY` 环境变量已设置
2. `inject_sparkle_pubkey` 用 PlistBuddy 替换占位符为真实公钥
3. `xcodebuild` 把 `Info.plist` 编入 `.app`（Mach-O 段也含一份）
4. `restore_sparkle_pubkey`（trap 保证失败时也执行）还原占位符
5. `git status` 不应显示 `Info.plist` 有变更

### 13.3 Keychain 导入（CI）

`release.yml` 导入 Developer ID Application 证书到临时 Keychain：

```bash
KEYCHAIN_PATH=$RUNNER_TEMP/build.keychain-db
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
echo "$MACOS_CERT_P12" | base64 --decode > $RUNNER_TEMP/cert.p12
security import $RUNNER_TEMP/cert.p12 -P "$MACOS_CERT_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security list-keychain -d user -s "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
```

**安全要点**：

- Keychain 文件位于 `$RUNNER_TEMP`（job 结束自动清理）
- `lut 21600` = 6 小时自动锁定
- `set-key-partition-list -S apple-tool:,apple:` 允许 codesign / notarytool 访问
- job 结束 `security delete-keychain` + `rm -f cert.p12` 强制清理

### 13.4 公证（notarytool + Staple）

```bash
# 1. 提交 ZIP（Sparkle in-app update 用）
xcrun notarytool submit CodingTools-1.0.0.zip \
  --keychain-profile "$KEYCHAIN_PROFILE" --wait

# 2. 提交 DMG
xcrun notarytool submit CodingTools-1.0.0.dmg \
  --keychain-profile "$KEYCHAIN_PROFILE" --wait

# 3. Staple（把公证票据嵌入文件，Gatekeeper 离线验证用）
xcrun stapler staple CodingTools-1.0.0.zip
xcrun stapler staple CodingTools-1.0.0.dmg

# 4. 验证
xcrun stapler validate CodingTools-1.0.0.zip
spctl --assess --verbose CodingTools-1.0.0.zip
```

`KEYCHAIN_PROFILE` 是本地预存的 notarytool 凭证：

```bash
# 本机一次性配置（不可提交）
xcrun notarytool store-credentials <profile-name> \
  --apple-id <apple-id> \
  --team-id <TEAMID> \
  --password <app-specific-password>
```

### 13.5 GitHub Actions Secrets 管理

| Secret | 用途 | 注入方式 | 轮换策略 |
| --- | --- | --- | --- |
| `MACOS_CERT_P12` | Developer ID Application 证书（base64） | `release.yml` `Import Signing Certificate` 步骤 | 证书有效期 5 年；到期前 60 天续 |
| `MACOS_CERT_PASSWORD` | P12 密码 | 同上 | 与证书同生命周期 |
| `KEYCHAIN_PASSWORD` | 临时 Keychain 密码 | 同上 | 每次 job 随机 |
| `KEYCHAIN_PROFILE` | notarytool profile 名 | `Build & Release` 步骤 `env` | profile 不变 |
| `DEVELOPER_ID` | `Developer ID Application: Name (TEAMID)` | `env` | 团队成员变化时更新 |
| `SPARKLE_PRIVATE_KEY` | EdDSA 私钥（base64 文本） | `Set Up Sparkle Keys` 步骤写文件 | **永久**；泄露则撤销旧 key 并发布新 key |
| `SPARKLE_PUBLIC_KEY` | EdDSA 公钥（base64） | `env` 注入 `release.sh` | 与私钥同步 |

**校验**：

```bash
# CI 中确认所有 secret 都已设置
gh secret list --repo yancyfeng999-star/coding-tools
# 必须包含：MACOS_CERT_P12 / MACOS_CERT_PASSWORD / KEYCHAIN_PASSWORD /
#          KEYCHAIN_PROFILE / DEVELOPER_ID / SPARKLE_PRIVATE_KEY / SPARKLE_PUBLIC_KEY
```

**禁止**：

- 把任何 secret 写进 commit / 注释 / log 输出
- 在 PR 触发的工作流中打印 `${{ secrets.* }}` 的值
- 把 SPARKLE_PRIVATE_KEY 同步到本地以外的机器

### 13.6 Sparkle EdDSA 签名流程

```text
[发版机]                                       [Sparkle 工具链]
   │                                                  │
   │ 1. generate_keys  → ed25519_private_key          │
   │ 2. 公钥 base64 → SPARKLE_PUBLIC_KEY              │
   │ 3. release.sh 注入 SUPublicEDKey                 │
   │ 4. xcodebuild → .app                             │
   │ 5. sign_update ZIP → ZIP + .sig                  │
   │ 6. generate_appcast → appcast.xml                │
   │    └─ <enclosure> + <sparkle:edSignature/>       │
   │ 7. gh release create  → GitHub Release           │
   │                                                  │
                                                    [用户 App]
                                                       │
                                                       ▼
                                              [SPUUpdater]
                                              1. GET appcast.xml
                                              2. 校验 EdDSA 用 SUPublicEDKey
                                              3. 下载 ZIP
                                              4. 验 Apple codesign
                                              5. 提示用户安装
```

### 13.7 风险登记（扩充）

| ID | 风险 | 检测 | 缓解 | 接受条件 |
| --- | --- | --- | --- | --- |
| R-01 | 签名失败：证书过期 / Keychain 未解锁 / 私钥缺失 | `sign-release.sh` 退出码非 0 | 检查 `DEVELOPER_ID` + Keychain 状态；证书到期前 60 天续 | 5 年周期，提示窗口足够 |
| R-02 | 公证失败：签名无效 / hardened runtime 缺 / entitlements 问题 | `notarytool submit` 返回 `Rejected` | `xcrun notarytool history <submission-id>` 查看 Apple 详细日志；修复后重提（不删 tag） | 每次都重试直至通过 |
| R-03 | Staple 失败：网络中断 / Apple 服务异常 | `stapler staple` 退出码非 0 | 重新 `submit --wait` 后重 staple；离线 Gatekeeper 不能验证 | 24h 内手动验证 |
| R-04 | EdDSA 私钥泄露 | git log / 第三方监控告警 | 立即轮换：`generate_keys` 生成新 key → 旧 key 加入 Sparkle 撤销列表 → 走 hotfix 发版 | 无 |
| R-05 | SUPublicEDKey 占位符被无意提交 | `git status` / CI lint | `release.sh` 的 `trap restore_sparkle_pubkey EXIT`；CI 加 `git diff --exit-code Apps/Mac/Sources/App/Info.plist` 检查 | 占位符必须始终是 `__SPARKLE_PUBLIC_KEY__` |
| R-06 | CI Keychain 文件残留到下一 job | runner 临时目录 | `$RUNNER_TEMP` 自动清理 + `if: always()` 显式 `delete-keychain` + `rm -f cert.p12` | ephemeral runner 默认行为 |
| R-07 | 自动更新推送恶意版本 | Sparkle EdDSA 校验 | 私钥绝不外泄；多 Key 支持期内新版本必须用当前活跃 key 签名 | 无 |
| R-08 | Appcast URL 域被劫持 | TLS 证书钉扎 | SUFeedURL 硬编码 `github.com`；HTTP fallback 被 ATS 拒绝 | 无 |
| R-09 | 在 feature 分支意外发版 | release.yml 触发条件 | 只在 `tags: ['v*']` 触发；`workflow_dispatch` 需手动 + 二次确认 | 无 |
| R-10 | gh release 资产上传失败 | `gh release create` 退出码 | `gh release upload vX.Y.Z <asset>` 重试；不删 tag | 单次发版可重试 3 次 |

### 13.8 阶段 7 审查清单（每次发版前）

- [ ] `SPARKLE_PRIVATE_KEY` 在 GitHub Secrets 中存在
- [ ] `SPARKLE_PUBLIC_KEY` 与本地 `ed25519_private_key` 配对（用 `generate_keys --show` 验）
- [ ] `DEVELOPER_ID` 与 Apple Developer Portal 一致
- [ ] `KEYCHAIN_PROFILE` 在 `xcrun notarytool list-credentials` 中可见
- [ ] `MACOS_CERT_P12` 证书有效期 > 30 天
- [ ] `Info.plist` 中 `SUPublicEDKey` 是 `__SPARKLE_PUBLIC_KEY__`（不是真实 key）
- [ ] `Info.plist` 中 `SUFeedURL` 是 HTTPS GitHub Releases URL
- [ ] `LSMinimumSystemVersion` ≥ 14.0
- [ ] entitlements 包含 `com.apple.security.network.client`
- [ ] 没有在 PR / commit message / log 中打印任何 secret
- [ ] 测试机装旧版本可成功拉取新版本

