# Gate 4 — UX & Runtime Audit

## 概要

**结论**：**BLOCKED**。

- 菜单栏启动入口打开 `https://example.com` —— Plan §4 明确禁止；代码注释自承「占位」。
- InstallSheet / ToolDetailView 的「来源 / 风险 / 操作」**与实际 catalog 行为严重不符**（已在 Gate 2 详述）。
- HomeView 多个 StatCard 用**硬编码中文**作为 label，绕过 Localizable.xcstrings；声称的 7 语言本地化在主页统计区不生效。
- HomeToolCard 永远 `HealthBadge(status: .notInstalled)`，即便工具已装也会显示"未安装"。
- 取消按钮不停止进程、ToolDetailView 安装按钮不传 installOption、CatalogView 卡片按钮 set installingTool 后 InstallSheet 仍按写死 Homebrew 显示。
- ContentLinkRow 直接 `NSWorkspace.open` 任意 https URL（来源 Content manifest 无签名，P0-G1-4 已记录）。

---

## 1. 场景表（Plan §7）

| 场景 | 观察点 | 实测 | 通过？ |
|---|---|---|---|
| 首次启动 | Catalog loading、空状态、错误状态 | catalogProvider 用 `try?` 吞错（Gate 1 P0-G1-3） | ❌ |
| 目录成功 | 卡片、搜索、详情 | CatalogView 卡片 OK，但 ToolDetailView 的 install 选项写死 | ⚠️ |
| 目录过期/拒绝 | reason、retry、offline 文案 | 无验签，目录永远 "verified" | ❌ |
| 详情页 | option、风险、来源、版本 | **写死 Homebrew + low + brew install <slug>**（Gate 2 P0-G2-3） | ❌ |
| 安装中 | 阶段、进度、禁用重复操作 | AppState.startInstall 启动 Task 但 installingTool 不一致；按钮未禁用 | ❌ |
| 取消 | cancelling、停止、结果 | **仅改 UI 不停进程**（Gate 2 P0-G2-6） | ❌ |
| 安装失败 | 错误原因、retryable | UI 显示"失败"+ stderr 文本；无 retry 按钮 | ⚠️ |
| 安装成功 | 检测、版本、launch | startInstall 完成分支不调 refreshProbe | ❌ |
| 启动失败 | capability、路径、修复建议 | **AppMenuBar.launchTool 打开 https://example.com**（P0-G4-1） | ❌ |
| 收藏/最近 | 立即反馈、重启恢复 | UI OK；**重启丢失**（Gate 3 P0-G3-1） | ❌ |
| 菜单栏 | 最近工具、真实状态、入口 | 最近/收藏 OK，但 launch 走 example.com | ❌ |
| 中文/英文 | 文案、截断、动态尺寸 | HomeView StatCard 硬编码中文 | ⚠️ |
| 可访问性 | keyboard、VoiceOver、Reduce Motion | 简单 Tab + button；未做 Reduce Motion 验证 | not_run |

---

## 2. P0 发现详情

### P0-G4-1 — 菜单栏启动入口打开 https://example.com

**位置**：`Apps/Mac/Sources/App/MenuBar/AppMenuBar.swift:272-280`

```swift
@objc private func launchTool(_ sender: NSMenuItem) {
    guard let id = sender.representedObject as? String,
          let tool = state?.tools.first(where: { $0.id == id }) else { return }
    state?.markRecent(id)
    // 占位启动（阶段 3 接入 MacLauncher 后由依赖驱动；这里只打开 homepage）
    if let url = URL(string: "https://example.com") {
        NSWorkspace.shared.open(url)
    }
}
```

**Plan §4 表格**："启动失败 | capability、路径、修复建议 | 不打开 example.com"

**Plan §7 P0 条件**："启动入口打开占位网站或未校验的用户可控 URL" —— 命中。

**影响**：菜单栏点击任意工具（包括 docker-desktop、grok-build）都打开 example.com，不响应 `tool.launchCapability` 字段。

`Tool.launchCapability` 已有完整定义（`Domain/LaunchCapability.swift`）：
- `case cli(command, arguments, openInTerminal)` → 应调 `ProcessExecutor.run([command] + arguments)` 或在 Terminal 打开
- `case app(bundleID)` → `NSWorkspace.urlForApplication(withBundleIdentifier:)`
- `case url(url)` → `NSWorkspace.open(url)`（需要白名单）

但 `launchTool` 完全忽略 `tool.launchCapability`，写死 example.com。

### P0-G4-2 — HomeToolCard 永远显示「未安装」

**位置**：`HomeView.swift:238`

```swift
HStack(alignment: .top) {
    ToolIconView(toolID: tool.id, category: tool.category, size: 40)
    Spacer()
    HealthBadge(status: .notInstalled)   // ← 写死 notInstalled
}
```

**对照 CatalogView.ToolCard**（L206）：`HealthBadge(status: health)` 用 `state.probe(for: tool.id)?.healthStatus ?? .notInstalled` —— 正确。

