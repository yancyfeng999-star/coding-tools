
# Coding Tools Integration and UX Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** 将 Coding Tools 从“目录、安装器和 UI 外壳已存在”推进到可验证的真实产品闭环：可信目录加载、参数正确的安装、可取消和可重试的操作、持久化状态、真实启动、清晰反馈，以及前后端和发布证据完整。

**Architecture:** 保留现有 SwiftUI + Tuist 分层，在 Catalog、Installers、Persistence、Launching、Content 和 UIState 之间建立明确接口。安装和目录安全逻辑由领域层提供事实，AppState 只编排状态，视图只渲染状态并触发意图；所有外部副作用通过 Helper、ProcessExecutor、网络加载器或持久化 Store 进入。每项改动先有失败测试，再实现最小闭环，最后采集对应证据。

**Tech Stack:** Swift 5.9+, SwiftUI, macOS, Xcode/xcodebuild, Tuist, XCTest, SQLite, XPC Helper, Sparkle, Ed25519 manifest verification.

## Global Constraints

- 只在本项目目录内工作：/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools。
- 保留现有未提交改动；执行前后记录 git status；不得 reset、clean、checkout 或覆盖他人文件。
- 不把静态编译、单元测试或本机 Debug 构建写成可发布、可安装或用户已验收。
- 不把上游包名、签名 URL、凭据、供应商成本、利润、内部路径放进浏览器或用户可见 DTO。
- 目录、远程内容和更新清单验证失败时必须 fail closed；不得用空签名、unknown key 或过期缓存继续当作可信数据。
- 安装、取消、重试、启动、收藏和最近使用必须有可观察的状态和持久化或明确的无持久化说明。
- Developer ID、notarization、远程 Release、Sparkle 更新和真实用户安装都需要单独证据，不能由本地构建推断。
- 代码变更每个独立任务单独提交；提交前运行该任务的最小测试集。

---

## 1. 当前基线与完成定义

以下是实施前必须重新确认的只读基线，用于防止把旧文档或生成文件状态误认为当前产品状态。

| 检查项 | 现状判断 | 对实施的影响 |
|---|---|---|
| 版本 | Info.plist 是 1.4.0 build 22，PROJECT_STATUS.md 仍写 v1.5.0-rc1，协作状态文件还保留 0.0.0/0.1.0 | 先统一版本事实，再决定是否更新状态文档 |
| Debug 构建 | CodingTools Debug 构建可通过，但有 AIConfigDiscovery、LatestVersion、HelperProtocol 等警告 | 警告按风险分类；与本任务相关的警告必须清零或记录豁免 |
| 测试 | CodingTools scheme 的 Testables 为空，直接 xcodebuild test 不能运行整套测试 | 先修复 scheme 和脚本，再声称测试可复现 |
| Catalog | CodingToolsApp 只注入 LocalCatalogLoader；本地工具 JSON 的签名为空；loader 未强制 ManifestSecurity | 目录安全是发布阻塞项，不是 UI 微调项 |
| 安装 | AppState 选择首个 install option；NpmGlobalAdapter、OfficialArtifactAdapter 依赖 pendingActions；Registry 没有把 action 传入 execute | 必须先修正 install action 的参数流 |
| UI | ToolDetailView、InstallSheet、HomeView 使用硬编码安装、健康度、风险和状态；菜单栏启动打开 example.com | 先接入真实状态，再补 UI 视觉 |
| 状态 | 收藏、最近使用和 Store 仍偏内存；取消安装没有真正取消 Task/进程 | 必须有重启、取消和失败恢复验收 |
| 发布 | 尚无完整的签名、notarization、Release、Sparkle 更新和真实安装证据 | 本计划完成不等于发布授权 |

### 完成定义

只有同时满足以下条件，实施负责人才能标记“本计划完成”：

1. 所有 P0 项通过独立审核；P1 项有关闭证据或产品负责人书面豁免。
2. 目录签名、密钥、过期、撤销、篡改、离线缓存行为有自动化测试和运行日志。
3. 至少 Claude Code、Codex CLI、Docker、Node、Python、Rust 和一个官方 Artifact 路径完成参数映射测试；真实供应商安装另需用户授权和环境证据。
4. 安装进度、取消、失败、重试、安装后检测、启动失败均能在 UI 中给出可理解反馈。
5. 收藏、最近使用、操作历史重启后保持；敏感参数和凭据不进入日志。
6. UI 不再使用 example.com、假安装命令或硬编码的已安装、健康、风险结论。
7. Debug、Release、测试、签名包、notarization、更新和干净机器安装分别有证据；未取得远程发布授权时停在本地交付。

