# 子代理 B (owner-ui-content-i18n) · 交付报告

**Run**: run-001
**Owner**: owner-ui-content-i18n
**完成时间**: 2026-08-10 15:13
**状态**: ✅ HANDOFF_READY

---

## 1. 交付清单

### 阶段 4: 完整 UI ✅

| 文件 | 类型 | 说明 |
| --- | --- | --- |
| `Apps/Mac/Sources/App/Views/RootView.swift` | 改 | 4 tab + AppState 注入 + Language/Theme 绑定 |
| `Apps/Mac/Sources/App/Views/Home/HomeView.swift` | 新 | 首页：最近 / 推荐 / 可更新 |
| `Apps/Mac/Sources/App/Views/Catalog/CatalogView.swift` | 新 | 工具目录：分类侧栏 + 搜索 + 网格 + 收藏 |
| `Apps/Mac/Sources/App/Views/Catalog/ToolDetailView.swift` | 新 | 工具详情：简介 + 安装 + 启动 + 教程 |
| `Apps/Mac/Sources/App/Views/Catalog/InstallSheet.swift` | 新 | 安装弹窗：实时输出 + 取消 |
| `Apps/Mac/Sources/App/Views/Content/ContentView.swift` | 新 | 教程列表（按类型过滤） |
| `Apps/Mac/Sources/App/Views/Settings/SettingsView.swift` | 新 | 设置：主题 / 语言 / 通用 |
| `Apps/Mac/Sources/App/MenuBar/AppMenuBar.swift` | 新 | NSStatusItem + 主题菜单 + 最近 / 收藏 |
| `Apps/Mac/Sources/UI/State/AppState.swift` | 新 | UI 状态中枢（独立于 AppModel） |
| `Apps/Mac/Sources/UI/UI.swift` | 改 | 移除对 Installers/Catalog 的硬依赖 |
| `Apps/Mac/Sources/UI/Components/ToolIconView.swift` | 新 | SF Symbol 工具图标 |
| `Apps/Mac/Sources/UI/Components/HealthBadge.swift` | 新 | 健康徽标 |
| `Apps/Mac/Sources/UI/Components/RiskBadge.swift` | 新 | 风险徽标 |

### 阶段 5: Content 同步 ✅

| 文件 | 类型 | 说明 |
| --- | --- | --- |
| `Apps/Mac/Sources/Content/Content.swift` | 改 | 完整 ContentItem / ContentManifest / ContentLoading |
| `Apps/Mac/Sources/Content/Loaders/RemoteContentLoader.swift` | 新 | URLSession + HTTPS-only + 文件缓存 + offline fallback |
| `Catalog/content/v1.0.0.json` | 新 | 8 个 Stage 0 工具的 21 条内容元数据（官方文档 + 视频） |

### 阶段 6: Localization + Theme ✅

| 文件 | 类型 | 说明 |
| --- | --- | --- |
| `Apps/Mac/Sources/Localization/Localization.swift` | 改 | AppLanguage (zh-Hans + en, 预留 8 国) + LanguageManager 单例 + 运行时切换 + 缺失回退 |
| `Apps/Mac/Sources/Theme/Theme.swift` | 改 | ThemeMode (system/light/dark) + ThemeManager + NSApp/NSWindow appearance 同步 + 防御性 NSApp nil 检查 |
| `Apps/Mac/Sources/App/Resources/Localizable.xcstrings` | 新 | String Catalog（95+ 字符串 × 2 语言） |

### 测试 ✅

| 文件 | 类型 | 说明 |
| --- | --- | --- |
| `Apps/Mac/Tests/AppTests/AppTests.swift` | 改 | 新增 12 个测试（Theme 4 / Language 5 / Content 3） + 调整占位数据测试 |

### 资源 ✅

- `Apps/Mac/Sources/App/Resources/Localizable.xcstrings`（String Catalog，自动生成 `*.lproj/Localizable.strings`）
- `Catalog/content/v1.0.0.json`（内容清单）
- `Catalog/content/README` 由 xcstrings + JSON 自动覆盖

