# Coding Tools UI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the 2026-08-14 UI foundation spec: keep the shipped P0 visual/state/update/feedback layer, then add Mac P1 foundations (onboarding, diagnostics, portable user data, catalog cache reset, crash recovery, help) plus leftover P0 polish.

**Architecture:** Domain facts stay in `ToolPresentationMapper`. P1 lives as small Persistence / ProcessExecution / UI types consumed by `AppState` and Settings/Root. No Catalog, installer, or Sparkle rewrite. No default commands for tools without a trusted option.

**Tech Stack:** Swift 6, SwiftUI + AppKit, Tuist modules (`Persistence`, `Catalog`, `ProcessExecution`, `UI`, `App`), XCTest, `Localizable.xcstrings` (zh-Hans + en).

## Global Constraints

- macOS 14+, Universal Binary, Bundle ID `com.codingtools.macos`.
- No remote shell, no silent sudo, no `.zshrc` / `PATH` edits.
- Export/import/diagnostics/GitHub URLs must not include home paths, tokens, env dumps, or signed download URLs.
- Do not invent install options. Views only render `ToolPresentationMapper`.
- Do not launch or copy a new `.app` into `/Applications` on this Mac. Unit tests are the local evidence; runtime/signing/Release stay `not_run` unless separately authorized.
- New user copy must have `zh-Hans` and `en` in `Localizable.xcstrings`.
- App updates and tool updates keep distinct keys.

## Already shipped (do not redo)

v1.5.2/v1.5.3 already contain spec tasks 1–7:

- `DesignTokens` + `AppearancePreference` follow-system restore
- Four-tab `RootView` + tokenized Home/Catalog/Content/Settings
- `ToolPresentationMapper` + card/detail/install/menu bar consumers
- Install sheet close + running-close confirm; no fake install option
- Settings/menu/app-menu Check for Updates + `AppUpdateCheckGuard`
- Support & feedback + diagnostic preview + sanitized GitHub issue URL

Leftover P0 polish in this plan: single-tool latest refresh, copyable path, hide official-artifact URL, leftover hardcoded radii/fonts, card VoiceOver value includes version + action.

---

### Task 1: Settings schema + store corruption recovery

**Files:**
- Create: `Apps/Mac/Sources/Persistence/AppPreferences.swift`
- Modify: `Apps/Mac/Sources/Persistence/FileJSONStore.swift`
- Modify: `Apps/Mac/Sources/Persistence/Persistence.swift` (`Store` + `InMemoryStore`)
- Test: `Apps/Mac/Tests/AppTests/AppPreferencesTests.swift`
- Test: `Apps/Mac/Tests/AppTests/FileJSONStoreTests.swift`

**Interfaces:**
- Consumes: existing `FileJSONStore` atomic write
- Produces: `AppPreferencesDocument`, `AppPreferencesLoadResult`, `AppPreferencesStore.recoverIfNeeded()`, `Store.replaceFavorites`, `Store.replaceRecents`, `Store.resetCatalogCache()`

- [x] **Step 1: Write failing tests** for missing file, v1→v2 migrate, corrupt JSON backup, replace favorites/recents, reset catalog cache.
- [x] **Step 2: Run tests and confirm they fail** because types do not exist.
- [x] **Step 3: Implement `AppPreferencesStore` and store protocol methods.**
- [x] **Step 4: Re-run tests and confirm they pass.** CatalogTests 38 passed; AppTests 109 passed.

```swift
public struct AppPreferencesDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var hasCompletedOnboarding: Bool
    public var lastAcknowledgedCrashAt: Date?
    public static let currentSchemaVersion = 2
}

public enum AppPreferencesLoadResult: Equatable, Sendable {
    case loaded(AppPreferencesDocument)
    case migrated(from: Int, document: AppPreferencesDocument)
    case recoveredFromCorruption(backupName: String)
    case createdDefault(AppPreferencesDocument)
}
```

Corrupt `store.json` / `preferences.json` must be renamed to `*.corrupt-<unix>` and replaced with defaults. Favorites must survive `resetCatalogCache()`.

---

### Task 2: Portable user data

**Files:**
- Create: `Apps/Mac/Sources/Persistence/UserDataPortable.swift`
- Test: `Apps/Mac/Tests/AppTests/UserDataPortableTests.swift`