---

## 2. 责任边界

| 角色 | 负责范围 | 交付物 | 不得宣称 |
|---|---|---|---|
| Owner A：Catalog / Installer | Catalog 安全、内容加载、InstallAction、Helper、检测和取消 | 代码、单元测试、安装参数矩阵、日志脱敏说明 | 不得宣称真实供应商或用户环境已验证，除非有环境证据 |
| Owner B：UI / Content / Persistence | AppState、SwiftUI 状态、收藏/最近、启动入口、内容和可访问性 | UI、UI 测试、重启验证、截图/录像、错误文案 | 不得用固定 mock 状态替代后端事实 |
| Owner C：工程 / QA / Release | 版本、scheme、脚本、构建、测试、签名和证据归档 | 可复现命令、报告、制品校验、门禁记录 | 不得把本地构建写成远程发布或安装成功 |
| Independent Reviewer | 只读复核、反例测试、证据判定、P0/P1/P2 分级 | 独立审核报告和阻塞清单 | 不得审核自己提交的代码并以此作为唯一通过依据 |

---

## 3. 先固定的接口契约

实施前先在对应测试 target 中固定这些语义；名称可以按现有类型调整，但参数含义不得丢失。

### 3.1 安装动作必须贯穿计划到执行

InstallOption 中的 action 是事实源。AdapterRegistry 不得重新从 toolID 猜包名。

~~~swift
protocol InstallAdapter {
    func plan(tool: ToolDefinition, option: InstallOption) throws -> InstallPlan
    func execute(
        plan: InstallPlan,
        action: InstallAction,
        progress: @escaping (InstallProgress) -> Void
    ) async throws -> InstallResult
    func cancel(operationID: UUID) async
}
~~~

最低要求：

- Homebrew 使用 action.packageName 的 formula 或 cask 信息。
- Mise 使用 action.toolName，不从产品 ID 推断。
- Npm 使用 action.packageName 和安全的 package manager 路径。
- Official Artifact 使用 action.downloadURL、archiveType、checksum 和 installDestination。
- 记录 operationID、toolID、optionID、adapterID、startedAt、finishedAt、result。
- 用户取消后底层 Task 和可取消进程都必须结束，并在 UI 显示 cancelled，而不是 failed。

### 3.2 AppState 只编排，不伪造事实

AppState 至少需要以下状态：

~~~swift
enum OperationState {
    case idle
    case loading
    case installing(operationID: UUID, progress: InstallProgress)
    case cancelling(operationID: UUID)
    case succeeded(operationID: UUID, result: InstallResult)
    case failed(operationID: UUID, error: UserFacingError, retryable: Bool)
    case cancelled(operationID: UUID)
}

struct AppStateDependencies {
    let catalogLoader: CatalogLoading
    let contentLoader: ContentLoading
    let installer: InstallerService
    let launcher: Launcher
    let store: Store
    let latestVersionProvider: LatestVersionProvider
}
~~~

视图只能从 AppState 读取 ToolStatus、InstallOption、LaunchCapability 和 OperationState；不允许在 View 内固定“已安装”“低风险”“Homebrew”等事实。

### 3.3 目录和远程内容必须返回可判定结果

Loader 不得只返回数组并吞掉错误。结果至少区分：

- verified：签名、schema、expiry、revocation 均通过；
- stale-but-usable：只在产品安全策略明确允许且 UI 明确提示时使用；
- rejected：签名、密钥、schema、过期或篡改失败；
- unavailable：网络或本地文件不可读；
- partial：仅在 manifest 明确允许部分加载且已记录缺失项时使用。

空 signature 不得映射为 verified；try? 不得把 rejected 转成空目录。

### 3.4 Store 以用户行为为中心

Store 至少支持：

~~~swift
protocol Store {
    func setFavorite(toolID: String, isFavorite: Bool) throws
    func listFavoriteToolIDs() throws -> Set<String>
    func recordRecent(toolID: String, at: Date) throws
    func listRecentToolIDs(limit: Int) throws -> [String]
    func appendOperation(_ record: OperationRecord) throws
    func listOperations(limit: Int) throws -> [OperationRecord]
}
~~~

凭据、签名密钥、完整下载 URL、命令行敏感参数不得进入 OperationRecord。

---

## 4. 实施任务

### Task 1: 统一版本、项目状态和可运行测试入口

