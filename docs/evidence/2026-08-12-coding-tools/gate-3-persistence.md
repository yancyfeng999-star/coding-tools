# Gate 3 — State, Persistence & Privacy Audit

## 概要

**结论**：**CONDITIONAL**。

- 持久化层**完全是 stub**：`Persistence.swift` 只有 `InMemoryStore`，**无 SQLite 实现**。AppState 的 `favoriteProvider`/`favoriteSaver` 默认为 nil，**重启即丢失收藏与最近使用**。
- `OutputRedactor` 实现了 Bearer / basic auth / 用户路径 / GitHub PAT / PEM 脱敏，但**未覆盖 progress 消息**与 `installLog` 的拼接。
- `AIConfig` 暴露 `configPath`（绝对路径）与 `hasAPIKey` Bool 给 `@Published` SwiftUI 状态——可接受但需记录。
- `ProcessExecutor` 拒绝 `sh/bash/zsh/csh/tcsh` 作为 `executableURL`，但 `NpmGlobalAdapter` 仍以 `/bin/sh -c` 调用——会被 `shellForbidden` 拦截（这是一道安全网，不视为绕过）。

---

## 1. 持久化层

### 1.1 `Persistence` framework 的全部产出

```
$ find Apps/Mac/Sources/Persistence -name "*.swift"
Apps/Mac/Sources/Persistence/Persistence.swift   (55 行)
```

文件全文结构：
- `protocol Store` — 9 个方法（saveInstallation / loadInstallations / saveFavorite / removeFavorite / loadFavorites / saveCatalog / loadLatestCatalog + implicit actor conformance）
- `actor InMemoryStore: Store` — 唯一实现，**纯内存**

**没有任何 `SQLiteStore` / `GRDBStore` / `StoreMigrations` / `StoreFactory`**。

注释（L8）声称：「计划使用 GRDB（成熟、稳定、支持加密）」—— 这是计划，非现实。

### 1.2 AppState 持久化依赖

`AppState.swift:67-69`：
```swift
/// 收藏 / 加载接口（占位：阶段 2 接入后替换为 Store）
public var favoriteProvider: ((String) async -> [String])?
public var favoriteSaver: ((String, Bool) async -> Void)?
```

- 默认值 **nil**
- `CodingToolsApp.swift` 的启动代码未注入 provider / saver
- `toggleFavorite` 调用 `Task { await favoriteSaver?(toolID, true) }` —— provider 为 nil 时静默 no-op

```swift
public func toggleFavorite(_ toolID: String) {
    if favorites.contains(toolID) {
        favorites.remove(toolID)
        Task { await favoriteSaver?(toolID, false) }   // ← nil 时 no-op
    } else {
        favorites.insert(toolID)
        Task { await favoriteSaver?(toolID, true) }    // ← nil 时 no-op
    }
}
```

`recent`（最多 10 个 toolID）：
```swift
@Published public var recent: [String] = []
...
public func markRecent(_ toolID: String) {
    recent.removeAll(where: { $0 == toolID })
    recent.insert(toolID, at: 0)
    if recent.count > 10 { recent = Array(recent.prefix(10)) }
}
```

`recent` **完全没有 Store 接入**——纯内存数组。

### 1.3 重启验证（静态推断，无法跑 runtime）

最小重启验收（Plan §6）：
1. 启动 → 收藏 A，打开 B，记录操作 ✓（内存）
2. 退出 → 进程结束 ✓（无后台）
3. 再启动 → 验证 A 仍收藏 ← **失败**：`favoriteProvider` nil
4. 验证 B 在最近列表 ← **失败**：`recent` 内存数组无持久化
5. 清理历史 → 只清理历史表 ← **失败**：无历史表，无清理 API

**结论**：收藏、最近使用**完全没有持久化**。

---

## 2. P0 发现

### P0-G3-1 — 收藏 / 最近使用仅内存，重启丢失（Plan §6 标 P1，但 plan §1 风险已写）

**位置**：`Persistence.swift:55 行（stub）`；`AppState.swift:30-32, 68-69`

**证据**：见 §1.1、§1.2。