但 HomeView 用写死的 `.notInstalled`。即使用户已安装 git，首页推荐区仍显示「未安装」。

### P0-G4-3 — HomeView StatCard 硬编码中文

**位置**：`HomeView.swift:81-83`

```swift
StatCard(title: "工具", value: "\(snapshot.tools.count)", icon: "shippingbox.fill", color: .blue)
StatCard(title: "已收藏", value: "\(state.favorites.count)", icon: "star.fill", color: .yellow)
StatCard(title: "最近", value: "\(state.recent.count)", icon: "clock.fill", color: .green)
```

`Localizable.xcstrings` 中存在 `工具` 键（L4452）、`已安装`/`未安装`（L1642/L1683）等；但 `StatCard(title:)` 接收 `String`，不是 `LocalizedStringKey`，故 SwiftUI 不会走本地化查找。

**Plan §4 场景表**："中文/英文 | 文案、截断、动态尺寸 | 无关键硬编码英文或乱码"

**影响**：用户切到 en / ja / ko / fr / de / es 后，首页统计区仍显示中文标签。其他区域（tab / section title）正确本地化。

### P0-G4-4 — InstallSheet 写死 Homebrew + low

**位置**：`InstallSheet.swift:32-37, 50-53`

```swift
Text(LocalizedStringKey("install.source homebrew-formula"))   // 写死
RiskBadge(level: .low)                                          // 写死
...
row("来源", value: "Homebrew Formula")                          // 写死
row("操作", value: "brew install \(tool.slug)")                  // 写死
row("预计变化", value: "安装 CLI 到 /opt/homebrew")              // 写死
```

`tool.installOptions.first` 完全不被读；显示的 type 永远是 `homebrew-formula`，risk 永远是 low，操作永远是 `brew install <slug>`。

**Plan §4 场景表**："详情页 | option、风险、来源、版本 | 不写死 Homebrew 或低风险" —— 命中。

### P0-G4-5 — ToolDetailView install options 写死 brew + mise

**位置**：`ToolDetailView.swift:29-34`

```swift
section(titleKey: "tool.section.install") {
    VStack(alignment: .leading, spacing: 10) {
        // 占位：阶段 3 接入后由 InstallAdapter.plan() 提供
        installOptionRow(type: "homebrew-formula", description: "brew install \(tool.slug)")
        installOptionRow(type: "mise-tool", description: "mise use \(tool.slug)@latest")
    }
}
```

`tool.installOptions` 完全不被读；tool.slug 当 pkg 名。对 npm/cask/curl|bash/official-artifact 类型工具全部错误。

`RiskBadge(level: .low)`（L100）也是写死。

### P0-G4-6 — ContentLinkRow 打开任意 HTTPS URL

**位置**：`ToolDetailView.swift:140-148`

```swift
private struct ContentLinkRow: View {
    let item: ContentItem
    var body: some View {
        Button {
            if item.sourceURL.scheme == "https" {
                NSWorkspace.shared.open(item.sourceURL)
            }
        }
```

`item.sourceURL` 来自 `Content/v1.0.0.json`（无签名，见 P0-G1-4）。任何攻击者控制 Content 即可注入任意 https URL；NSWorkspace 直接打开。

**Plan §4 P0 条件**："启动入口打开占位网站或未校验的用户可控 URL" —— 命中。

### P0-G4-7 — 取消不停止进程（Gate 2 复用）

**位置**：`AppState.cancelInstall()` 不调 `Task.cancel()`、不调 adapter `cancel(planID:)`。

`InstallSheet` 写死"install.cancel"按钮触发 `state.cancelInstall()`，UI 立刻 `.cancelled` 状态，但 brew/npm/curl 进程仍跑、installLog 持续刷新。

---

## 3. P1 发现

### P1-G4-1 — ToolDetailView 的 install 按钮设置 installingTool 但不传 installOption

```swift
Button {
    state.installingTool = tool
}
```

`InstallSheet` 接 `tool: Tool`，但不传 `tool.installOptions.first`。InstallSheet preview 写死显示（见 P0-G4-4）。

### P1-G4-2 — CatalogView 卡片 install 按钮同样不传 installOption

```swift
Button {
    state.installingTool = tool
}
```

但好在 CatalogView.ToolCard 的 `RiskBadge(level: tool.riskLevel)` 正确从 tool 读。InstallSheet 仍然写死。

### P1-G4-3 — RootView.loadFavorites() 在 provider=nil 时 no-op

```swift
.task {
    await state.loadCatalogIfNeeded()
    await state.loadContentIfNeeded()
    await state.loadFavorites()    // ← nil provider, no-op
    menuBar.attach(state: state)
    menuBar.refreshMenu()
}
```

`loadFavorites`（AppState.swift L279-283）：
```swift
public func loadFavorites() async {
    guard let provider = favoriteProvider else { return }    // ← nil 立即返回
    let list = await provider("all")
    favorites = Set(list)
}
```

**影响**：每次启动 `favorites = Set()`，menu bar 不显示收藏区。`tool.favorite` sidebar 始终空。