**Files:**

- Modify: PROJECT_STATUS.md
- Modify: CHANGELOG.md
- Modify: .multi-agent-collaboration/runs/run-001/state.yaml，仅在确认该状态属于当前版本时修改
- Modify: Apps/Mac/Project.swift
- Modify: Apps/Mac/CodingTools.xcodeproj/xcshareddata/xcschemes/CodingTools.xcscheme 或对应 Tuist 生成源
- Modify: Apps/Mac/scripts/run-tests.sh
- Test: Apps/Mac/Tests/AppTests/AppTests.swift，补充版本/启动依赖的最小测试

**目标：** 让版本、scheme、测试脚本和状态文件表达同一事实。

- [ ] Step 1: 保存基线并确认 dirty 范围。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools"
git status --short --branch
git log -1 --oneline
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Apps/Mac/Sources/App/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Apps/Mac/Sources/App/Info.plist
~~~

Expected: 命令输出写入实施记录；任何非本任务 dirty 文件都不触碰。

- [ ] Step 2: 选择单一版本来源并更新状态文件。

规则：

1. 版本真相来自 Project.swift 或 Info.plist 的既有生成链，不允许只改 PROJECT_STATUS.md。
2. 如果目标仍是 1.4.0 build 22，所有状态文档统一写 1.4.0/build 22。
3. 如果确实要进入 1.5.0-rc1，先在 Project.swift、Info.plist 生成源、CHANGELOG 和发布说明中统一，再更新协作状态。
4. 不得把计划目标版本写成已经发布版本。

- [ ] Step 3: 生成 scheme 并确认 CodingTools Testables 不为空。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
tuist generate
xcodebuild -workspace CodingTools.xcworkspace -scheme CodingTools -showTestPlans
xcodebuild -workspace CodingTools.xcworkspace -scheme CodingTools -configuration Debug -destination "platform=macOS" test
~~~

Expected: CodingTools scheme 的 Testables 明确列出测试 target；整套测试可执行，失败时能定位到具体 test。

- [ ] Step 4: 给 run-tests.sh 增加一致的 workspace、scheme、destination 和失败退出码。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
./scripts/run-tests.sh
test "$?" -eq 0
~~~

Expected: 脚本在无测试配置、编译失败、测试失败时均返回非 0，不打印“通过”假结果。

- [ ] Step 5: 运行最小回归并提交。

~~~bash
xcodebuild -workspace CodingTools.xcworkspace -scheme CodingTools -configuration Debug -destination "platform=macOS" build
xcodebuild -workspace CodingTools.xcworkspace -scheme CodingTools -configuration Debug -destination "platform=macOS" test
git diff --check
git add PROJECT_STATUS.md CHANGELOG.md Apps/Mac/Project.swift Apps/Mac/scripts/run-tests.sh Apps/Mac/CodingTools.xcodeproj/xcshareddata/xcschemes/CodingTools.xcscheme Apps/Mac/Tests/AppTests/AppTests.swift
git commit -m "build: align version and test entrypoint"
~~~

Expected: 构建和测试输出、commit id、仍未处理的风险均写入 handoff。

---

### Task 2: 建立签名、过期和撤销强制执行的 Catalog 闭环

**Files:**

- Modify: Apps/Mac/Sources/Catalog/Catalog.swift
- Modify: Apps/Mac/Sources/ManifestSecurity/ManifestSecurity.swift
- Modify: Apps/Mac/Sources/ManifestSecurity/ManifestCanonicalizer.swift
- Modify: Apps/Mac/Sources/Content/Content.swift
- Modify: Apps/Mac/Sources/Content/BundledContent.swift
- Modify: Apps/Mac/Sources/Content/Loaders/RemoteContentLoader.swift
- Modify: Apps/Mac/Sources/App/CodingToolsApp.swift
- Modify: Apps/Mac/Sources/ManifestSecurity/Resources/PublicKeys/dev-pub-2026a.pub，仅在密钥轮换时修改
- Modify: catalog JSON 文件及其 manifest，补齐真实签名和 schema 字段
- Test: Apps/Mac/Tests/ManifestSecurityTests/ManifestSecurityTests.swift
- Test: Apps/Mac/Tests/CatalogTests/CatalogLoaderTests.swift
- Test: Apps/Mac/Tests/CatalogTests/LocalCatalogLoaderTests.swift
- Test: Apps/Mac/Tests/CatalogTests/CatalogTests.swift

