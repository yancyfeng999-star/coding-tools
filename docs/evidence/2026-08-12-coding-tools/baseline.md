# Gate 0 Baseline — Coding Tools Independent Review

- **Review date**: 2026-08-12
- **Reviewer**: Independent Reviewer (automated execution)
- **Project path**: /Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools
- **Branch**: main
- **HEAD commit**: 820918c (`release: v1.4.0 (build 22)`)
- **Tag**: v1.4.0
- **macOS**: 26.6.1 (Build 25G76)
- **Architecture**: arm64
- **Xcode**: 26.6 (Build 17F113)
- **Initial git status**: only `?? docs/superpowers/` untracked (this plan), clean otherwise
- **Final git status**: same as initial (Gate 0 only runs read-only commands)

---

## A. 范围与版本对照

| 来源 | 字段 | 值 | 状态 |
|---|---|---|---|
| git tag | tag | v1.4.0 | ✅ 与 HEAD 一致 |
| Info.plist | CFBundleShortVersionString | 1.4.0 | ✅ 与 tag 一致 |
| Info.plist | CFBundleVersion | 22 | ✅ |
| Info.plist | CFBundleIdentifier | $(PRODUCT_BUNDLE_IDENTIFIER) | static |
| Info.plist | LSMinimumSystemVersion | 14.0 | static |
| Info.plist | LSUIElement | true | **异常**：菜单栏 App，但 Info.plist 同时声明为完整 APPL 包（`CFBundlePackageType=APPL`），需运行时确认 |
| Info.plist | SUPublicEDKey | Utj+cIsQE5MVs9tD2lId3s4zvzHnPgThFD1JebEfcEA= | ✅ EdDSA 公钥存在 |
| Info.plist | SUFeedURL | https://github.com/yancyfeng999-star/coding-tools/releases/latest/download/appcast.xml | ✅ |
| Info.plist | NSAppTransportSecurity | githubusercontent.com + homebrew.org 例外，禁任意加载 | ✅ |
| Info.plist | CFBundleLocalizations | en, zh-Hans, ja, ko, fr, de, es | ✅ 7 种 |
| Info.plist | CFBundleURLSchemes | codingtools:// | ✅ |
| Project.swift | name | CodingTools | ✅ |
| PROJECT_STATUS.md | 阶段 | v1.5.0 阶段 9 + 12 起步 | ⚠️ 与 tag/Info.plist 不一致 |
| PROJECT_STATUS.md | 当前版本声明 | v1.5.0-rc1 | ⚠️ 与 Info.plist 1.4.0 不一致 |
| CHANGELOG.md | 最新发布段 | [1.4.0] - 2026-08-11 | ✅ |
| CHANGELOG.md | XPC Helper 描述所在版本 | [1.2.5] - 2026-08-11 | ⚠️ 编号与 PROJECT_STATUS 的「v1.5.0-rc1」不对应；CHANGELOG 段名版本号与内容所属阶段不匹配 |

---

## B. Scheme 与测试架构

**xcschemes 清单（共 27 个，含 1 个 workspace scheme）**：
- App: `CodingTools`, `CodingToolsHelper`, `CodingTools-Workspace`
- 主测试 scheme: `CodingTools`（含 6 个 Testables：DomainTests/CatalogTests/InstallerTests/ManifestSecurityTests/UpdatesTests/AppTests）
- 单独测试 scheme: `AppTests`, `DomainTests`, `CatalogTests`, `InstallerTests`, `ManifestSecurityTests`, `UpdatesTests`, `HelperTests`, `LatestVersionTests`, `AIConfigDiscoveryTests`
- 非测试 scheme: `AIConfigDiscovery`, `Catalog`, `Content`, `Detection`, `Domain`, `Launching`, `Localization`, `ManifestSecurity`, `Persistence`, `ProcessExecution`, `Theme`, `Updates`

**Project.swift 关键定义**（lines 384–455）：
- `CodingTools` scheme 包含 6 个 Testable（DomainTests / CatalogTests / InstallerTests / ManifestSecurityTests / UpdatesTests / AppTests）
- `run-tests.sh` 注释明确说明：`AppTests 暂不通过 CodingTools scheme 跑（LSUIElement CLI 启动失败），单独跑`
- 因此 `run-tests.sh` 应跑 5 个 unit test scheme + AppTests 单独跑

