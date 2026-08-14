# Gate 1 — Catalog, Content & Security Audit Report

## 概要

**结论**：**BLOCKED**。Catalog/Content 安全模型在生产路径**完全失守**：ManifestSecurity 框架代码完整、测试充分，但在 4 个生产加载点（LocalCatalogLoader、RemoteCatalogLoader、RemoteContentLoader、CodingToolsApp 入口）**没有任何调用**。24 个 tool JSON 全部 `signature=""` + `keyID="0000000000000000"`；Content manifest 甚至没有 `signature` 字段。NpmGlobalAdapter 的 `curl | bash` 回退路径与"未签名"目录组合，构成 P0 级供应链风险。

---

## 1. 静态证据：签名与目录结构

### 1.1 Catalog/tools/ 24 个 tool JSON

```
所有 24 个 tool JSON：
  signature = ""
  keyID     = "0000000000000000"
  expiresAt = "2099-12-31T23:59:59Z"   ← 远期过期，签名验证缺位时无法拦截
```

`PROJECT_STATUS.md L134` 风险登记写「10 个 tools 全部 signature=''」，**实际为 24 个**（误差说明风险登记未及时更新）。

### 1.2 Catalog/content/v1.0.0.json

```json
{
  "schemaVersion": "1.0.0",
  "contentVersion": "2026.08.10-001",
  "createdAt": "2026-08-10T03:28:25Z",
  "expiresAt": "2026-11-10T03:28:25Z",
  "items": [ ... 21 条 ... ]
}
```

**没有 `signature` 字段、没有 `keyID` 字段**。Content manifest 在格式层不支持签名验证（与 CatalogSnapshot 不同，CatalogSnapshot 在 schema 中强制要求 keyID + signature 字段）。

### 1.3 Catalog/revocations/ — 空目录

```
$ ls Catalog/revocations/
(empty)
```

撤销列表机制在数据层不存在。

### 1.4 Catalog/schemas/catalog.schema.json

声明以下字段为 `required`：
- `schemaVersion`, `catalogVersion`, `createdAt`, `expiresAt`, `keyID`, `signature`, `tools`

但当前 24 个 tool JSON 的 `signature` 字段值是空字符串 `""` —— schema 校验不会拒空字符串（只要求字段存在），因此静态 schema 检查无法发现问题。**真正的检测需要运行时的 ManifestSecurity 验证（被绕过）**。

---

## 2. ManifestSecurity 实现与连接状态

### 2.1 ManifestSecurity 代码完整

`Apps/Mac/Sources/ManifestSecurity/ManifestSecurity.swift`：
- `Ed25519ManifestVerifier` 实现 `verify()`、`verifyPayload()`
- 完整错误类型：`unknownKey` / `signatureInvalid` / `signatureMalformed` / `expired` / `revoked` / `publicKeyMalformed`
- `ManifestCanonicalizer` 实现 canonical JSON
- `PublicKeyRegistry` + `BundlePublicKeyLoader`（从 `<keyID>.pub` 文件加载公钥）

### 2.2 测试完整

`Apps/Mac/Tests/ManifestSecurityTests/ManifestSecurityTests.swift` 覆盖：
- `testValidSignaturePasses`
- `testTamperedSignatureFails`
- `testSignatureBase64Malformed`
- `testEmptySignatureFails`  ← **关键**：证明代码会拒绝空签名
- `testWrongKeyIDFails`
- `testExpiredManifestRejected`
- `testSchemaVersionMismatch`

**静态层 evidence**: ManifestSecurity 框架本身能正确拒绝空签名 / 篡改 / 过期 / 未知 key —— 问题不在实现。

### 2.3 与生产加载链断开

```
$ rg -n "verifySnapshot|ManifestVerifying|verify\(|Ed25519ManifestVerifier|ManifestSecurity\." \
    Apps/Mac/Sources/Catalog Apps/Mac/Sources/Content Apps/Mac/Sources/App
(no output)
```

**零调用**。所有 loader 都没注入 verifier。

---

## 3. P0 发现详情

### P0-G1-1 — LocalCatalogLoader 无验签，构造假签名快照

**位置**：`Apps/Mac/Sources/Catalog/Catalog.swift:163-274`

**证据**：

```swift
public func loadCatalog() async throws -> CatalogSnapshot {
    let snapshots = try loadAllToolsFiles()       // L181：纯解码，无验签
    let merged = merge(snapshots)
    return merged
}

private func merge(_ snapshots: [CatalogSnapshot]) -> CatalogSnapshot {
    ...
    return CatalogSnapshot(
        ...
        keyID: "local-no-signature",   // L268: 写死假 keyID
        signature: "",                 // L269: 空签名
        tools: allTools,
        revokedItems: allRevoked
    )
}
```

源码注释自承「阶段 11 路径：ManifestSecurity 验证接入后，LocalCatalogLoader 走 verify 后再返回」（L161）—— **当前未接通**。