**目标：** 本地、远程和缓存目录都经过同一套验证规则，失败时可解释、可重试且不泄漏不可信内容。

- [ ] Step 1: 先写失败测试矩阵。

~~~swift
func testEmptySignatureIsRejected()
func testUnknownKeyIsRejected()
func testTamperedPayloadIsRejected()
func testExpiredManifestIsRejected()
func testRevokedKeyIsRejected()
func testValidManifestIsVerified()
func testOfflineCacheCannotOutliveExpiry()
func testLocalLoaderDoesNotReturnLocalNoSignatureAsVerified()
~~~

每个测试都要构造独立 fixture，断言错误类型、manifest 状态和 UI 可用的恢复动作；不得只断言数组为空。

- [ ] Step 2: 统一验证入口。

实现一个由 LocalCatalogLoader、RemoteCatalogLoader 和 Content loader 共用的验证服务，输入原始 bytes、manifest 元数据、当前时间和 key registry，输出 verified/rejected/unavailable 等明确结果。

强制规则：

- signature 为空直接 rejected。
- keyID 不存在、key 已撤销、过期超过允许时钟偏差直接 rejected。
- canonical bytes 必须和签名验证使用的 bytes 完全一致。
- 通过验证后再 decode 成 ToolDefinition 或 Content。
- 失败结果必须带 source、reason、retryable 和 receivedAt。

- [ ] Step 3: 删除静默吞错和伪成功路径。

将 CodingToolsApp 中 catalogLoader 的 try? 改为显式处理；启动时显示 loading、verified、stale、rejected 或 unavailable。删除 local-no-signature 作为成功信号的语义；如果开发环境需要 fixture，必须由测试 fixture 或明确的 development-only key 产生且不进入 Release。

- [ ] Step 4: 补齐 manifest 和签名生成检查。

每个工具 JSON 都要有稳定的 toolID、schemaVersion、source、updatedAt、expiresAt、signature、keyID。签名不写进被签名 payload。增加校验脚本，对 24 个工具文件逐一报告缺失字段、重复 ID、无效签名和过期时间。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools"
python3 Scripts/verify_catalog.py
test "$?" -eq 0
~~~

如果项目没有 Scripts/verify_catalog.py，则在本任务内按现有脚本目录新增，且脚本必须是只读检查器，不生成或覆盖签名文件。

- [ ] Step 5: 运行安全回归并提交。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
xcodebuild -project CodingTools.xcodeproj -scheme ManifestSecurityTests -configuration Debug -destination "platform=macOS" test
xcodebuild -project CodingTools.xcodeproj -scheme CatalogTests -configuration Debug -destination "platform=macOS" test
git diff --check
git add Apps/Mac/Sources/Catalog Apps/Mac/Sources/ManifestSecurity Apps/Mac/Sources/Content Apps/Mac/Sources/App/CodingToolsApp.swift Apps/Mac/Tests/ManifestSecurityTests Apps/Mac/Tests/CatalogTests
git commit -m "security: enforce verified catalog and content"
~~~

Expected: 空签名、篡改、未知 key、撤销和过期 fixture 全部拒绝；有效 fixture 全部通过。

---

### Task 3: 修复安装 action 参数、Helper 接入和真实取消

**Files:**

- Modify: Apps/Mac/Sources/Installers/Installers.swift
- Modify: Apps/Mac/Sources/Installers/HomebrewAdapter.swift
- Modify: Apps/Mac/Sources/Installers/MiseToolAdapter.swift
- Modify: Apps/Mac/Sources/Installers/NpmGlobalAdapter.swift
- Modify: Apps/Mac/Sources/Installers/OfficialArtifactAdapter.swift
- Modify: Apps/Mac/Sources/Installers/HelperProtocol.swift
- Modify: Apps/Mac/Sources/Installers/HelperClient.swift
- Modify: Apps/Mac/Helper/CodingToolsHelperService.swift
- Modify: Apps/Mac/Helper/HelperInstallExecutor.swift
- Modify: Apps/Mac/Sources/UI/State/AppState.swift
- Modify: Apps/Mac/Sources/Detection/Detection.swift
- Test: Apps/Mac/Tests/InstallerTests/AdapterRegistryTests.swift
- Test: Apps/Mac/Tests/InstallerTests/InstallerTests.swift
- Test: Apps/Mac/Tests/InstallerTests/DetectionTests.swift
- Test: Apps/Mac/Tests/InstallerTests/ProcessExecutionTests.swift
- Test: Apps/Mac/Tests/HelperTests/HelperWireTests.swift