### P1-G4-4 — RootView.loadContentIfNeeded 失败时只显示 BundledContent + toast

AppState L246-256：远端加载失败时 catch 块 emit toast；内容回退到 `BundledContent.items`。但 BundledContent 是什么未读。`BundledContent.items` 静态定义，未验证存在。

### P1-G4-5 — 推荐区 = tools.prefix(4)

HomeView L195：`Array(state.tools.prefix(4))`。无任何排序、过滤、安装状态判断。

### P1-G4-6 — 发现配置按钮直接 adopt，但不启动

DiscoveredConfigRow L451-457：
```swift
Button {
    state.adoptDiscoveredConfig(config)
}
```

`adoptDiscoveredConfig` 仅 `favorites.insert(config.toolID)`。用户看到 AI CLI 配置后无法「打开配置文件」或「跳到安装」。

### P1-G4-7 — LaunchCapability 的"command"和"arguments"参数被忽略

`launchTool` 写死 example.com，不读 `tool.launchCapability.command` / `arguments` / `openInTerminal`。

### P1-G4-8 — `openSettingsProvider` 在通知路径额外开窗口

`RootView.L60-67`：codingToolsOpenSettings 通知触发时 `appModel.selectedTab = .settings` + 调 `NSApp.activate` + 循环 `makeKeyAndOrderFront`。如果用户已经打开主窗口，再开窗口会重复。

### P1-G4-9 — `AppDelegate.shared?.pendingDeepLink` 是静态可选

`RootView.L69`：`AppDelegate.shared?.pendingDeepLink` 通过单例访问。如果 AppDelegate 没初始化或被回收，deep link 静默丢失。无错误反馈。

---

## 4. Plan §7 P0 条件复核

| 条件 | 触发？ | 证据 |
|---|---|---|
| 用户点击安装后 UI 成功，但没有真实执行或检测 | ✅ | P0-G2-1 + P0-G2-3：UI 显示 Homebrew/low 但 adapter 立即 preconditionFailed |
| 失败/取消导致 UI 永久 loading 或错误地显示成功 | ⚠️ | 取消只改 UI（不算永久 loading）；installState 切换正常 |
| 私有内容、未经验证内容或任意 URL 可直接进入用户流程 | ✅ | P0-G4-6 ContentLinkRow + P0-G1-4 Content 无签名 |
| 启动入口打开占位网站或未校验的用户可控 URL | ✅ | P0-G4-1 example.com |

**4 项中 3 项命中**。

---

## 5. Gate 4 结论

| 维度 | 状态 |
|---|---|
| CatalogView | **部分 OK**（搜索/过滤/收藏 toggle 正确） |
| ToolDetailView | **多 P0**（写死 brew/low/不读 installOptions） |
| InstallSheet | **多 P0**（写死 brew/low/不读 catalog 实际行为） |
| HomeView | **多 P1**（推荐 = prefix 4；StatCard 硬编码中文；HomeToolCard 永远 notInstalled） |
| AppMenuBar | **多 P0**（launchTool example.com） |
| DeepLink | **P1**（rootL69 单例访问） |
| Localization | **不完整**（StatCard 硬编码中文） |
| 可访问性 | **未验证**（Reduce Motion / VoiceOver） |
| 取消流程 | **P0**（不停止进程） |
| Discovery UI | **P1**（仅收藏，无 jump-to-install） |

**Gate 4 决定**：**BLOCKED**

**解除条件（最小集）**：

1. `AppMenuBar.launchTool` 改为分发到 `tool.launchCapability`：
   - `.cli` → `ProcessExecutor.run([command] + arguments)` 或 `open -a Terminal "<command> <args>"`
   - `.app` → `NSWorkspace.urlForApplication(withBundleIdentifier:)?.open()`
   - `.url` → 仅当 host 在白名单（如 `docs.docker.com`、`git-scm.com` 等 catalog 声明的官方域）才打开
2. `InstallSheet` / `ToolDetailView` install option 区改为遍历 `tool.installOptions`；`RiskBadge(level: opt.riskLevel)`；`opt.type` 渲染本地化文案；操作行用 `opt.toInstallAction()` 真实预览命令。
3. `HomeView` `HealthBadge` 改用 `state.probe(for: tool.id)?.healthStatus ?? .notInstalled`。
4. `HomeView.StatCard.title` 改为 `LocalizedStringKey`；新增 `home.stats.tools` / `home.stats.favorites` / `home.stats.recent` 三个 key。
5. `RootView.loadFavorites` 在 nil provider 时显示 toast「收藏功能未启用」而不是静默 no-op。
6. `ContentLinkRow` 增加 host 白名单或要求 sourceURL 经过签名验证。
7. `cancelInstall()` 改为 `Task.cancel()` + `installerRegistry.adapter(for: type)?.cancel(planID:)`；UI 状态切到 `.cancelling`，进程退出后切 `.cancelled`。

---

**Gate 4 审核结束。下一步：Gate 5（测试、构建和发布证据审核）。**