**审核记录**：
- [x] CodingTools scheme 的 Testables 包含 6 个测试目标，**不是空集合**（仅 CodingTools.xcodeproj/xcshareddata/xcschemes/CodingTools.xcscheme 静态检查显示 `<Testables></Testables>` 空，但 Tuist 生成路径下 Project.swift 重新注入 — 静态空可能误导，需在测试阶段实际跑 CodingTools scheme 验证 Testables 真值）
- [x] 27 个 scheme 名称与 Project.swift 一致
- [x] run-tests.sh 在 Phase 7 改为「按需 build」（不再预先 build CodingTools scheme）

---

## C. 已知与文档声明的风险

摘自 `PROJECT_STATUS.md` 风险登记（lines 130–143）：

| 风险 | 项目方标记 | 描述 | 审核关注 |
|---|---|---|---|
| Apple Developer ID 申请 | 🔴 未开始 | 阶段 10 阻塞 | 决定签名/notarization/Release 状态 |
| **Sandbox 关闭** | 🔴 v1.0.0 起一直未恢复 | 阶段 9 引入 XPC Helper 后再开 | **P0**：App 在生产路径以非 sandbox 进程运行，NPM/Helm/HTTP 命令直接由 App 进程执行 |
| **目录签名未接通** | 🔴 10 个 tools 全部 signature="" | 阶段 11 待接 CatalogLoader | **P0 待 Gate 1 验证**：空签名是否被当作 verified |
| Post-release 闭环缺失 | 🔴 | 阶段 12 部分启动 | 阶段 12 二期未完成 |
| Catalog 工具数 | 🟡 当前 10 / 承诺 20–30 | CHANGELOG [1.2.5] 提到「24 工具」，与风险登记矛盾（数据漂移） | P2 |
| 测试覆盖率 ~22.5% | 🟡 偏低 | — | 不影响 Gate 判定但需记录 |
| Sparkle 端到端更新未真实验证 | 🟡 release 成功 ≠ 用户装机成功 | — | Gate 5 待验证 |
| Apple Silicon / Intel 兼容性 | 🟢 Universal Binary（arm64+x86_64） | — | Gate 5 build 时核对 |
| macOS 14+ 兼容性 | 🟢 LSMinimumSystemVersion 14.0 | — | 当前 26.6.1 已满足 |

**核心矛盾**：
1. PROJECT_STATUS 风险登记写「10 个 tools 全部 signature=""」与 CHANGELOG [1.2.5] 写「24 工具」冲突，需 Gate 1 数 Catalog 实际文件。
2. PROJECT_STATUS 阶段 2 标 ✅ 已完成，但同文件阶段 11 与风险登记均说目录签名未接通 — **同文档内自相矛盾**，需要在 Gate 1 读源码判定 ManifestSecurity 是否接到 CatalogLoader。
4. PROJECT_STATUS 写「当前版本 v1.5.0-rc1」，但 tag 与 Info.plist 都是 v1.4.0 — 阶段 9 起步但未发版，需在交接记录中标 not_run。

---

## D. 项目方声称完成与本次审核范围的差异

| 项目方声称 | 本次审核范围 | 处理方式 |
|---|---|---|
| 14 framework + 5 unit test target + 1 .app | 实际 14 framework + 9 test target | ✅ 实际超出声称 |
| Sparkle 端到端发版脚本 release.sh 完整 | 不在本计划内；仅审查 Sparkle 配置存在性 + appcast 签名 | Gate 5 验证 appcast 签名 + Release 资产可达性 |
| XPC Helper 架构就位 | 仅静态检查 Helper 协议与 HelperClient 存在性 + 生产路径接通 | Gate 2 重点验证 |
| Catalog 24 工具 | Gate 1 数实际 JSON + 验证每条 toolID 唯一、签名存在 | 必跑 |
| 135 测试 | Gate 5 实际跑测试 + 记录 pass/fail 数量 | 必跑 |
| Crash 本地落盘 | 不在 Gate 1–5 显式范围内；可在 Gate 4 抽样验证 | 抽样 |
| Apple Developer ID 申请未开始 | **不可在本次审核内推进**；签名/notarization/Release 状态保持 not_run | 显式记录 |
| 目录签名未接通 | **Gate 1 的最高优先级项** | 必跑 |

