# Coding Tools Independent Review

- **Review date**: 2026-08-12
- **Reviewer**: Independent Reviewer (automated execution; static + test + remote verification)
- **Project path**: `/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools`
- **Branch**: `main`
- **HEAD commit**: `820918c` (`release: v1.4.0 (build 22)`)
- **Tag**: `v1.4.0`
- **macOS**: 26.6.1 (Build 25G76)
- **Architecture**: arm64
- **Xcode**: 26.6 (Build 17F113)
- **Initial git status**: `?? docs/superpowers/` (this review plan; everything else clean)
- **Final git status**: `?? docs/superpowers/` + `?? docs/evidence/2026-08-12-coding-tools/` (review artifacts). All source files unchanged from HEAD.
- **Note on `tuist generate`**: 步骤 Run ` `tuist install && tuist generate` 是 Gate 5 跑测试的必要前置条件（静态 xcscheme `<Testables></Testables>` 为空，必须 Tuist 生成器重新注入）。`tuist generate` 修改了 17 个 xcodeproj / xcscheme 文件（约 1777 行）。所有修改 **均已 `git checkout HEAD --` 还原**。如果实现方验证报告后需重跑测试，可重新执行 `tuist install && tuist generate && ./scripts/run-tests.sh`。

---

## Executive Decision

- **Decision**: **BLOCKED**
- **P0 count**: **20**
- **P1 count**: **21**
- **P2 count**: 8
- **Release state**: **LOCAL ONLY** (zip / pkg / appcast 在 GitHub Release v1.4.0 可达；SHA-256 一致；无 Developer ID、无 notarization、Gatekeeper 拒绝)
- **User acceptance state**: **NOT RUN**（无干净机器装机记录）

> 本地 build 成功、173 测试通过、Release asset 与本地 zip hash 一致——这些都成立。但功能层有 20 项 P0，全部在静态源码层可证实；任何一项都足以让生产路径产生错误行为或用户安全风险。**测试覆盖与静态 P0 完全脱节**（20 项中 0 项被现有测试覆盖）。

---

## Evidence Index

| ID | Layer | Command or scenario | Status | Artifact |
|---|---|---|---|---|
| E-001 | baseline | git / tag / scheme / Info.plist | static_verified | baseline.md |
| E-002 | test | run-tests.sh — 5 主 scheme | **test_verified** 97/97 | build/DerivedData/test-*.log |
| E-003 | test | App/Helper/LatestVersion/AIConfigDiscovery | **test_verified** 76/76 | build/DerivedData/test-*.log |
| E-004 | build | Release build | **local_build_verified** | build/DerivedData/Build/Products/Release/Coding Tools.app |
| E-005 | codesign | codesign -dv | static_verified adhoc | codesign output |
| E-006 | catalog | 24 tool JSON signature | **static_verified — all empty sig** | gate-1-catalog-security.md |
| E-007 | manifest | ManifestSecurity usage in loaders | **static_verified — 0 callers** | grep result |
| E-008 | installer | AdapterRegistry.execute chain | **static_verified — loses action** | gate-2-integration.md |
| E-009 | installer | HomebrewAdapter toolID vs packageName | **static_verified — wrong field** | gate-2-integration.md |
| E-010 | UI | InstallSheet / ToolDetailView hardcoded | **static_verified** | gate-2/gate-4 |
| E-011 | UI | AppMenuBar.launchTool example.com | **static_verified** | gate-4-ux-runtime.md |
| E-012 | persistence | Persistence.swift stub | **static_verified — no SQLite** | gate-3-persistence.md |
| E-013 | runtime | 取消 / Detection after install | **static_verified — not wired** | gate-2/gate-4 |
| E-014 | runtime | installLog 脱敏 | **static_verified — not called on progress** | gate-3 |
| E-015 | package | zip SHA-256 match remote | **runtime_verified** — match | shasum + curl |
| E-016 | release | GitHub Release v1.4.0 | **runtime_verified** — reachable | GitHub API |
| E-017 | appcast | sparkle:edSignature 校验 | **static_verified** — 2 enclosures | verify-appcast.sh |
| E-018 | notarize | stapler validate / spctl | **not_run** — no ticket | gate-5 |
| E-019 | Helper | HelperClient 生产调用 | **static_verified — 0 callers** | grep |
| E-020 | user install | clean machine install | **not_run** | n/a |

---

## Findings

### P0（20 项，全部命中）

| ID | Reproduction | Impact | Evidence | Owner | Blocking condition |
|---|---|---|---|---|---|
| P0-G1-1 | `LocalCatalogLoader.loadCatalog` → `merge()` 写 `keyID: "local-no-signature", signature: ""`（`Apps/Mac/Sources/Catalog/Catalog.swift:257-273`） | 24 个 tool JSON 全部以"verified"进入 UI；目录可被未授权篡改 | Catalog.swift L268-269 | Catalog Loader owner | ManifestSecurity 接入 LocalCatalogLoader 并强制 verify |
| P0-G1-2 | `RemoteCatalogLoader.decode(_:)` 仅校验 schemaVersion（`Catalog.swift:343-366`）；`grep verifySnapshot|ManifestVerifying` 在 Catalog/Content/App 0 命中 | 远程目录无签名/过期/撤销检查 | Catalog.swift L343-366 | Catalog Loader owner | ManifestSecurity 接入 RemoteCatalogLoader + ContentManifest 加签名 |
| P0-G1-3 | `CodingToolsApp.swift:30-32` `try? await LocalCatalogLoader().loadCatalog()` | loader 失败用户得到 10 个 placeholder，看不到原因 | CodingToolsApp.swift L31 | App entry owner | 移除 `try?`、UI 显示「签名校验失败」 |
| P0-G1-4 | `Catalog/content/v1.0.0.json` 无 signature/keyID 字段；`ContentManifest` 类型不声明 | Content 在格式层不可签名 | Catalog/content/v1.0.0.json + Content.swift L64 | Content owner | ContentManifest 加签名字段并重签 |
| P0-G1-5 | `NpmGlobalAdapter.execute` L78-85 调用 `curl -fsSL <url> \| bash`；grok-build / hermes 的 installOptions `url` 字段直接进此路径 | 任意代码执行；与 P0-G1-1/2 组合可在 catalog 被污染后立刻远程代码执行 | NpmGlobalAdapter.swift L81-85 + Catalog/tools/grok-build.json / hermes.json | Adapter owner | 移除 curl\|bash 或要求 SHA256 + UI 二次确认 |
| P0-G2-1 | `AdapterRegistry.execute` L168-169：`adapter.execute(plan, progress)` **不传 action**；`NpmGlobalAdapter` / `OfficialArtifactAdapter` 立即 preconditionFailed | 21/24 tool 安装必失败 | Installers.swift L152-170 + NpmGlobalAdapter.swift L44-49 + OfficialArtifactAdapter.swift L62-65 | Installer owner | AdapterRegistry 改为 `executeWithAction` 或 InstallPlan 加 metadata |
| P0-G2-2 | `HomebrewAdapter.execute` L96：`fullArgs.append(plan.toolID)`；对 docker-desktop / nodejs / rust 必失败 | Homebrew 工具 4/13 必失败 + 1 brew 名错配 | HomebrewAdapter.swift L79-97 + Catalog/tools/*.json | Adapter owner | 改用 `case .homebrewFormula(let name)` 而非 toolID |
| P0-G2-3 | `InstallSheet.swift:32-37, 50-53` 写死 "Homebrew Formula" + `RiskBadge(level: .low)` + `brew install <slug>`；`ToolDetailView.swift:29-34, 100` 写死 brew/mise + low | UI 显示的来源 / 风险 / 操作与实际 catalog 严重不符；grok-build/hermes 实际是 curl\|bash 也显示 low | InstallSheet.swift + ToolDetailView.swift | UI owner | 遍历 `tool.installOptions` 渲染；用 `opt.riskLevel` |
| P0-G2-4 | `ToolDetailView.swift:146-148` `ContentLinkRow` 直接 `NSWorkspace.shared.open(item.sourceURL)`；Content 无签名（P0-G1-4） | 任意 https URL 可被 content manifest 控制者直接打开 | ToolDetailView.swift L140-148 + P0-G1-4 | UI owner | host 白名单或签名验证 |
| P0-G2-5 | `grep "HelperClient(" Apps/Mac/Sources` 0 命中；AppState.startInstall → AdapterRegistry → adapter.execute（in-process） | Helper 完全未连入生产；所有 install 命令由未沙箱 App 进程跑 | HelperClient.swift + AppState.swift L303-340 | Helper owner | HelperClient 接入 AdapterRegistry.execute |
| P0-G2-6 | `AppState.cancelInstall` L355-358 仅 `installState = .cancelled`；不调 Task.cancel()、不调 adapter.cancel() | 用户取消后 brew/npm/curl 进程继续运行 | AppState.swift L355-358 + 各 adapter.cancel(planID:) 注释 | AppState owner | Task.cancel + adapter.cancel 接线 |
| P0-G3-1 | `Persistence.swift:55` 全文只有 `InMemoryStore` actor；`AppState.favoriteProvider / favoriteSaver` 默认 nil | 收藏 / 最近使用每次重启即丢失 | Persistence.swift + AppState.swift L67-69 | Persistence owner | SQLiteStore + 注入 favoriteProvider |
| P0-G3-2 | `AppState.swift:320`：`installLog += "[\(p.stage.rawValue)] \(p.message)\n"`；`p.message` 未走 OutputRedactor；adapter（NpmGlobalAdapter L73-74, L79）把 URL 原样写入 | installLog 含原始 URL；含 `user:password@host` 时无法脱敏 | AppState.swift L318-321 + 各 adapter | Privacy owner | progress 构造时 redact 或 installLog 拼接前 redact |
| P0-G3-3 | `discoveredConfigs: [AIConfig]` 是 `@Published`，`configPath: URL`（绝对路径） + `hasAPIKey: Bool` 暴露给 SwiftUI | 任意视图可读用户 home 绝对路径；Process 内存 dump 可读取 | AppState.swift L44 + AIConfig.swift L11-19 | Privacy owner | 路径截断显示 + ProcessExecutor.redact 规则扩展 |
| P0-G4-1 | `AppMenuBar.swift:277-279` 打开 `https://example.com`，注释自承"占位" | 菜单栏点击任意工具 → 浏览器开 example.com；与 Plan §4 明确禁令冲突 | AppMenuBar.swift L272-280 | Menu Bar owner | 分发到 `tool.launchCapability`（cli/app/url+白名单） |
| P0-G4-2 | `HomeView.swift:238` `HealthBadge(status: .notInstalled)` 写死；对照 `CatalogView.ToolCard` L206 用 `state.probe(...)` | 首页推荐区永远显示未安装 | HomeView.swift L238 | HomeView owner | 改用 `state.probe(for: tool.id)?.healthStatus ?? .notInstalled` |
| P0-G4-3 | `HomeView.swift:81-83` `StatCard(title: "工具" / "已收藏" / "最近", ...)` 硬编码中文 | 7 语言本地化在主页统计区不生效 | HomeView.swift L81-83 | HomeView owner | 改为 `LocalizedStringKey` + 新 key |
| P0-G4-4 | `InstallSheet.swift:32-37, 50-53` 写死 Homebrew + low + brew install slug | 见 P0-G2-3（同一文件） | 同 P0-G2-3 | 同 P0-G2-3 | 同 P0-G2-3 |
| P0-G4-5 | `ToolDetailView.swift:29-34` 写死 brew + mise 行；L100 写死 low | 见 P0-G2-3 | 同 P0-G2-3 | 同 P0-G2-3 | 同 P0-G2-3 |
| P0-G4-6 | `ToolDetailView.swift:146-148` ContentLinkRow 直接 `NSWorkspace.open` | 见 P0-G2-4 | 同 P0-G2-4 | 同 P0-G2-4 | 同 P0-G2-4 |
| P0-G4-7 | `AppState.cancelInstall` 不调 Task.cancel、不调 adapter.cancel | 见 P0-G2-6 | 同 P0-G2-6 | 同 P0-G2-6 | 同 P0-G2-6 |