**目标：** 每一种安装方式都执行 catalog 给出的 action，不靠 product ID 猜参数，不以 shell pipe 绕过安全模型，并能取消底层进程。

- [ ] Step 1: 为 Registry 写参数保真失败测试。

| 产品 | adapter | 必须传递的事实 |
|---|---|---|
| Claude Code | npm | packageName、registry/版本约束 |
| Codex CLI | npm | packageName、registry/版本约束 |
| Docker | Homebrew | cask/formula packageName |
| Node | Mise | toolName |
| Python | Mise | toolName |
| Rust | Mise | toolName |
| 一个官方 Artifact | OfficialArtifact | downloadURL、archiveType、checksum、destination |

测试必须断言 adapter 收到的 action 与 fixture 完全一致，尤其不能使用 toolID 替代 packageName/toolName。

- [ ] Step 2: 调整 InstallAdapter、AdapterRegistry 和 Helper wire contract。

Registry 的 execute 入口必须传递 tool、option、plan、action、operationID；不得先把 action 丢掉再让 adapter 猜。Helper 请求至少包括 operationID、toolID、adapterID、action、destination policy 和 cancellation token identifier；禁止传输凭据和无界任意命令。

- [ ] Step 3: 删除或封装危险 fallback。

NpmGlobalAdapter 不得直接执行 curl URL pipe bash。若供应商只提供安装脚本，必须先下载到受控临时目录、校验 HTTPS 证书策略和 checksum/签名，再由允许的 Helper 执行；如果无法证明安全性，返回明确的 unsupported/blocked，而不是静默 fallback。ProcessExecutor 不得放宽为任意 /bin/sh。

- [ ] Step 4: 接通 HelperClient，并处理启动、协议和失败。

CodingToolsApp 或安装服务必须实际构造 HelperClient；Helper service 应返回结构化 progress、stdout/stderr 摘要、exit code、cancelled 和 postInstallDetection。路径权限、Helper 不可用、用户拒绝授权、checksum 不一致必须有稳定 UserFacingError。

- [ ] Step 5: 实现取消、重试和安装后检测。

AppState 保存 operationID 到 Task/进程句柄的映射。cancelInstall 先进入 cancelling，再调用 adapter.cancel 或 Helper cancel；确认进程结束后进入 cancelled。只有 retryable=true 的错误显示重试；重试要生成新的 operationID，不能复用已结束的进程。

- [ ] Step 6: 运行测试并提交。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
xcodebuild -project CodingTools.xcodeproj -scheme InstallerTests -configuration Debug -destination "platform=macOS" test
xcodebuild -project CodingTools.xcodeproj -scheme HelperTests -configuration Debug -destination "platform=macOS" test
git diff --check
git add Apps/Mac/Sources/Installers Apps/Mac/Helper Apps/Mac/Tests/InstallerTests Apps/Mac/Tests/HelperTests
git commit -m "feat: preserve install actions and support cancellation"
~~~

Expected: 参数矩阵通过；取消不会被记录为失败；安装失败、Helper 拒绝和检测失败均能被区分。

---

### Task 4: 用 SQLite 完成收藏、最近使用和操作历史持久化

**Files:**

- Modify: Apps/Mac/Sources/Persistence/Persistence.swift
- Create: Apps/Mac/Sources/Persistence/SQLiteStore.swift
- Create: Apps/Mac/Sources/Persistence/StoreMigrations.swift
- Modify: Apps/Mac/Sources/App/CodingToolsApp.swift
- Modify: Apps/Mac/Sources/UI/State/AppState.swift
- Test: Apps/Mac/Tests/AppTests/AppTests.swift
- Create or modify: Apps/Mac/Tests/PersistenceTests/PersistenceTests.swift

**目标：** 重启后用户的收藏、最近工具和可安全展示的操作历史保持一致，并可迁移和恢复。

- [ ] Step 1: 定义 schema 和迁移。

~~~sql
CREATE TABLE favorites (
  tool_id TEXT PRIMARY KEY,
  updated_at REAL NOT NULL
);

CREATE TABLE recents (
  tool_id TEXT PRIMARY KEY,
  last_used_at REAL NOT NULL
);

CREATE TABLE operations (
  operation_id TEXT PRIMARY KEY,
  tool_id TEXT NOT NULL,
  option_id TEXT NOT NULL,
  adapter_id TEXT NOT NULL,
  state TEXT NOT NULL,
  started_at REAL NOT NULL,
  finished_at REAL,
  error_code TEXT
);
~~~

