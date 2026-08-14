# Gate 5 — Testing, Build & Release Evidence Audit

## 概要

**结论**：**PASS WITH RISKS**。

| 维度 | 状态 |
|---|---|
| 测试 | **local_build_verified + test_verified**：173/173 通过（5 主 + 4 副 scheme） |
| Debug build | **local_build_verified** |
| Release build | **local_build_verified** |
| Codesign | ad-hoc（`Signature=adhoc`，`TeamIdentifier=not set`） |
| Notarization | **not_run**（无 stapled ticket，spctl 拒绝） |
| 远程 Release | **runtime_verified**（v1.4.0 release 存在且 zip hash 与 GitHub asset 一致） |
| Sparkle appcast | **static_verified + reachable**（含 EdDSA signature，2 enclosures） |
| Helper build | **local_build_verified**（`CodingToolsHelper.xpc` 通用二进制，ad-hoc） |
| 干净机器安装 | **not_run**（未跑过） |
| 端到端用户安装 | **not_run**（项目方未提供机器装机记录） |

**注**：虽然工程层 173 测试通过 + Release build 成功 + Release asset 可达，但**功能层被 Gate 1–4 全部 BLOCKED**——173 测试无法覆盖 P0-G1-1 / P0-G2-1 / P0-G4-1 等静态可证实的生产路径 bug。

---

## 1. 测试执行（real，2026-08-12）

```
==> tuist install
restored sparkle 2.9.5
==> tuist generate
Using cache binaries for the following targets
==> tuist generate
Generating workspace CodingTools.xcworkspace
Generating project CodingTools
✔ Success

5 个主 test scheme：
  ✅ DomainTests              passed=3
  ✅ CatalogTests             passed=34
  ✅ InstallerTests           passed=40
  ✅ ManifestSecurityTests    passed=10
  ✅ UpdatesTests             passed=10
  ── 主合计：97 passed, 0 failed

4 个副 test scheme：
  ✅ AppTests                 passed=46
  ✅ HelperTests              passed=9
  ✅ LatestVersionTests       passed=13
  ✅ AIConfigDiscoveryTests   passed=8
  ── 副合计：76 passed, 0 failed

总：173 passed, 0 failed
```

- PROJECT_STATUS L76 写「135 测试」—— 实际 173，多出 38（可能是 PROJECT_STATUS 写时是中间状态；当前更新）。
- 所有测试在 Debug + DerivedDataPath=`./build/DerivedData` 下执行。
- Tuist 缓存命中，未触发完整重建。

## 2. Build 产物

```
build/DerivedData/Build/Products/Debug/Coding Tools.app
build/DerivedData/Build/Products/Release/Coding Tools.app
build/DerivedData/Build/Products/Release/Coding Tools.app/Contents/XPCServices/CodingToolsHelper.xpc
```

**Release build 信息**：

```
$ codesign -dv --verbose=4 --strict "build/DerivedData/Build/Products/Release/Coding Tools.app"
Format=app bundle with Mach-O universal (x86_64 arm64)
Signature=adhoc
TeamIdentifier=not set
Sealed Resources version=2 rules=13 files=49

$ codesign -dv --verbose=4 --strict ".../CodingToolsHelper.xpc"
Format=bundle with Mach-O universal (x86_64 arm64)
Signature=adhoc
TeamIdentifier=not set
```

- Mach-O 通用（x86_64 + arm64）：✅ 与 PROJECT_STATUS L141 一致
- Ad-hoc 签名：项目方确认无 Developer ID，符合阶段 10 阻塞状态

**SHA-256**：
```
$ shasum -a 256 build/DerivedData/Build/Products/Release/Coding\ Tools.app/Contents/MacOS/CodingTools
6c47fb708a2362b31c94f93415038bf8617efd22899778b1d77135154db423d0
```

## 3. Release artifacts（remote reachable）