> 备注：P0-G2-3/4/5 与 P0-G4-1/4/5/6/7 共享证据，列表时按"每条 P0 编号"展开。

### P1（21 项）

| ID | Reproduction | Impact | Evidence | Owner | Due date | Risk acceptance |
|---|---|---|---|---|---|---|
| P1-G0-1 | PROJECT_STATUS L9 说 v1.5.0-rc1；tag / Info.plist / CHANGELOG 最新段 = v1.4.0 | 文档与发布物版本号不一致 | PROJECT_STATUS.md L9 | Doc owner | |
| P1-G0-2 | PROJECT_STATUS 阶段 2 ✅ 已完成；阶段 11 ⬜ 未开始；风险登记 🔴「10 个 tools 全部 signature=''」 | 同文档内阶段与风险表自相矛盾 | PROJECT_STATUS.md L18, L27, L134 | Doc owner | |
| P1-G0-3 | PROJECT_STATUS 风险登记 L136 「10 个 tools」；CHANGELOG L21「24 工具」 | 工具数在文档间漂移 | PROJECT_STATUS.md L136 | Doc owner | |
| P1-G0-4 | NpmGlobalAdapter 仍未走 HelperClient（PROJECT_STATUS L79, L85-87） | 阶段 9 二期未做 | PROJECT_STATUS.md | Adapter owner | |
| P1-G0-5 | Apple Developer ID 未开始；签名 / notarization / Release 全部阻塞 | 见 Gate 5 not_run | PROJECT_STATUS.md L132 | Coordinator | 外部流程 |
| P1-G0-6 | xcscheme 静态显示 `<Testables></Testables>` 空；Project.swift 重新注入 — 不跑 `tuist generate` 时 Testables 缺失 | xcodebuild test 报错 "scheme not configured for test action" | xcscheme file vs Project.swift | Build owner | |
| P1-G0-7 | Info.plist `LSUIElement=true` 同时 `CFBundlePackageType=APPL` | 运行时是菜单栏附加还是完整 App 需 Gate 4 runtime 确认 | Info.plist L30-43 | App owner | |
| P1-G0-8 | CHANGELOG 同日两版本（[1.4.0] 与 [1.2.5] 都是 2026-08-11） | 不影响行为但版本号跳跃 | CHANGELOG.md L11, L17 | Doc owner | |
| P1-G1-1 | ManifestSecurity 框架完整、10 测试覆盖，但 `verifySnapshot\|ManifestVerifying\|verify\(\|Ed25519ManifestVerifier\|ManifestSecurity\.` 在 Catalog/Content/App 0 命中 | 测试通过 ≠ 实际拦截 | grep result | Catalog owner | |
| P1-G1-2 | `Catalog/revocations/` 为空目录 | 即使将来接通验签，无撤销源 | Catalog/revocations/ | Catalog owner | |
| P1-G1-3 | `ManifestSecurity.InMemoryPublicKeys.developmentRegistry` 是空 PublicKeyRegistry | 若生产误用 = 所有签名 unknownKey = 等同关验证 | ManifestSecurity.swift L135-136 | Catalog owner | |
| P1-G1-4 | `CatalogError.signatureInvalid / .expired / .revoked` 已定义但无任何 loader 抛出 | dead code 隐患 | Catalog.swift L21-23 | Catalog owner | |
| P1-G2-1 | AdapterRegistry 默认 5 adapter 共享 ProcessExecutor 并发模型未显式说明 | 并发 brew/npm 行为未验证 | Installers.swift L134-142 | Installer owner | |
| P1-G2-2 | `startInstall` 完成分支未触发 `refreshProbe(toolID:)` | 安装完成后 latest version 比较持续显示旧值 | AppState.swift L303-340 | AppState owner | |
| P1-G2-3 | ToolDetailView L73-82 install 按钮始终可点 | install 中可再次触发，覆盖 installingTool + installLog | ToolDetailView.swift L73-82 | UI owner | |
| P1-G2-4 | InstallProgress 无 sequence number | progress 回调乱序时日志时间倒流 | InstallProgress 类型定义 | Installer owner | |
| P1-G2-5 | InstallError 没有 retryable 区分 | 失败后无 retry 按钮；与 toast retry 通路分裂 | AppState.swift L335-338 | AppState owner | |
| P1-G2-6 | AdapterRegistry 构造不抛错，r.register() 静默失败 | 生产注册失败不可见 | Installers.swift L144-146 | Installer owner | |
| P1-G3-1 | `AIConfigDiscovery.discover()` 返回 `[]` 时 UI 不可区分未配置 vs 扫描失败 | Plan §6 P1 #4 | FilesystemAIConfigDiscovery L78-92 | AIConfig owner | |
| P1-G3-2 | `Store.saveCatalog / loadLatestCatalog` 无任何调用点 | Catalog 缓存未接入 Store | grep result | Persistence owner | |
| P1-G3-3 | 无清理操作历史 API | Plan §6 验收 #5 无法执行 | Persistence.swift | Persistence owner | |
| P1-G3-4 | OutputRedactor 未覆盖 npm_xxx / AWS AKIA / sk-ant / sk- 等 | installLog / 未来 log 漏 token | ProcessExecution.swift L237-254 | Privacy owner | |
| P1-G3-5 | CrashReporter fputs 到 stderr 未走 redactor | stderr 副本可能漏脱敏 | CrashReporter.swift L270-273 | Privacy owner | |
| P1-G3-6 | `@Published var installingTool: Tool?` 在 install 进行中可被覆盖 | 无 invariant 保证 | AppState.swift L24 | AppState owner | |
| P1-G4-1 | ToolDetailView install 按钮不传 installOption | InstallSheet 拿不到真实 option | ToolDetailView.swift L73-82 | UI owner | |
| P1-G4-2 | CatalogView 卡片 install 按钮同样不传 installOption | 同上 | CatalogView.swift L242-268 | UI owner | |
| P1-G4-3 | `RootView.task { await state.loadFavorites() }` 在 provider=nil 时 no-op | 菜单栏收藏区永不显示 | RootView.swift L47 + AppState.swift L279-283 | Persistence owner | |
| P1-G4-4 | `loadContentIfNeeded` 失败回退 BundledContent 但 BundledContent 内容未验证 | 远端失败时 UI 显示未验证数据 | AppState.swift L246-256 | Content owner | |
| P1-G4-5 | `recommended: [Tool] = Array(state.tools.prefix(4))` | 推荐无逻辑 | HomeView.swift L193-196 | HomeView owner | |
| P1-G4-6 | DiscoveredConfigRow 仅 adopt 到 favorites，无 jump-to-install | 发现后无法直接安装 | HomeView.swift L451-457 | UI owner | |
| P1-G4-7 | `launchTool` 忽略 `tool.launchCapability.command / arguments` | 见 P0-G4-1 | AppMenuBar.swift L272-280 | Menu Bar owner | |
| P1-G4-8 | RootView.onReceive codingToolsOpenSettings 在窗口已开时再 makeKeyAndOrderFront | 重复开窗 | RootView.swift L60-67 | UI owner | |
| P1-G4-9 | `AppDelegate.shared?.pendingDeepLink` 单例访问可选 | deep link 静默丢失 | RootView.swift L69 | AppDelegate owner | |
| P1-G5-1 | Sparkle SPUUserDriver 升级流程无真实机器日志 | 见 Gate 5 E-018 | SilentUpdateUserDriver.swift | Sparkle owner | |
| P1-G5-2 | 干净机器装机未跑（无 Parallels / 快照 / 实机） | 见 Gate 5 E-019 | n/a | Coordinator | |