---

## E. Gate 0 通过条件自检

- [x] 记录绝对项目路径、branch、HEAD、tag、版本和 build
- [x] 记录初始 dirty 文件（只有 `docs/superpowers/`）
- [x] PROJECT_STATUS.md、CHANGELOG.md、Info.plist、Project.swift 互相比较
- [x] CodingTools scheme 的 Testables（Project.swift 路径）确认非空；xcscheme 静态文件显示为空需在 Gate 5 实际跑测试时二次确认
- [x] 阶段 11「目录签名未接通」是同文档内自指 P0 风险 → Gate 1 最高优先

---

## F. Gate 0 临时发现的 P1/P2 清单（送交 Gate 1+ 复核）

| 编号 | 类型 | 描述 | 出处 | 处理 |
|---|---|---|---|---|
| F-G0-1 | P1 | PROJECT_STATUS 称当前版本 v1.5.0-rc1，Info.plist/tag/CHANGELOG 都是 v1.4.0，文档与发布物不一致 | PROJECT_STATUS.md L9、L124 vs CHANGELOG L11、Info.plist | 写交接报告标版本漂移；不阻塞 Gate 0 |
| F-G0-2 | P1 | 同文档内 PROJECT_STATUS 阶段 2 标 ✅，但阶段 11 标 ⬜，风险登记写「目录签名未接通 🔴」 | PROJECT_STATUS.md L18、L27、L134 | 送 Gate 1 复验 ManifestSecurity 是否接到 CatalogLoader |
| F-G0-3 | P1 | PROJECT_STATUS 风险登记写「10 个 tools」，CHANGELOG [1.2.5] 写「24 工具」 | PROJECT_STATUS.md L136、CHANGELOG L21 | Gate 1 数 Catalog 实际 JSON 数 |
| F-G0-4 | P1 | NpmGlobalAdapter 仍未走 HelperClient（NPM 安装仍在 App 进程内执行） | PROJECT_STATUS.md L79、L85-87 | Gate 2 验证 NpmGlobalAdapter.execute 实际调用链 |
| F-G0-5 | P1 | Apple Developer ID 申请未开始，签名/notarization/Release 全部阻塞 | PROJECT_STATUS.md L132 | Gate 5 显式 not_run |
| F-G0-6 | P2 | CodingTools.xcscheme（xcodeproj 静态文件）`<Testables></Testables>` 为空；Tuist 生成路径重新注入 — 但若不跑 Tuist generate 直接用 Xcode open，Testables 缺失 | xcscheme vs Project.swift 不一致 | Gate 5 跑测试前确认 tuist generate 已执行 |
| F-G0-7 | P2 | Info.plist LSUIElement=true 但 CFBundlePackageType=APPL；需要确认运行行为是菜单栏附加还是完整 App | Info.plist L30-43 | Gate 4 运行时确认 |
| F-G0-8 | P2 | CHANGELOG [1.2.5] 日期 2026-08-11，[1.4.0] 日期也是 2026-08-11，同日两个版本 | CHANGELOG L11、L17 | 不影响行为，但版本号跳跃需标 P2 |

---

## G. Gate 0 通过判定

| 维度 | 状态 | 备注 |
|---|---|---|
| 范围、版本、可复现性 | **static_verified** | 版本号未对齐但范围清楚；可复现环境就位 |
| 已知 P0 风险 | **已识别** | Sandbox 关闭 + 目录签名未接通 → Gate 1/2 必查 |
| 测试架构 | **static_verified** | 27 schemes 齐全，6 测试目标在 CodingTools scheme 内 |
| 文档一致性 | **存在 P1 漂移** | 不阻塞 Gate 0，但送 Gate 1+ 复核 |

**Gate 0 通过**：可以进入 Gate 1（Catalog、Content 和安全审核）。
Gate 1 必须重点验证 PROJECT_STATUS L134「10 个 tools 全部 signature=""」与 L27「阶段 11 未开始」是否在源码中表现为：
- LocalCatalogLoader / RemoteCatalogLoader 是否真的把空 signature 当 verified；
- ManifestSecurity / ManifestCanonicalizer 是否被任何 loader 调用；
- CodingToolsApp 是否把 catalog 失败降级为空目录或默认成功。

---

**Gate 0 审核结束。下一步：Gate 1。**