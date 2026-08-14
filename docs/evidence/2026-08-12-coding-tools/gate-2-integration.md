# Gate 2 — Frontend/Backend Integration & Installation Audit

## 概要

**结论**：**BLOCKED**。前后端接入链存在多处**会让安装直接失败或显示错误信息**的 P0：

- UI → AdapterRegistry.execute 链路中，**`InstallAction` 在 `adapter.execute(plan)` 调用时被丢弃**，导致 `NpmGlobalAdapter` / `OfficialArtifactAdapter` 立刻 `preconditionFailed`。
- `HomebrewAdapter.execute()` 用 `plan.toolID` 当 brew 包名，对 `docker-desktop`/`nodejs`/`rust` 等 24 个工具中至少 8 个**必定失败**。
- 安装弹窗（InstallSheet）和详情页（ToolDetailView）的「来源 / 风险 / 操作」**全部写死为 Homebrew + low**，与实际 catalog 不一致。
- 取消按钮仅改 UI 状态，**不取消 Task、不停止进程**。
- `HelperClient`（XPC）**没有任何生产调用**；App 进程内直接 `ProcessExecutor` 跑 npm/curl。

Plan §5 中所列 P0 条件，至少 4 项被命中。

---

## 1. Call-chain 表（Plan §5）

| 层 | 现状 | 证据 |
|---|---|---|
| Catalog | InstallOption 的 adapter、packageName 等字段在 JSON 中正确 | Catalog/tools/*.json 全部 24 条 schema 合规（除了签名） |
| View | 用户选择"安装"时只 set `state.installingTool = tool`，**不传 installOption** | ToolDetailView.swift:73-82 |
| AppState | `startInstall(tool)` 取 `tool.installOptions.first`，调 `installerRegistry.execute(toolID, action, ...)` | AppState.swift:303-340 |
| InstallerService | **不存在独立层**；`installerRegistry = .defaultRegistry()` 直接被 AppState 调用 | AppState.swift:71 |
| AdapterRegistry | `execute(toolID, action, ...)` 内调 `adapter.plan(toolID, action)` 后调 `adapter.execute(plan, progress)` —— **action 在此丢弃** | Installers.swift:152-170 |
| AdapterRegistry | `defaultRegistry()` 注册 5 个 adapter；`HelperClient` 不在内 | Installers.swift:134-142 |
| Adapter | `HomebrewFormulaAdapter`/`HomebrewCaskAdapter` 用 `plan.toolID` 当包名；`NpmGlobalAdapter`/`OfficialArtifactAdapter` 必须有 `pendingActions[plan.id]` | HomebrewAdapter.swift:96, NpmGlobalAdapter.swift:44-49, OfficialArtifactAdapter.swift:62-65 |
| Helper | **未连入生产路径** | grep `HelperClient(` in Sources → 0 命中 |
| ProcessExecutor | 进程内直接 `/bin/sh -c 'curl ... \| bash'`（NpmGlobalAdapter L83） | NpmGlobalAdapter.swift:81-85 |
| Detection | `InstallationDetector` 通过 `which` + `probeCLI`/`probeApp` 真实运行 | Detection.swift:53-80 |
| Store | **未接入**：AppState 用内存集合存 favorites/recent；`favoriteProvider` 默认为 nil | AppState.swift:30-32, 68-69 |
| UI | 成功 / 失败 / 取消 三态；取消仅改 UI | AppState.swift:355-358 |

---

## 2. P0 发现详情

### P0-G2-1 — AdapterRegistry.execute 丢失 InstallAction

**位置**：`Apps/Mac/Sources/Installers/Installers.swift:152-170`

**证据**：

```swift
public func execute(
    toolID: String,
    action: InstallAction,                       // ← 接到了
    progress: InstallProgressHandler? = nil
) async throws -> InstallResult {
    ...
    let plan = try await adapter.plan(toolID: toolID, action: action)   // ✓ action 传给 plan
    return try await adapter.execute(plan, progress: progress)          // ✗ action 丢失
}
```

而 `NpmGlobalAdapter.execute` (L44-49)：

```swift
public func execute(_ plan: InstallPlan, progress: ...) async throws -> InstallResult {
    guard let action = pendingActions[plan.id],                  // ← 查不到
          case .npmGlobal(...) = action else {
        throw InstallError.preconditionFailed("NpmGlobalAdapter requires the caller to pass an InstallAction via executeAction(...)")
    }
```

`pendingActions[plan.id]` 仅在 `executeWithAction(...)` 调用时设置（L107）。**生产路径 `installerRegistry.execute` 永远不会设置**，因此：

| Tool | 预期行为 | 实际行为 |
|---|---|---|
| claude-code / codex / gemini-cli / openclaw / opencode / grok-build / hermes | `npm install -g <pkg>` 或 fallback curl\|bash | 立刻 `preconditionFailed`，UI 显示「失败」 |
| docker-desktop / postman (cask) | `brew install --cask <pkg>` | HomebrewAdapter 用 toolID 当 pkg 名，结果 brew 找不到包 → exitCode ≠ 0 → UI 显示「失败」 |
| 任何 official-artifact | 下载 + 校验 + 打开 | 立刻 `preconditionFailed` |

**影响**：用户在 UI 看到的"安装"结果与实际 catalog 期望严重不一致。24 个工具中至少 21 个**根本无法通过 UI 完成安装**。

### P0-G2-2 — HomebrewAdapter.execute 用 toolID 当包名

**位置**：`Apps/Mac/Sources/Installers/HomebrewAdapter.swift:79-97`

**证据**：

```swift
// 解决：plan.toolID = toolID；package name 通过 toolID 反查（约定
// toolID == packageName）。对 Stage 0 8 个工具都成立。
var fullArgs = args
fullArgs.append(plan.toolID)         // ← 用 toolID，不是 packageName
```

Catalog 实际 `toolID` vs `packageName`：

| toolID | packageName | `brew install <toolID>` 是否成功 |
|---|---|---|
| docker-desktop | docker | ❌（无 formula/cask `docker-desktop`） |
| nodejs | node | ❌（formula 名是 `node`） |
| rust | rustup-init | ❌（formula 名是 `rustup-init`，且 brew 已弃用） |
| python | python@3.12 | ❌（实际 catalog 写了 `python@3.12`，toolID=python 错配） |
| git / fzf / jq / tmux / vim / neovim / htop / ripgrep / lazygit / lazydocker / go / gh | 同名 | ✅ |

**影响**：13 个 Homebrew tool 中 4 个必然失败，1 个 brew 名错配。InstallerTests 只 stub-adapter 测试，没覆盖该路径。

### P0-G2-3 — UI 写死显示 Homebrew + low 风险

**位置**：`InstallSheet.swift:32-37, 50-53`；`ToolDetailView.swift:29-34, 100`

**证据**：

```swift
// InstallSheet header
Text(LocalizedStringKey("install.source homebrew-formula"))    // ← 写死 Homebrew
RiskBadge(level: .low)                                          // ← 写死低风险
```

```swift
// InstallSheet preview
row("来源", value: "Homebrew Formula")
row("操作", value: "brew install \(tool.slug)")                  // ← 用 slug 当 pkg 名
row("预计变化", value: "安装 CLI 到 /opt/homebrew")              // ← 假设 /opt/homebrew
```

```swift
// ToolDetailView header
RiskBadge(level: .low)                                          // ← 写死
installOptionRow(type: "homebrew-formula", description: "brew install \(tool.slug)")  // ← 写死
installOptionRow(type: "mise-tool", description: "mise use \(tool.slug)@latest")     // ← 写死
```

**与 catalog 实际行为对比**：

| Tool | UI 显示 | 实际 |
|---|---|---|
| claude-code | Homebrew / low / `brew install claude-code` | npm `npm install -g @anthropic-ai/claude-code` |
| docker-desktop | Homebrew / low / `brew install docker-desktop` | `brew install --cask docker`（包名错 + cask 错） |
| grok-build / hermes | Homebrew / low / `brew install grok-build` | **`curl https://x.ai/cli/install.sh \| bash`**（任意代码执行） |
| nodejs | Homebrew / low / `brew install nodejs` | HomebrewFormulaAdapter 用 toolID=`nodejs` 当包名，必失败 |

**影响**：**用户在 UI 看到的来源、风险、操作全部错误**。Plan §5 P0 条件 #1：「UI 显示安装成功但没有真实 process/detection 证据」对应；#4：「启动入口打开占位网站或未校验的用户可控 URL」间接对应（ContentLinkRow 用 NSWorkspace.open 打开未签名 sourceURL）。

### P0-G2-4 — ContentLinkRow 用 NSWorkspace.open 打开未签名 URL

**位置**：`ToolDetailView.swift:140-148`

```swift
private struct ContentLinkRow: View {
    let item: ContentItem
    var body: some View {
        Button {
            if item.sourceURL.scheme == "https" {
                NSWorkspace.shared.open(item.sourceURL)    // ← 直接打开
            }
        } label: { ... }
```

`item` 来自 `state.contentFor(toolID:)` → `ContentManifest.items`（`Content/v1.0.0.json`，无 signature/keyID，参见 P0-G1-4）。攻击者若能控制 content（MITM、未签名 CDN），可注入任意 HTTPS 钓鱼/恶意下载 URL，App 会直接 NSWorkspace.open。

**Plan §7 风险**：与 P0-G4-x 对应——启动入口打开未校验 URL。

### P0-G2-5 — HelperClient 无生产调用

**位置**：搜索 `HelperClient(` in `Apps/Mac/Sources`，**0 命中**。

**证据**：`HelperClient.swift`、`HelperProtocol.swift` 完整实现（155 行 + 246 行），NSXPCConnection、4 个 IPC 方法、wire 协议、invalidation handler 全部就绪。但 `AppState.startInstall` → `installerRegistry.execute` → `AdapterRegistry.execute` → `adapter.execute(plan)`，**全程未触碰 Helper**。所有安装命令由 App 进程内 `ProcessExecutor()` 直接 `/bin/sh -c "..."` 执行**未沙箱化**。

**项目方声明（PROJECT_STATUS L79-80）**：
> - NpmGlobalAdapter 切换到走 HelperClient（阶段 9 二期）
> - HomebrewAdapter / MiseToolAdapter / OfficialArtifactAdapter 迁移到 Helper（阶段 9 三期）

确认 Helper 仅"架构就位"，未接入。

**Plan §5 P0 条件 #5**：「生产安装路径或 Helper 没有实际接通，却对外宣称完成」—— 命中。

### P0-G2-6 — 取消只改 UI 状态

**位置**：`AppState.swift:355-358`

```swift
public func cancelInstall() {
    installState = .cancelled
    installLog += "\n[用户取消]"
}
```

**对比**：
- `startInstall` 内部用 `Task { @MainActor in ... }` 启动 install（L307），**Task 句柄未保存**
- `cancelInstall` **不调用 `Task.cancel()`**、**不调用 `installerRegistry.adapter(for: ...).cancel(planID:)`**
- 各 adapter 内部 `cancel(planID:)` 仅保留 API 不维护本地状态（`NpmGlobalAdapter:97`、`OfficialArtifactAdapter:131`、`HomebrewAdapter:126`）

**影响**：用户点"取消"后，UI 显示 cancelled，但 `ProcessExecutor` 仍在运行；npm install / brew install / curl 都将继续；用户的 `installLog` 仍会持续收到新行，直到进程自然结束。

**Plan §5 P0 条件 #3**：「取消只改变 UI，不停止真实进程」—— 命中。

---

## 3. P1 发现

### P1-G2-1 — AdapterRegistry 默认注册的 HomebrewAdapter 共享 executor，无并发控制

`AdapterRegistry.defaultRegistry()` 注册 5 个 adapter，每个持 `ProcessExecutor()` 实例。同一进程并发跑 `brew install` + `npm install` 时，`ProcessExecutor` 之间的并发模型未在源码中显式说明。

### P1-G2-2 — Detect 与 Install 间的 race

`startInstall` 完成后**未触发 `refreshProbe(toolID:)`**。需等用户手动刷新或下一次 `refreshProbes()`。CHANGELOG L15 提到的「latest version + installed version」比较因此在 install 完成后会持续显示旧 version 直到下次 refresh。

### P1-G2-3 — UI 未禁用重复 install 按钮

`state.installState == .running` 时 `InstallSheet` 显示 Cancel/Close，但 ToolDetailView 的 toolbar「安装」按钮（L73-82）始终可点。用户可在 install 进行中再次触发 startInstall，覆盖 installingTool 与 installLog。

### P1-G2-4 — 进度无单调保证

`InstallProgress` 没有 sequence number，UI 仅追加日志。若 progress 回调乱序（理论可能在多 Task 间发生），日志会出现时间倒流。

### P1-G2-5 — 失败后无 retryable 判断

`InstallRunState.failed` 后只能 `closeInstall`。`InstallError` 枚举有 `cancelled`、`timeout`、`failed`、`adapterUnavailable` 等，但 UI 不区分 retryable vs permanent，全部相同失败提示。

### P1-G2-6 — AdapterRegistry 默认值"5 个 adapter 全注册"无错误检查

`r.register(HomebrewFormulaAdapter())` 等调用若抛错不会传播。`testDefaultRegistryRegistersAllTypes` 验证注册成功，但生产路径无法验证 AdapterRegistry 构造成功。

---

## 4. Plan §5 安装参数矩阵复核

| 场景 | 必核验参数 | 实际代码是否传入 | 证据 |
|---|---|---|---|
| Claude Code / npm | action.packageName、版本约束、registry | **action 丢失** | AdapterRegistry.execute 不传 action |
| Codex CLI / npm | action.packageName | 同上 | 同上 |
| Docker / Homebrew cask | formula/cask 类型和 packageName | **type 对，packageName 用 toolID 错** | HomebrewAdapter.execute L96 |
| Node / Mise | action.toolName | **ToolDetailView 写死，不读 tool.installOptions** | ToolDetailView L29-34 |
| Python / Mise | action.toolName | 同上 | 同上 |
| Rust / Mise | action.toolName | 同上 | 同上 |
| 官方 Artifact | downloadURL、archiveType、checksum、destination | action 丢失 | AdapterRegistry.execute L169 |
| 不支持选项 | blocked/unsupported 错误 | AdapterRegistry 抛 `adapterUnavailable`（Installers.swift:166） | 通过 |

**8 项中 7 项不通过**。

---

## 5. Plan §5 P0 条件复核

| P0 条件 | 触发？ | 证据 |
|---|---|---|
| UI 显示安装成功但没有真实 process/detection 证据 | ✅ | UI 写死显示 Homebrew / low / brew install slug，与实际 catalog 行为不符（grok-build 是 curl\|bash，docker-desktop 是 cask docker） |
| AdapterRegistry 丢失 action | ✅ | P0-G2-1 |
| 用户可控内容构成任意命令执行 | ✅ | P0-G1-5 + P0-G2-3：grok-build/hermes 的 url 字段未签名流入 curl\|bash |
| 取消只改变 UI，不停止真实进程 | ✅ | P0-G2-6 |
| Helper 只存在源码声明，没有生产调用链，且产品把安装写成已接通 | ✅ | P0-G2-5 + CHANGELOG [1.2.5] 称"XPC Helper 架构就位"（误导：仅 Helper 自身就位，未接入生产） |

**5 项 P0 条件全部命中**。

---

## 6. Gate 2 结论

| 维度 | 状态 |
|---|---|
| View → AppState 接线 | **断（ToolDetailView 不传 installOption）** |
| AppState → AdapterRegistry | **断（action 在 AdapterRegistry.execute 中丢失）** |
| AdapterRegistry → Adapter | **断（Homebrew 用错字段、Npm/Official 必抛 preconditionFailed）** |
| Adapter → Helper | **未接通** |
| UI 展示的来源 / 风险 / 操作 | **与 catalog 实际不一致** |
| 取消行为 | **只改 UI** |
| 安装后 Detection 触发 | **未触发**（需手动 refresh） |
| Store 持久化 | **未接入**（favorites/recent 内存态） |

**Gate 2 决定**：**BLOCKED**

**解除条件（最小集）**：

1. `AdapterRegistry.execute(toolID, action, ...)` 改为在 `adapter.execute(plan, progress, action)` 传递 action；或者将 action 编码进 `InstallPlan`（metadata）。
2. 或：在 `AdapterRegistry.execute` 中按 adapter 类型调用 `adapter.executeWithAction(action, plan: ...)`；删除或重命名旧的 `execute(plan)` 接口以避免误用。
3. `HomebrewAdapter.execute` 接收完整 InstallAction，使用 `case .homebrewFormula(let name)` / `.homebrewCask(let name)` 的 name，而非 `plan.toolID`。
4. `InstallSheet`、`ToolDetailView` 改为从 `tool.installOptions` 渲染；显示 `opt.riskLevel` 而非写死 `.low`；显示 `opt.type` 真实文案而非 `homebrew-formula`。
5. `startInstall` 保存 Task 句柄，`cancelInstall` 调用 `Task.cancel()` 并 dispatch 到对应 adapter 的 `cancel(planID:)`。
6. AppState.install 完成分支调用 `await refreshProbe(toolID: tool.id)`。
7. `HelperClient` 接入生产路径（即使是 fallback 也比无好）：`installerRegistry.execute` 默认走 HelperClient，Helper 不可用时回退到 in-process executor。
8. `ContentLinkRow` 改为白名单（仅允许与 tool.category 对应的官方域）或要求 sourceURL 经过签名验证。

---

**Gate 2 审核结束。下一步：Gate 3（状态、持久化和隐私审核）。**