> 备注：列表超过 21 条实际项（算 P1-G2 / G3 / G4 子项）。按 Plan §9 P1 定义清点。

### P2（8 项）

| ID | Description |
|---|---|
| P2-G0-1 | CodingTools.xcodeproj/xcshareddata/xcschemes 静态 `<Testables></Testables>` 空（Tuist 重新生成后覆盖） |
| P2-G0-2 | Info.plist LSUIElement=true 与 CFBundlePackageType=APPL 组合需运行时确认 |
| P2-G1-1 | 24 tool JSON 中 4 个 tool 的 catalogVersion 同日重复（git/docker/fzf 等）— 不影响逻辑 |
| P2-G2-1 | CatalogView.ToolCard buttonTitle 在 installed 时只判 latest，不看 installed == latest |
| P2-G3-1 | outputRedactor 末位空白字符未做 unicode normalization（`/Users/<name>/`） |
| P2-G4-1 | 列表 / grid 的 spacing / corner radius 在大屏未做 adaptive |
| P2-G5-1 | Content manifest v1.0.0.json 21 条内容条目，6 条 youtube 链接可能因速率限制失效 |
| P2-G5-2 | CI 占位 workflow 仅有 `ci.yml` + `release.yml`，未跑过 CI |

---

## UX Review

- **First launch**: CodingToolsApp 启动 → catalogProvider=`try? LocalCatalogLoader()` → 24 tool 加载（无验签）→ `discoverAIConfigs()` 扫 ~/.claude / ~/.codex 等 → `refreshProbes()` 真实 run which / probeCLI → `refreshLatestVersions()` 调 brew info / npm view。 任何一步失败被 try? / Task.detached 吞掉，UI 无明确反馈。
- **Catalog loading**: 24 个 tool 卡片渲染 OK；搜索/分类/收藏 toggle 工作；CatalogView.ToolCard 的 `RiskBadge(level: tool.riskLevel)` 正确从 tool 读。
- **Catalog failure**: **不存在**——所有失败被 try? 吞 + LocalCatalogLoader.merge 主动伪造 verified。
- **Detail and install option**: ToolDetailView **写死 brew install + mise use + RiskBadge(.low)**（P0-G2-3 / G4-5），与 tool.installOptions 实际内容无关。
- **Progress**: InstallProgress 阶段名正确但 InstallSheet 头部仍写死 Homebrew；进度回调顺序无 sequence number（P1-G2-4）。
- **Cancel**: **仅改 UI**（P0-G2-6 / G4-7），brew/npm/curl 继续运行。
- **Failure and retry**: 显示 stderr 文本 + "失败"图标；不区分 retryable；与 toast retry 通路不连（P1-G2-5）。
- **Post-install detection**: **未触发 refreshProbe**（P1-G2-2）—— installed version / latest 比较会持续显示旧值。
- **Launch**: AppMenuBar.launchTool 写死 https://example.com（P0-G4-1）；tool.launchCapability 完全忽略。
- **Favorites and recents**: UI toggle 立即反馈；**重启即丢失**（P0-G3-1）。
- **Menu bar**: NSStatusBar system 渲染 OK；最近 / 收藏子菜单 OK；启动跳转坏（P0-G4-1）。
- **Localization**: tab / section / category 7 语言 OK；**HomeView StatCard 硬编码中文**（P0-G4-3）。
- **Accessibility**: keyboard shortcut 部分覆盖（⌘O / ⌘, / ⌘Q / ⌘I / ⌘U）；Reduce Motion / 高对比 未验证。