**Interfaces:**
- Consumes: favorites, recents, theme raw value, language raw value, auto-check/auto-download booleans
- Produces: `UserDataExport` formatVersion 1, `UserDataPortable.encode/decode/validate`

Allowed fields only: `formatVersion`, `exportedAt`, `favorites`, `recents`, `theme`, `language`, `autoCheckUpdates`, `autoDownloadUpdates`.

Reject payloads containing `/Users/<name>`, tokens (`sk-`, `ghp_`, `Bearer `), `PATH=`, or `signed-download`. Tool IDs must match `^[a-z0-9][a-z0-9-]{0,63}$`.

---

### Task 3: Compatibility + crash recovery + catalog cache reset

**Files:**
- Create: `Apps/Mac/Sources/UI/State/CompatibilityCheck.swift`
- Create: `Apps/Mac/Sources/ProcessExecution/CrashRecovery.swift`
- Modify: `Apps/Mac/Sources/Catalog/Catalog.swift` (`FileSystemCatalogCache.reset()`)
- Modify: `Apps/Mac/Sources/UI/State/AppState.swift`
- Test: `Apps/Mac/Tests/AppTests/CompatibilityCheckTests.swift`
- Test: `Apps/Mac/Tests/AppTests/CrashRecoveryTests.swift`
- Test: `Apps/Mac/Tests/CatalogTests/CatalogTests.swift`

**Interfaces:**
- `CompatibilityCheck.evaluate(majorVersion:minimumMajor:architecture:sparklePublicKey:catalogReady:)`
- `CrashRecovery.status(directory:acknowledgedAt:)`
- `AppState.refreshLatestVersion(toolID:)`
- `AppState.resetCatalogCache()`
- `AppState.loadFoundationState()` / `completeOnboarding()` / `acknowledgeCrash()`
- `AppState.exportUserData(...)` / `importUserData(_:)`

macOS < 14 is unsupported. Empty Sparkle public key is a warning, not a crash. Cache reset deletes only `~/Library/Caches/CodingTools/catalog/` contents plus `store.json` catalogCache metadata, then reloads the signed bundled catalog.

---

### Task 4: Settings / Root / leftover P0 views

**Files:**
- Create: `Apps/Mac/Sources/App/Views/Settings/OnboardingSheet.swift`
- Create: `Apps/Mac/Sources/App/Views/Settings/HelpSheet.swift`
- Modify: `SettingsView.swift`, `RootView.swift`, `CodingToolsApp.swift`, `AppMenuBar.swift`
- Modify: `ToolDetailView.swift`, `InstallSheet.swift`, `ContentView.swift`, `HomeView.swift`, `CatalogView.swift`

Behavior:
- First launch shows onboarding (four tabs, trusted sources, no silent sudo, app vs tool updates) plus compatibility summary.
- Settings diagnostics show catalog version / keyID / tool count / expiry / cache status, last crash, open crash folder, refresh, safe reset, export/import, copy diagnostics.
- Help sheet lists shortcuts (`⌘,` `⌘U` Esc Return) and FAQ.
- Unacknowledged crash on launch shows recover/dismiss.
- Detail refresh is current-tool only; path is truncated with copy of the real path; official-artifact preview shows host only.
- Content/home leftover hardcoded fonts/radii use tokens.
- Tool card VoiceOver value includes status + local version + primary action.

---

### Task 5: Localization and open-source docs

**Files:**
- Modify: `Apps/Mac/Sources/App/Resources/Localizable.xcstrings` (zh-Hans + en for every new key)
- Modify: `README.md`, `README.zh-CN.md`, `CHANGELOG.md`, `PROJECT_STATUS.md`, `CONTRIBUTING.md`

Do not add screenshots unless they come from a real isolated runtime. Mark runtime / signing / Release / Sparkle / clean-machine as `not_run`.

---

### Task 6: Verification

Run:

```bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Apps/Mac"
SCHEMES="CatalogTests AppTests" ./scripts/run-tests.sh
```

Also run the default `./scripts/run-tests.sh` if time allows. Do not `open` the app, do not copy to `/Applications`, do not run `release.sh` unless the user later authorizes a Release (spec §20 vs AGENTS.md: this plan follows spec §20).

Evidence to report separately: `local_review`, `local_tests`, `local_build`, `runtime_verified`, `remote_release`, `update_verified`, `user_installed`.