**影响**：
1. 用户从 Bundle 读取的 24 个 tool JSON 全部被视为已验证
2. `merge()` 主动伪造 `keyID="local-no-signature"` 制造"通过验签"假象
3. UI 后续看到的 CatalogSnapshot 与经过 Ed25519 验签后的 CatalogSnapshot 不可区分

### P0-G1-2 — RemoteCatalogLoader 无验签

**位置**：`Apps/Mac/Sources/Catalog/Catalog.swift:278-366`

**证据**：`decode(_:)` 仅校验 `schemaVersion`，无签名/过期/撤销检查：

```swift
private func decode(_ data: Data) throws -> CatalogSnapshot {
    let snapshot = try decoder.decode(CatalogSnapshot.self, from: data)
    guard snapshot.schemaVersion == expectedSchemaVersion else {
        throw CatalogError.schemaMismatch(...)
    }
    return snapshot                              // ← 直接返回
}
```

且 `CatalogError.signatureInvalid` / `.expired` / `.revoked` 已定义但**从未被任何 loader 抛出**（dead code）。

### P0-G1-3 — CodingToolsApp 用 `try?` 吞错

**位置**：`Apps/Mac/Sources/App/CodingToolsApp.swift:28-32`

```swift
appState.catalogProvider = {
    try? await LocalCatalogLoader().loadCatalog()
}
```

**影响**：若 loader 任何步骤失败（包括本应在验签后产生的 signatureInvalid），用户得到 `nil` → AppState 走 `loadError = nil`，`tools` fallback 到 `Tool.placeholderTools`（即 PROJECT_STATUS 风险登记提到的「10 个 placeholder」）。用户看到的是 10 个占位工具，**无法识别这是签名失败而非目录空**。

### P0-G1-4 — Content manifest 无签名能力

**位置**：`Catalog/content/v1.0.0.json`（无 signature 字段）；`ContentManifest` 结构定义于 `Apps/Mac/Sources/Content/Content.swift:64`

**证据**：
- JSON 中没有 signature/keyID
- ContentManifest 类型定义也未声明这些字段
- `RemoteContentLoader.swift` L96-99 只校验 `schemaVersion == "1.0.0"`，无验签调用

**影响**：Content manifest 在格式层不可签名。即使 ManifestSecurity 被接入，Content 仍无法保护。

### P0-G1-5 — NpmGlobalAdapter 走 `curl -fsSL <url> | bash` 回退

**位置**：`Apps/Mac/Sources/Installers/NpmGlobalAdapter.swift:78-91`

```swift
if let url = scriptURL {
    let result = try await executor.run(ProcessRequest(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "curl -fsSL \(url.absoluteString) | bash"],
        timeout: .seconds(900)
    ))
    ...
}
```

**触发链路**：
1. 用户在 UI 选 grok-build / hermes
2. Catalog 写入 `installOptions[0] = { type: "npm-global", url: "https://x.ai/cli/install.sh", riskLevel: "low" }`（grok-build.json L27-32）/ `https://raw.githubusercontent.com/.../install.sh`（hermes.json L29）
3. `InstallOption.toInstallAction()` 把 `url` 映射为 `scriptURL`
4. `NpmGlobalAdapter.execute` 在 npm 路径失败或缺 `packageName` 时回退到 `curl | bash`

**风险**：
1. 目录未签名（P0-G1-1/2）→ 攻击者替换 install.sh → 用户被诱导执行任意代码
2. `riskLevel: "low"` 误导 UI（按 plan Gate 4 应基于真实风险评估）
3. 即便目录签名接通，下载执行任意脚本本身就是 P0（plan Gate 2 L 153）

---

## 4. P1 发现

### P1-G1-1 — ManifestSecurity 框架与生产路径完全断开

**证据**：第 2.3 节搜索结果显示 `verifySnapshot|ManifestVerifying|verify\(|Ed25519ManifestVerifier|ManifestSecurity\.` 在 Catalog/Content/App 三个目录**零调用**。

**影响**：12 个 ManifestSecurityTests 全绿 ≠ 实际拦截空签名。在 CodingToolsApp 启动路径上，没有一行代码会触发 verifier。

### P1-G1-2 — revocations/ 目录为空

`Catalog/revocations/` 是空目录。即使将来接通验签，目前没有维护流程把被撤销的 tool ID 加入到此目录。`CatalogSnapshot.revokedItems` 字段存在，但来源是每个 tool JSON 文件内的 `revokedItems` 列表（24 个全部 `[]`），不是全局撤销源。

### P1-G1-3 — ManifestSecurity 默认 dev key 为空

`Apps/Mac/Sources/ManifestSecurity/ManifestSecurity.swift:135-136`：