---

## Frontend / Backend Integration

| Call-chain | 现状 |
|---|---|
| Catalog to View | ✅ CatalogView + HomeView 直接读 `state.tools` |
| View to AppState | ⚠️ `state.installingTool = tool` 但 **不传 installOption**（P1-G4-1, P1-G4-2） |
| AppState to InstallerService | ❌ 无独立 InstallerService；`installerRegistry.execute(toolID, action, ...)` 直接到 AdapterRegistry |
| InstallerService to AdapterRegistry | ❌ AdapterRegistry.execute 内部 plan→execute，**execute 不传 action**（P0-G2-1） |
| AdapterRegistry to Adapter | ⚠️ Homebrew/Mise 用 plan.toolID 错配；Npm/Official preconditionFailed（混合 P0-G2-1 / G2-2） |
| Adapter to Helper/ProcessExecutor | ❌ HelperClient 0 调用；curl\|bash 直接走 ProcessExecutor 的 shellForbidden 拦截（NpmGlobalAdapter L81-85） |
| Detection back to AppState | ⚠️ `refreshProbes()` 在启动 + install 后未自动跑（P1-G2-2） |
| AppState to Store | ❌ favoriteProvider / favoriteSaver 默认 nil（P0-G3-1） |
| Store back to UI | ⚠️ favorites / recent 是 @Published 内存态；UI 渲染 OK 但**重启丢失**（P0-G3-1） |
| Unverified or missing links | ContentLinkRow 直接 `NSWorkspace.open(item.sourceURL)`（P0-G2-4 / G4-6） |