迁移必须有 schema version，事务内执行，失败时保留原数据库并给出恢复错误。

- [ ] Step 2: 为 Store 写内存 fixture 和 SQLite 行为测试。

覆盖收藏增删、最近去重并按时间排序、操作成功/失败/cancelled 记录、迁移、数据库损坏、并发队列串行化。测试中不得写真实用户的 Application Support。

- [ ] Step 3: 接入真实路径和生命周期。

使用 NSApplicationSupportDirectory/CodingTools/store.sqlite，启动时迁移，退出或操作结束时 flush。开发/测试可注入临时路径；不能继续让生产 AppState 默认使用 InMemoryStore。

- [ ] Step 4: 做日志脱敏和删除策略。

OperationRecord 只存稳定 ID、状态和错误 code；不存命令行完整参数、token、下载签名 URL、绝对用户路径。提供清理历史和随账号/本机数据删除的策略，UI 告知保留范围。

- [ ] Step 5: 做重启验证并提交。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
xcodebuild -project CodingTools.xcodeproj -scheme Persistence -configuration Debug -destination "platform=macOS" test
xcodebuild -project CodingTools.xcodeproj -scheme AppTests -configuration Debug -destination "platform=macOS" test
git diff --check
git add Apps/Mac/Sources/Persistence Apps/Mac/Sources/App/CodingToolsApp.swift Apps/Mac/Sources/UI/State/AppState.swift Apps/Mac/Tests/AppTests Apps/Mac/Tests/PersistenceTests
git commit -m "feat: persist favorites recents and operation history"
~~~

Expected: 重启前后数据一致；迁移和损坏处理有明确 UI 反馈；日志扫描不出现 credential、token、signed URL 等敏感字段。

---

### Task 5: 将 Catalog、安装、启动和错误状态接入真实 UI

**Files:**

- Modify: Apps/Mac/Sources/App/Views/Catalog/CatalogView.swift
- Modify: Apps/Mac/Sources/App/Views/Catalog/ToolDetailView.swift
- Modify: Apps/Mac/Sources/App/Views/Catalog/InstallSheet.swift
- Modify: Apps/Mac/Sources/App/Views/Home/HomeView.swift
- Modify: Apps/Mac/Sources/App/MenuBar/AppMenuBar.swift
- Modify: Apps/Mac/Sources/App/Views/RootView.swift
- Modify: Apps/Mac/Sources/UI/UI.swift
- Modify: Apps/Mac/Sources/Launching/Launching.swift
- Modify: Apps/Mac/Sources/App/Resources/Localizable.xcstrings
- Test: Apps/Mac/Tests/AppTests/AppTests.swift
- Create or modify: Apps/Mac/Tests/UI/ToolFlowUITests.swift

**目标：** 用户看到的是实时事实和下一步动作，不再看到硬编码的 Homebrew、低风险、未安装或 example.com。

- [ ] Step 1: 先写 UI 状态测试。

覆盖：

1. loading 时显示进度，不显示“没有工具”。
2. verified catalog 显示工具卡片。
3. rejected/unavailable 显示原因、重试和离线说明。
4. installed、outdated、notInstalled、blocked、unknown 各显示不同 Badge。
5. 没有可用 install option 时不显示可点击安装按钮。
6. 非法 launch capability 显示不可启动原因，不调用 URL 占位。
7. install 失败仅在 retryable 时显示重试。
8. cancel 后显示 cancelled，按钮可回到详情页。

- [ ] Step 2: 移除 View 内的硬编码事实。

ToolDetailView、InstallSheet、HomeToolCard 使用 ToolViewModel/AppState 提供的 status、risk、options、progress、capability 和 error。SwiftUI Preview 可用 fixture，但生产初始化不能使用 Preview 固定值。

- [ ] Step 3: 统一交互路径。

目录卡片 -> 详情 -> 选择真实 option -> 确认风险和权限 -> 进度 -> 安装后检测 -> 启动/重试。所有异步动作有 disabled/loading 状态，防止双击启动两个 operationID。

- [ ] Step 4: 实现真实 Launching。

Launching.swift 要基于 LaunchCapability 做白名单校验：可执行文件路径来自安装后检测或受控配置；URL 必须使用允许的 scheme 和 host；CLI 参数必须逐项编码。移除 example.com，未实现路径返回 notSupported，并解释如何安装或配置。

- [ ] Step 5: 补菜单栏、空状态、错误状态和可访问性。