**影响**：
- 用户每次重启都看到空收藏与空最近使用
- 与 Plan §6 "最小重启验收" 期望完全不一致

### P0-G3-2 — `installLog` 拼接 progress message 不脱敏

**位置**：`AppState.swift:318-321`

```swift
let progress: InstallProgressHandler = { [weak self] p in
    Task { @MainActor in
        self?.installLog += "[\(p.stage.rawValue)] \(p.message)\n"
    }
}
```

**证据**：`p.message` 由各 adapter 构造，未经过 `OutputRedactor.redact`：
- `NpmGlobalAdapter.swift:73-74`：`"npm failed, falling back to script \(scriptURL?.absoluteString ?? "")"` ← **脚本 URL 直接进 UI**
- `NpmGlobalAdapter.swift:79`：`"Running install script \(url.absoluteString)"` ← 同样
- `HomebrewAdapter.swift:98`：`"Running \(brew.path) \(fullArgs.joined(separator: " "))"` ← 含 brew path（用户 home）
- `OfficialArtifactAdapter.swift:68`：`"Downloading \(url.lastPathComponent)"` ← 含 URL 末段

**对照**：`ProcessExecutor.awaitExit` 内部对 `stdout`/`stderr` 走 `OutputRedactor.redact`（L313, L315）；但 progress 消息（adapter 自构字符串）**未脱敏**。

**影响**：如果某天 catalog 引入含 `user:password@host/install.sh` 的 url，UI 上 installLog 会原样显示。

### P0-G3-3 — `discoveredConfigs` 暴露绝对路径与 API key 存在性

**位置**：`AppState.swift:44`、`AIConfig.swift:11-19`、`FilesystemAIConfigDiscovery.swift:104-113`

**证据**：
- `@Published public var discoveredConfigs: [AIConfig] = []`
- `AIConfig.configPath: URL`（绝对路径如 `/Users/yancyfeng/.claude/settings.json`）
- `AIConfig.hasAPIKey: Bool`（仅布尔，不含 key 值——符合规范）

**影响**：
- 任何 SwiftUI 视图绑定 `state.discoveredConfigs` 即可拿到绝对 home 路径
- 若 ProcessExecutor 的 `redact` 模式未覆盖完整路径（已覆盖 `/Users/<name>/`，OK），UI 直接绑定则不被脱敏
- `@Published` 状态在内存，进程崩溃转储或调试时可能被读到

**项目方声称**（FilesystemAIConfigDiscovery.swift L14）：「只读顶层字段，不读任何 *_key / *_token / *_secret 字段」—— 实现确实只检测 `apiKeyFieldNames` 字段名存在，未读 value。但 `readTopLevel` 内部把**所有** string 值存入 `fields` dict（L130-133），虽然不暴露给 `AIConfig`，但 `ParsedTop` 局部变量在 `scanOne` 栈上驻留；若启用某种 logging / debug print，可能漏出。

---

## 3. P1 发现

### P1-G3-1 — 无 Store 实现导致 AIConfigDiscovery 无 fallback

`AppState.swift:193`：`public func discoverAIConfigs() async { ... configDiscoverer.discover() ... }`

`configDiscoverer: AIConfigDiscovering = FilesystemAIConfigDiscovery()` 默认实例化。

`discover()` 返回 `[]` 时（路径不存在 / JSON 损坏），UI 无法区分「未配置」与「扫描失败」—— 两者都呈现为空数组。

Plan §6 P1 条件 #4：「UI 的配置扫描依赖缺失时直接显示"未配置"」—— 命中。

### P1-G3-2 — 无 Catalog / Content 持久化

`SaveableStore.saveCatalog(_:)` 协议方法存在，但**无任何调用点**：
```
$ rg -n "saveCatalog" Apps/Mac/Sources
(只有 Persistence.swift 协议定义)
```

`loadLatestCatalog()` 同样无调用点。`FileSystemCatalogCache` 单独存在（`Catalog.swift:86-147`），但与 Store 协议无关。

### P1-G3-3 — 无清理操作历史 API

Plan §6 验收 #5 要求「清理历史」—— 当前无任何 `clearHistory()`、`clearOperations()`、`resetStore()` 等接口。