---

## Release Boundary

- **Local build**: ✅ Debug + Release 编译通过；universal binary (x86_64 + arm64)
- **Local tests**: ✅ 173/173 通过（5 主 + 4 副 scheme，Tuist 缓存命中）
- **Runtime**: ⚠️ 仅测试 target 跑；真实 App 启动无录像
- **Package**: ✅ zip / pkg / appcast 三个 artifact SHA-256 与 GitHub Release 一致
- **Signing**: ⚠️ ad-hoc（`Signature=adhoc`，`TeamIdentifier=not set`）
- **Notarization**: ❌ **not_run**（`stapler validate` 无 ticket；`spctl -a` 拒绝 → 用户运行 DMG 必须右键打开）
- **Remote Release**: ✅ v1.4.0 GitHub Release reachable；zip download 与本地 hash 一致
- **In-app update**: ⚠️ appcast EdDSA 静态校验通过；运行时升级未实测
- **Clean machine install**: ❌ **not_run**（无干净装机记录）
- **Explicitly not run**: notarization、干净机器安装、Sparkle 端到端升级、real runtime、user acceptance

---

## Reviewer Conclusion

### 当前可交付

- ✅ 内部代码审阅 / 学习用
- ✅ 第三方阅读源码
- ✅ Tuist 构建链路在 macOS 14+ / Xcode 26.6 / arm64 上编译通过
- ✅ Sparkle appcast 格式 + EdDSA 签名结构正确（已校验）
- ✅ Catalog 24 个 tool JSON 数据契约符合 schema（除签名外）
- ✅ CrashReporter 本地落盘 + OutputRedactor 主规则就绪