AppMenuBar 读取最近使用和真实工具状态；空目录、权限拒绝、网络失败、目录过期、安装取消均有专用文案。为卡片、Badge、进度、重试和菜单项补 accessibilityLabel、keyboard action、Dynamic Type、Reduce Motion 支持。

- [ ] Step 6: 做 UI 验收并提交。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
xcodebuild -project CodingTools.xcodeproj -scheme UI -configuration Debug -destination "platform=macOS" test
xcodebuild -project CodingTools.xcodeproj -scheme AppTests -configuration Debug -destination "platform=macOS" test
git diff --check
git add Apps/Mac/Sources/App/Views Apps/Mac/Sources/App/MenuBar Apps/Mac/Sources/UI Apps/Mac/Sources/Launching Apps/Mac/Sources/App/Resources/Localizable.xcstrings Apps/Mac/Tests/AppTests Apps/Mac/Tests/UI
git commit -m "feat: connect real tool state to catalog and launch UI"
~~~

Expected: 在无真实 Catalog、安装失败、取消、启动不可用时，用户仍能理解当前状态和下一步。

---

### Task 6: 接通 source-aware 最新版本和可信远程内容

**Files:**

- Modify: Apps/Mac/Sources/LatestVersion/LatestVersionProvider.swift
- Modify: Apps/Mac/Sources/LatestVersion/BrewLatestVersionProvider.swift
- Modify: Apps/Mac/Sources/LatestVersion/NpmLatestVersionProvider.swift
- Modify: Apps/Mac/Sources/App/CodingToolsApp.swift
- Modify: Apps/Mac/Sources/Content/Content.swift
- Modify: Apps/Mac/Sources/Content/Loaders/RemoteContentLoader.swift
- Modify: Apps/Mac/Sources/Content/BundledContent.swift
- Test: Apps/Mac/Tests/LatestVersionTests/LatestVersionProviderTests.swift
- Test: Apps/Mac/Tests/CatalogTests/CatalogLoaderTests.swift
- Test: Apps/Mac/Tests/CatalogTests/LocalCatalogLoaderTests.swift

**目标：** 最新版本查询使用上游 source/packageName，而不是把内部 tool.id 当作供应商查询参数；远程内容与本地内容遵守相同可信边界。

- [ ] Step 1: 为 source mapping 写失败测试。

对 Homebrew formula、Homebrew cask、npm package、mise tool name 分别断言 provider 收到正确的上游 ID。测试必须覆盖内部 ID 与上游 ID 不相等的工具。

- [ ] Step 2: 修改 Provider 输入模型。

调用者传入 ToolDefinition 的 source metadata 或 LatestVersionRequest，不允许 provider 自己从产品 ID 猜测。请求日志只记录 provider、safe upstream ID、request result，不记录 token 和签名 URL。

- [ ] Step 3: 将 RemoteCatalogLoader、RemoteContentLoader 作为真实依赖注入。

App 启动策略：

1. 远程成功且 verified -> 使用远程。
2. 网络不可用且本地 bundled verified 且未过期 -> 使用本地。
3. 签名、expiry 或 schema 失败 -> rejected 并提示修复。
4. 不允许 quietly fallback 到未经验证数据。

- [ ] Step 4: 增加缓存和重试语义。

缓存键包含 manifest version/source；只缓存验证后的 payload；指数退避次数和超时有上限；用户点击重试时生成新 request ID 并清除失败状态，不重复显示旧错误。

- [ ] Step 5: 运行测试并提交。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
xcodebuild -project CodingTools.xcodeproj -scheme LatestVersionTests -configuration Debug -destination "platform=macOS" test
xcodebuild -project CodingTools.xcodeproj -scheme CatalogTests -configuration Debug -destination "platform=macOS" test
git diff --check
git add Apps/Mac/Sources/LatestVersion Apps/Mac/Sources/App/CodingToolsApp.swift Apps/Mac/Sources/Content Apps/Mac/Tests/LatestVersionTests Apps/Mac/Tests/CatalogTests
git commit -m "feat: connect source-aware versions and verified content"
~~~

Expected: provider 参数、缓存、过期和离线行为均有测试证据。

---

### Task 7: 完成发布前验证和证据归档

**Files:**