### P1-G3-4 — `OutputRedactor` 未覆盖 npm token / AWS key / 通用 API key

`ProcessExecution.swift:237-254` 的正则列表：
- ✅ Authorization: Bearer
- ✅ URL basic auth
- ✅ /Users/<name>/...
- ✅ GitHub PAT (ghp_/gho_/ghs_/ghu_)
- ✅ HOME/PATH/SHELL/API_KEY/SECRET/TOKEN/PASSWORD=
- ✅ PEM private key block

**未覆盖**：
- npm 令牌（`npm_xxxxxxxx`）
- AWS access key（`AKIAxxxxxxxx`）
- Anthropic key（`sk-ant-...`）、OpenAI key（`sk-...`）
- 数据库连接字符串（postgres://user:pass@host）

`FilesystemAIConfigDiscovery.readTopLevel` 不读 secret（仅检测存在性），但 `installLog` / 未来 log 中若包含这些 token 会原样保留。

### P1-G3-5 — 进程崩溃日志写到 stderr

`ProcessExecution/CrashReporter.swift:270-273`：
```swift
fputs("=== Coding Tools crash ===\n", stderr)
fputs(str, stderr)
fputs("\n=== saved to ", stderr)
fputs(cpath, stderr)
```

崩溃日志写到 stderr 同时也写到 `cpath` 文件。`str` 已经过 `redactor`（L84-86），但 stderr 这份未走 redact（fputs 是直接写）。

### P1-G3-6 — AppState.@Published state 无派生状态保护

`@Published var installingTool: Tool?` 在 install 进行中始终可被 `state.installingTool = tool` 覆盖（ToolDetailView L74），造成 installTask 与 installingTool 不一致。无 invariant 保证。

---

## 4. Plan §6 P0/P1 条件复核

| 条件 | 类型 | 触发？ |
|---|---|---|
| 收藏或最近使用仅保存在内存，重启丢失 | P1 | ✅ P0-G3-1 |
| 迁移失败没有恢复说明或会覆盖原数据库 | P1 | ⚠️ 当前无迁移（无 SQLite 实现）；不适用，但同样未达验收 |
| 日志暴露供应商凭据、完整下载 URL 或私有路径 | P1 | ✅ P0-G3-2（P0-G3-3 含路径） |
| UI 的配置扫描依赖缺失时直接显示"未配置" | P1 | ✅ P1-G3-1 |

**4 项中 4 项命中**。

---

## 5. Gate 3 结论

| 维度 | 状态 |
|---|---|
| 收藏 / 最近使用持久化 | **未实现（P0）** |
| Catalog / Content 缓存持久化 | **未实现（P1）** |
| 操作历史持久化 | **未实现（P1）** |
| 崩溃日志脱敏与持久化 | **部分实现（P1）** |
| AIConfigDiscovery 三态区分 | **未实现（P1）** |
| installLog 脱敏 | **未实现（P0）** |
| Store 协议与实现 | **协议存在、实现为空（P0）** |

**Gate 3 决定**：**CONDITIONAL**（非 BLOCKED，但有 P0 — 收藏 / installLog 脱敏是 plan §6 标 P1；但若按 plan §1 风险登记严格执行「P0 即 BLOCKED」，则升级为 BLOCKED。）

**解除条件（最小集）**：

1. 实现 `SQLiteStore`（GRDB 或 SQLite.swift），并提供 migration；接入到 `favoriteProvider` / `favoriteSaver`。
2. 给 `recent` 增加 Store 接入（`saveRecent(toolID:)` / `loadRecent()`），重启恢复。
3. `installLog` 拼接前对 `p.message` 调用 `OutputRedactor.redact`；或仅在 adapter 内构造 progress message 时直接 redact。
4. `OutputRedactor` 增补 npm token / AWS key / Anthropic-OpenAI key 规则。
5. `AIConfigDiscovery` 返回 `[AIConfig]` 区分「扫描失败」状态（增加 `.failed(reason:)` case 或 Result 类型）。
6. `CrashReporter` 写到 stderr 之前也走 redactor。

---

**Gate 3 审核结束。下一步：Gate 4（用户体验和运行时审核）。**