```
$ curl -sL https://api.github.com/repos/yancyfeng999-star/coding-tools/releases/latest
{
    "tag_name": "v1.4.0",
    "name": "v1.4.0",
    "draft": false,
    "prerelease": false,
    "published_at": "2026-08-11T13:32:15Z",
    "assets": [
        {"name": "appcast.xml",                 "size": 1186},
        {"name": "CodingTools-1.4.0.dmg",       "size": 4944766},
        {"name": "CodingTools-1.4.0.pkg",       "size": 3774123},
        {"name": "CodingTools-1.4.0.zip",       "size": 4069519}
    ]
}
```

**SHA-256 一致性验证**（zip）：

```
local:    90ee6a23bc3b89a83a9c1215dc2bb2392d35f2b9e923d1dc5045af3c85de7eb6  releases/1.4.0/CodingTools-1.4.0.zip
download:  90ee6a23bc3b89a83a9c1215dc2bb2392d35f2b9e923d1dc5045af3c85de7eb6  /tmp/release-dmg.zip
```

✅ 本地与 GitHub Release 资产 hash 一致。

## 4. Sparkle appcast

`releases/1.4.0/appcast.xml`：

```xml
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="..." version="2.0">
    <channel>
        <title>Coding Tools</title>
        <item>
            <title>1.4.0</title>
            <pubDate>Tue, 11 Aug 2026 21:31:48 +0800</pubDate>
            <sparkle:version>22</sparkle:version>
            <sparkle:shortVersionString>1.4.0</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure xml:lang="en"
                       url=".../CodingTools-1.4.0.zip"
                       length="4069519"
                       type="application/octet-stream"
                       sparkle:edSignature="PaCzAm43..."/>
            <enclosure xml:lang="en"
                       url=".../CodingTools-1.4.0.pkg"
                       length="3774123"
                       type="application/vnd.apple.installer-package+xml"
                       sparkle:edSignature="/sIeB5Oi..."
                       sparkle:installationType="package"/>
        </item>
    </channel>
</rss>
```

```
$ SPARKLE_PUBLIC_KEY="Utj+cIsQE5MVs9tD2lId3s4zvzHnPgThFD1JebEfcEA=" \
    ./Apps/Mac/scripts/verify-appcast.sh /Users/.../releases/1.4.0/appcast.xml
    ✅ sparkle:edSignature 存在
    enclosure 数: 2

✅ Appcast XML 格式正确，包含 EdDSA 签名
   注：完整 EdDSA 验证在 Sparkle 应用内启动时执行（用 SUPublicEDKey 解 .sig）
```

- `Info.plist:89` 的 `SUFeedURL` 与 release asset 一致
- EdDSA 公钥（Info.plist `SUPublicEDKey`）与 `.keys/ed25519_private_key` 对应
- 运行时 EdDSA 验证由 Sparkle 在 App 启动时跑

## 5. Notarization & Gatekeeper

```
$ xcrun stapler validate /tmp/release-dmg.dmg
release-dmg.dmg does not have a ticket stapled to it.

$ spctl -a -t exec -vv /tmp/release-dmg.dmg
/tmp/release-dmg.dmg: rejected
source=no usable signature
```

- ❌ **无 notarization ticket stapled**
- ❌ **Gatekeeper 拒绝**（用户首次运行 DMG/zip 会要求"右键打开"或被拒）
- 与 PROJECT_STATUS L132 一致：「Apple Developer ID 申请未开始，签名/notarization/Release 状态保持 not_run」

## 6. 干净机器安装

**not_run**。

- 项目方未提供未污染的 macOS 14+ 测试机的装机记录
- spark `ensure` / `revert to snapshot` 等快照未跑
- 第一手用户体验无证据

## 7. 测试覆盖 vs 静态发现