- Modify: Apps/Mac/scripts/build.sh
- Modify: Apps/Mac/scripts/package-release.sh
- Modify: Apps/Mac/scripts/sign-release.sh
- Modify: Apps/Mac/scripts/notarize-release.sh
- Modify: Apps/Mac/scripts/generate-appcast.sh
- Modify: Apps/Mac/scripts/verify-appcast.sh
- Modify: Apps/Mac/scripts/release.sh
- Modify: docs/QA_MATRIX.md
- Modify: docs/RELEASE_WORKFLOW.md
- Create: docs/evidence/2026-08-12-coding-tools/
- Test: 全量测试、Release 构建和干净用户环境验收

**目标：** 形成可审计的证据链，不把“代码已写”升级为“已发布”。

- [ ] Step 1: 运行 Debug、Release 和全量测试。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
./scripts/run-tests.sh
xcodebuild -workspace CodingTools.xcworkspace -scheme CodingTools -configuration Debug -destination "platform=macOS" build
xcodebuild -workspace CodingTools.xcworkspace -scheme CodingTools -configuration Release -destination "platform=macOS" build
~~~

记录：命令、commit、Xcode、macOS、开始结束时间、exit code、warnings、产物路径和 SHA-256。

- [ ] Step 2: 运行静态安全和资源检查。

~~~bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools"
rg -n -i -e "example.com" -e "curl .*\\|.*bash" -e "local-no-signature" -e "try\\?" Apps/Mac/Sources Apps/Mac/Helper
python3 Scripts/verify_catalog.py
git diff --check
~~~

Expected: 不存在生产占位路径、危险安装 fallback、伪签名成功或静默吞错。

- [ ] Step 3: 采集运行时证据。

在独立测试用户或测试机器上记录：

- 首次启动和目录加载；
- 详情、安装 option、权限提示；
- 安装进度、取消、失败、重试、安装后检测；
- 收藏、最近、重启恢复；
- 启动 CLI/GUI；
- 菜单栏；
- 网络断开、目录过期、签名失败；
- 中文/英文、键盘、Reduce Motion 和 VoiceOver 基础路径。

每个结果注明 runtime_verified、环境、commit、时间和截图/日志位置。

- [ ] Step 4: 运行签名、notarization、appcast 和更新检查。

只有用户明确授权并提供签名、Notary、Release 环境时执行。每一步独立保存结果：

~~~bash
./scripts/sign-release.sh
./scripts/notarize-release.sh
./scripts/generate-appcast.sh
./scripts/verify-appcast.sh
~~~

没有授权或凭据时，报告为 not_run/blocked，不得写成 passed。

- [ ] Step 5: 汇总 handoff 并提交文档。

证据目录必须包含：

- baseline.md
- test-results.txt
- build-debug.txt
- build-release.txt
- catalog-security.md
- install-matrix.md
- runtime-acceptance.md
- artifact-sha256.txt
- release-state.md

最后执行：

~~~bash
git status --short --branch
git diff --check
git log -5 --oneline
~~~

Expected: 代码、测试、运行时、签名、Release、更新和用户安装状态分栏呈现；没有证据的项明确标记 unknown、not_run 或 blocked。

---

## 5. 推荐执行顺序

1. Task 1：先恢复版本和测试入口，否则后续绿色结果不可信。
2. Task 2：目录可信边界是所有工具和内容的上游依赖。
3. Task 3：安装参数、Helper 和取消是后端闭环的核心。
4. Task 4：持久化操作和隐私边界。
5. Task 5：把事实接入 UI 和启动。
6. Task 6：接通远程目录、内容和最新版本。
7. Task 7：统一采集工程、运行时和发布证据。

如果 Owner A 和 Owner B 并行，Task 2 的模型/错误契约和 Task 3 的 operation state 先冻结；UI 不得自行定义另一套状态。Task 7 只能在前六项的 P0 风险关闭后执行。

---

## 6. 交付清单

实施负责人交付以下内容后，才移交独立审核：

- [ ] 每个任务都有独立 commit、变更文件清单和测试命令。
- [ ] 代码中不存在生产用 example.com、local-no-signature、curl pipe bash 和吞错式 try?。
- [ ] Catalog、InstallAction、Store、Launcher、OperationState 的接口和错误码文档已更新。
- [ ] 7 个工具/路径的安装参数矩阵和取消/重试记录已完成。
- [ ] AppState 与 UI 的状态映射图或测试覆盖已完成。
- [ ] Debug、Release、test、runtime、package 的证据已归档。
- [ ] 未执行的签名、notarization、远程 Release、Sparkle、干净机安装均明确标注原因。
- [ ] 交付信息写明当前 commit、当前版本、未解决风险、下一步和责任人。

**计划结束。**