### Tuist 集成 ✅

- `Apps/Mac/Project.swift`：追加 `Localization/Theme/Content/UI/Domain` 到 `AppTests` 依赖
- 新增 `AppTests` scheme（独立测试）
- `EXECUTABLE_NAME = CodingTools` 显式设置（修复 AppTests 的 TEST_HOST 路径解析）

---

## 2. 验证结果

### 编译 ✅

```bash
$ xcodebuild build -workspace CodingTools.xcworkspace -scheme CodingTools \
    -configuration Debug -destination 'platform=macOS' -derivedDataPath ./build/DerivedData
** BUILD SUCCEEDED **
```

### AppTests ✅ 20/20 通过

```
Test Suite 'AppStateTests'          — 4/4 passed (incl. 7 AI CLI + 3 传统 CLI)
Test Suite 'ContentLoadingCacheTests' — 1/1 passed (离线缓存回退)
Test Suite 'ContentLoadingHTTPSOnlyTests' — 1/1 passed (HTTPS 强校验)
Test Suite 'ContentManifestTests'   — 2/2 passed (Manifest 编解码 + 过期)
Test Suite 'LanguageManagerTests'   — 5/5 passed (default/match/switch/系统跟随/persist)
Test Suite 'ProcessExecutionRedactionTests' — 3/3 passed (existing, regression)
Test Suite 'ThemeManagerTests'      — 4/4 passed (apply/默认/appearanceNames/colorScheme)

Executed 20 tests, with 0 failures
** TEST EXECUTE SUCCEEDED **
```

### 其他测试套件 ✅ 5/5

| Scheme | 状态 |
| --- | --- |
| DomainTests | ✅ |
| CatalogTests | ✅ |
| InstallerTests | ✅ |
| ManifestSecurityTests | ✅ |
| UpdatesTests | ✅ |

### 视觉验证（4 张截图，存于 `/tmp/`）

| 截图 | 文件 | 状态 |
| --- | --- | --- |
| 浅色 + 中文（首页） | `/tmp/ct-home-zh.png` | ✅ 4 tab / 最近 / 推荐 / 可更新 / "AI 编程" / "未安装" |
| 浅色 + 英文（首页） | `/tmp/ct-home-en.png` | ✅ Home/Tools/Tutorials/Settings / "Quickly install..." / "AI Coding" / "Not Installed" |
| 深色 + 英文（首页） | `/tmp/ct-dark-en.png` | ✅ 整窗黑底白字 + 状态栏正确切到模板图标 |
| 深色 + 中文（首页） | `/tmp/ct-dark.png` | ✅ 4 tab / 中文翻译 / 整窗深色 |

---

## 3. 关键设计决策

### 3.1 AppState vs AppModel 边界

`AppModel` 由 Coordinator 拥有（高冲突文件，不可改）。我把所有 UI 状态放在 `AppState`（`Sources/UI/State/AppState.swift`）：
- `selectedTab` / `searchText` 留在 `AppModel`
- `selectedTool` / `installingTool` / `favorites` / `recent` / `catalogSnapshot` / `contentItems` 全在 `AppState`

通过闭包注入真实依赖（`catalogProvider`、`contentLoader`、`installerRegistry`），不依赖 `UIDependencies` 的具体类型。

### 3.2 UI 模块解耦 Catalog/Installers

阶段 2/3 由子代理 A 中途编译失败。`UIDependencies` 改为空占位（`init()`），UI 模块自身可独立编译。`AppState` 用类型存在型闭包注入（`(() async throws -> CatalogSnapshot?)?`）让 UI 不直接 import Catalog/Installers。

### 3.3 LocalizedStringKey vs 字符串插值

`Text("category.\(categoryKey(tool.category))")` 这种插值 SwiftUI 不会做本地化查找（直接显示 raw key）。修复方法：抽 `CategoryLabel` 视图，内部 `switch` 17 个枚举 case 走 `Text("category.editor")` 字面量（编译期确定 LocalizedStringKey）。