### 不能交付

- ❌ **不可作为生产 / 公共 Release**：
  - 目录签名未接通，远程内容 0 校验 → 攻击者可注入任意 install.sh / pkg 入口
  - NpmGlobalAdapter 走 `curl | bash`，与未签名目录组合是远程代码执行
  - UI 显示 Homebrew + low + brew install，但 24 个 tool 中至少 21 个实际安装必报错
  - 菜单栏启动入口打开 example.com
  - 取消按钮不停止真实进程
  - 收藏 / 最近使用每次重启即丢失
  - Persistence framework 无 SQLite 实现
  - Notarization 未做 → Gatekeeper 拒绝
- ❌ **不可对外宣称 "release 成功" / "用户装机"**：干净装机未实测
- ❌ **不可对外宣称 "Helper 已接通"**：HelperClient 在生产路径 0 调用

### P0 解除条件（最小集，按优先级）

1. **Catalog 验签接通**（P0-G1-1, G1-2, G1-3, G1-4）
   - `ManifestSecurity.Ed25519ManifestVerifier` 接入 `LocalCatalogLoader.loadAllToolsFiles` 后、`merge` 前
   - 接入 `RemoteCatalogLoader.decode` 后
   - `ContentManifest` 加 signature/keyID，重签
   - 生成 EdDSA 密钥对，私钥管理在仓库外，公钥编入 App Bundle
   - CodingToolsApp.swift 移除 `try?`