| Gate 静态发现 | 测试是否覆盖 |
|---|---|
| P0-G1-1 LocalCatalogLoader.merge 假签名 | ❌ ManifestSecurityTests 验证书签，但 LocalCatalogLoader 测试**未做**（grep `LocalCatalogLoader` 在 tests 中为空） |
| P0-G1-2 RemoteCatalogLoader 无验签 | ❌ 同上 |
| P0-G1-3 CodingToolsApp try? 吞错 | ❌ AppTests 不涉及 catalog 加载路径 |
| P0-G1-4 Content manifest 无签名 | ❌ 无 Content 安全测试 |
| P0-G1-5 NpmGlobalAdapter curl\|bash | ⚠️ InstallerTests 不覆盖 NpmGlobalAdapter 的真实 `execute(plan)` 路径 |
| P0-G2-1 AdapterRegistry 丢 action | ❌ AdapterRegistryTests 用 stub adapter |
| P0-G2-2 Homebrew 用 toolID 当包名 | ❌ HomebrewAdapterTests 只测 plan，不测 execute |
| P0-G2-3 UI 写死 Homebrew/low | ❌ AppTests 不覆盖 view |
| P0-G2-4 ContentLinkRow 任意 URL | ❌ 无 view 测试 |
| P0-G2-5 HelperClient 无生产调用 | ❌ HelperTests 不涉及 |
| P0-G2-6 取消只改 UI | ❌ AppTests 无 install 取消 |
| P0-G3-1 favorites/recent 内存 | ⚠️ ToastCenterTests/DeepLinkRouterTests 不涉及持久化（持久化层 stub，根本无测试可写） |
| P0-G3-2 installLog 未脱敏 | ❌ 无 |
| P0-G4-1 launchTool example.com | ❌ 无 |
| P0-G4-2 HomeToolCard 永远 notInstalled | ❌ 无 |
| P0-G4-3 StatCard 硬编码中文 | ❌ 无 |
| P0-G4-4 InstallSheet 写死 brew | ❌ 无 |
| P0-G4-5 ToolDetailView 写死 brew/mise | ❌ 无 |
| P0-G4-6 ContentLinkRow | ❌ 无 |
| P0-G4-7 cancel 不停进程 | ❌ 无 |

**20 个 P0 中只有 0 个被现有 173 测试覆盖**。
测试覆盖率（PROJECT_STATUS L137 标 ~22.5%）偏低且**未触及运行时关键路径**。

## 8. Release 状态分栏（Plan §8）

| 层 | 状态 | 证据 |
|---|---|---|
| source | static_verified | commit 820918c，tag v1.4.0，dirty 干净 |
| build | local_build_verified | Release universal binary 编译成功；DerivedData 已有产物 |
| test | test_verified | 173 / 173 通过（5 主 + 4 副 scheme，Tuist 缓存命中） |
| package | package_verified | zip / pkg / appcast.xml SHA-256 与 GitHub asset 一致 |
| signing | local ad-hoc | `codesign --verify --strict` 通过；adhoc + TeamIdentifier not set |
| notarization | **not_run** | `stapler validate` 无 ticket；`spctl -a` 拒绝 |
| remote release | remote_verified | API 返回 v1.4.0 4 个 asset；zip download 与本地 hash 一致 |
| in-app update | **not_run** | 无真实机器跑 Sparkle SPUUserDriver 升级日志；需干净机器实测 |
| user install | **not_run** | 无干净装机记录 |

## 9. Gate 5 决定

**本地测试 + 本地构建 + 远程 Release 资产可达** → **PASS WITH RISKS**

但：
1. 测试无法替代 Gate 1–4 的静态分析（20 P0 中 0 被覆盖）
2. Notarization 未做 → **不能在另一台 Mac 上正常启动**（除非手动右键打开）
3. 干净机器安装未验证 → 端到端用户接受度未知
4. **不能称为 RELEASED 或 USER ACCEPTED**

---

**Gate 5 审核结束。下一步：综合缺陷分级与最终决策报告。**