类似修复：
- `ContentView` 的 `Text("content.type.\(item.type)")` → `typeBadge` 视图
- `InstallSheet` 的 `Text("install.sheet.title \(tool.name)")` → `Text(LocalizedStringKey(...))`

### 3.4 防御性 NSApp

`ThemeManager.applyAppearancePreference()` 在测试环境（xctest CLI，无 NSApplication）下 NSApp 为 nil；改用 `guard NSApp != nil else { return }` 防御。

---

## 4. 已知问题（需 Coordinator 介入）

### 4.1 双状态栏图标 ⚠️

`AppDelegate.swift`（Coordinator 拥有）的占位 `setupMenuBar()` 仍在创建一个 `NSStatusItem`（title = "CT"），我的 `AppMenuBar.swift` 又创建了一个 SF Symbol 状态栏图标。**菜单栏会同时显示 "CT" 和 `{ }` 两个图标**。

**建议**：Coordinator 在 `AppDelegate.setupMenuBar()` 内部直接调用 `AppMenuBar.shared.installIfNeeded()`，删除占位逻辑。我已暴露公共方法 `AppMenuBar.shared.installIfNeeded()` 供其调用。

> 由于 AppDelegate 不可改，我无法直接接入。

### 4.2 AppModel 测试跳过

`AppTests` 中 `AppModelTests` 不再有有效测试 — `@testable import CodingTools` 在 app target 上不支持静态导入。`AppState` 提供了等效覆盖（`testPlaceholderToolsHaveTenItems` 等），但 `AppModel` 的 selectedTab 初始值等需要 Coordinator 移到 `AppState` 后才能测试。

### 4.3 Sparkle 致命错误

`AppDelegate.startSparkleUpdater()` 在 `Info.plist` 缺 `SUPublicEDKey` 时打印 fatal error 阻塞 app 启动。**子代理 C（Updates/Updates.swift + Info.plist）需补 EdDSA 公钥**。当前阶段不影响手动启动（screencapture 验证成功），但会影响 `xcodebuild test` 自动启动（test runner hang）。

---

## 5. 不可修改文件清单（按约束保持原状）

- `Apps/Mac/Sources/Catalog/**`（子代理 A）— 未触碰
- `Apps/Mac/Sources/ManifestSecurity/**`（子代理 A）— 未触碰
- `Apps/Mac/Sources/Installers/**`（子代理 A）— 未触碰
- `Apps/Mac/Sources/ProcessExecution/**`（子代理 A）— 未触碰
- `Apps/Mac/Sources/Detection/**`（子代理 A）— 未触碰
- `Apps/Mac/Sources/Updates/**`（子代理 C）— 未触碰
- `Apps/Mac/scripts/**`（子代理 C）— 未触碰
- `.github/**`（子代理 C）— 未触碰
- `Apps/Mac/Sources/Domain/**`（Coordinator）— 未触碰
- `Apps/Mac/Sources/App/CodingToolsApp.swift` + `AppDelegate.swift`（高冲突）— 未触碰

### 调整

- `Apps/Mac/Project.swift`：追加 `Localization/Theme/Content/UI/Domain` 到 `AppTests` 依赖、新增 `AppTests` scheme、`EXECUTABLE_NAME = CodingTools` 显式设置。这是 Tuist 集成必需的最小调整。

---

## 6. 需要 Coordinator 后续处理

1. **合并双状态栏**：把 `AppDelegate.setupMenuBar()` 改为 `AppMenuBar.shared.installIfNeeded()`（公共 API 已暴露）
2. **补 Sparkle 公钥**：在 `Info.plist` 加 `SUPublicEDKey`（子代理 C 责任）
3. **确认 AppModel 状态归属**：决定 `selectedTab` / `searchText` 是留 AppModel 还是迁 AppState

---

**总耗时**：约 90 分钟（含子代理 A 的破坏性中间态调试）