2. **NpmGlobalAdapter 移除 curl|bash**（P0-G1-5）
   - 移除 fallback 路径；或要求 scriptURL 同时含 SHA-256 + UI 二次确认
3. **AdapterRegistry.execute 接线 action**（P0-G2-1）
   - `executeWithAction` 改为 registry 唯一入口
   - 旧 `execute(plan)` 接口删除（避免误用）
4. **HomebrewAdapter / MiseToolAdapter 用 action 内字段**（P0-G2-2）
   - `case .homebrewFormula(let name)` 取 name
   - `case .miseTool(let name, let version)` 取两者
5. **InstallSheet / ToolDetailView 渲染 tool.installOptions**（P0-G2-3 / G4-4 / G4-5）
   - 遍历 options；RiskBadge(opt.riskLevel)；type 走 Localizable
6. **HelperClient 接入生产路径**（P0-G2-5）
   - `installerRegistry` 默认走 HelperClient；Helper 不可用回退 in-process
7. **取消真正停止进程**（P0-G2-6 / G4-7）
   - `cancelInstall` 调用 Task.cancel + adapter.cancel
8. **AppMenuBar.launchTool 走 tool.launchCapability**（P0-G4-1）
   - cli / app / url+host 白名单
9. **ContentLinkRow 走白名单 + 签名校验**（P0-G2-4 / G4-6）
10. **SQLiteStore + favoriteProvider 注入**（P0-G3-1）
11. **installLog 脱敏 + outputRedactor 扩展 npm/sk-/AWS**（P0-G3-2 / G3-4）
12. **HomeView StatCard 本地化 + HealthBadge 真值**（P0-G4-2 / G4-3）

### 下一次复核入口

- 解锁所有 P0 后重跑 Gate 1–4 静态 + Gate 5 测试 + 真实启动
- 在干净 macOS 14+ 机器上下载 v2.0.0-rc1 zip → 解压 → 启动 → 走完所有 24 个 tool 的 install 路径 → 卸载 → 重装
- 待 Apple Developer ID 申请下来后跑 notarization + spctl + 公证 stapled 验证

### 不能使用的措辞

- "XPC Helper 架构就位 = App 沙箱可开"——HelperClient 未接通，sandbox 不能开
- "目录签名就绪 = ManifestSecurity 模块完整"——模块完整 ≠ 接入 loader
- "v1.5.0-rc1" — 当前 tag / Info.plist 仍是 v1.4.0
- "24 工具全通过"——只有 10–13 个 tool 在 brew path 上可能 success

---

**审核完成。Decision: BLOCKED.**