```swift
public enum InMemoryPublicKeys {
    public static let developmentRegistry = PublicKeyRegistry(keys: [:])
}
```

注释：「默认 dev key；raw 32 字节。空数组也行，仅允许 manifest 测试失败模式。」

如果将来 production path 错误引用 `InMemoryPublicKeys.developmentRegistry`，所有签名都会被判 `unknownKey`，等同于关闭验证。需在交接记录中明确「production 必须走 `BundlePublicKeyLoader`，不得使用 `InMemoryPublicKeys`」。

### P1-G1-4 — CatalogError 枚举中的安全错误码未使用

`Apps/Mac/Sources/Catalog/Catalog.swift:21-23`：
```swift
case signatureInvalid
case expired
case revoked(toolID: String)
```

目前没有任何代码路径抛出这些错误。属于 dead code 但能编译过；后续接入验签时容易出现"类型已定义但调用方写错"的隐患。

---

## 5. Gate 1 矩阵（Plan §4 测试与行为矩阵）

| Fixture | 预期 | 实测 | 通过 |
|---|---|---|---|
| 有效签名、未过期、可信 key | verified 并可进入 decode | **无生产调用点** | ❌ 静态测试通过但 runtime 无效 |
| signature 为空 | rejected，不得显示为本地成功 | **production 把空签名当成 verified（merge() 主动伪造 keyID）** | ❌ |
| keyID 不存在 | rejected | 无验证 | ❌ |
| key 已撤销 | rejected，旧缓存也不可绕过 | 无验证 + revocations/ 为空 | ❌ |
| payload 被篡改 | rejected | 无验证 | ❌ |
| expiresAt 已过期 | rejected | **all 24 个 tools 都设 2099-12-31（远期），无验证时无法触发** | ❌ |
| schemaVersion 不支持 | rejected | RemoteCatalogLoader 有 schemaVersion 检查（通过） | ✅ |
| 网络断开 | 只使用已验证且未过期的缓存 | RemoteCatalogLoader 网络断开会回退到缓存，但缓存也未验签 | ❌ |
| 远程失败后 fallback | fallback 只能落到 verified 数据 | **fallback 到未验签的缓存** | ❌ |

**矩阵 9 项中 7 项失败**。

---

## 6. P0 条件复核（Plan §4 P0 条件）

| Plan P0 条件 | 触发？ | 证据 |
|---|---|---|
| 空签名被当作 verified | ✅ 是 | P0-G1-1: LocalCatalogLoader.merge 主动构造空签名快照 |
| 任意用户可控 URL 或本地内容无需签名进入安装器 | ✅ 是 | P0-G1-5: grok-build / hermes 的 url 字段直接进 curl \| bash |
| 过期或篡改 payload 仍展示安装按钮 | ✅ 是 | 24 个 tool JSON 都 2099-12-31 过期日 + 无验签 |
| loader 静默吞错并继续使用不可信数据 | ✅ 是 | P0-G1-3: CodingToolsApp.swift:31 `try?` |

**4 项 P0 条件全部命中**。

---

## 7. Gate 1 结论

| 维度 | 状态 |
|---|---|
| Catalog 签名验证 | **未接通（P0）** |
| Content 签名验证 | **格式层不支持（P0）** |
| LocalCatalog 路径 | **主动伪造 verified（P0）** |
| RemoteCatalog 路径 | **无验证（P0）** |
| NpmGlobalAdapter curl\|bash | **可达且 catalog 内容可注入（P0）** |
| ManifestSecurity 代码 | **存在但断开（P1）** |
| 撤销列表 | **空目录（P1）** |
| 生产路径异常处理 | **try? 吞错（P0）** |

**Gate 1 决定**：**BLOCKED**

后续 Gate（2-5）的可信度无法独立支撑：在不可信 Catalog 上做的任何前端/后端集成测试，都无法判定运行时是否安全。

**解除条件**（最小集）：
1. `CatalogSnapshot` / `ContentManifest` 的所有加载点（Local/Remote × Catalog/Content）接入 `Ed25519ManifestVerifier`
2. 24 个 tool JSON + Content manifest 用生产 Ed25519 私钥重新签名，公钥通过 Bundle 加载
3. `LocalCatalogLoader.merge()` 改为只 merge 已验签的快照，禁止 `keyID="local-no-signature"` 标记
4. `ContentManifest` 添加 signature/keyID 字段并重签
5. CodingToolsApp.swift:31 移除 `try?`，把 loader 失败透传到 UI 并显示「签名校验失败」
6. NpmGlobalAdapter 的 curl\|bash 回退策略：要么删除，要么改为 SHA256 校验 + 让用户在 UI 二次确认；不能仅靠目录签名就认为安全
7. riskLevel 字段需与实际行为匹配；grok-build / hermes 应标 `high` 或 `medium`

---

**Gate 1 审核结束。下一步：Gate 2（前后端接入和安装审核）。**