import AppKit
import SwiftUI
import Localization
import Theme
import UI
import Domain
import Updates

/// 菜单栏快速入口：最近使用 / 收藏 / 主题切换 / 检查更新 / 打开主窗口。
@MainActor
public final class AppMenuBar: ObservableObject {
    public static let shared = AppMenuBar()

    private var statusItem: NSStatusItem?
    private weak var state: AppState?
    /// Sparkle 更新状态 provider：AppDelegate 注入。
    /// 返回 nil 时不显示更新区。
    public var updateStateProvider: (() -> UpdateState?)?
    /// 触发 Sparkle 检查更新的 provider：AppDelegate 注入。
    public var checkForUpdatesProvider: (() -> Void)?
    /// 切到 Settings tab：AppDelegate 注入。
    public var openSettingsProvider: (() -> Void)?

    /// 由 RootView 在 appearance 时调用。
    public func attach(state: AppState) {
        self.state = state
        installIfNeeded()
    }

    private func installIfNeeded() {
        if statusItem != nil { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton(item)
        item.menu = buildMenu()
        statusItem = item
    }

    private func configureButton(_ item: NSStatusItem) {
        guard let button = item.button else { return }
        // 用 SF Symbol 暂代彩色 logo。模板模式 + 主题同步：
        // - 浅色模式：黑色模板
        // - 深色模式：白色模板
        // - 跟随系统：交给 NSStatusItem button.appearance
        let symbol = "curlybraces"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Coding Tools")
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.image = image?.withSymbolConfiguration(config)
        button.image?.isTemplate = true
        button.title = ""
    }

    private var language: LanguageManager { LanguageManager.shared }

    public func refreshMenu() {
        guard let item = statusItem else { return }
        item.menu = buildMenu()
    }

    // MARK: - Menu construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(headerItem("Coding Tools"))
        menu.addItem(.separator())

        // Open main window
        let openMain = NSMenuItem(
            title: language.localized("menubar.openMain", fallback: "Open Coding Tools"),
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openMain.target = self
        openMain.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: "Open")
        menu.addItem(openMain)

        // Settings
        let settingsItem = NSMenuItem(
            title: language.localized("tab.settings", fallback: "Settings"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Updates
        if let updateItem = makeUpdateMenuItem() {
            menu.addItem(updateItem)
            menu.addItem(.separator())
        }

        // Recent
        if let state = state, !state.recentTools().isEmpty {
            let recentItem = NSMenuItem(
                title: language.localized("menubar.recent", fallback: "Recent"),
                action: nil,
                keyEquivalent: ""
            )
            let submenu = NSMenu()
            for tool in state.recentTools().prefix(5) {
                let item = NSMenuItem(
                    title: tool.name,
                    action: #selector(launchTool(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = tool.id
                submenu.addItem(item)
            }
            recentItem.submenu = submenu
            menu.addItem(recentItem)
        }

        // Favorites
        if let state = state, !state.favoriteTools().isEmpty {
            let favItem = NSMenuItem(
                title: language.localized("menubar.favorites", fallback: "Favorites"),
                action: nil,
                keyEquivalent: ""
            )
            let submenu = NSMenu()
            for tool in state.favoriteTools().prefix(5) {
                let item = NSMenuItem(
                    title: tool.name,
                    action: #selector(launchTool(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = tool.id
                submenu.addItem(item)
            }
            favItem.submenu = submenu
            menu.addItem(favItem)
        }

        menu.addItem(.separator())

        // Theme
        let themeItem = NSMenuItem(
            title: language.localized("menubar.theme", fallback: "Theme"),
            action: nil,
            keyEquivalent: ""
        )
        let themeMenu = NSMenu()
        for mode in ThemeMode.allCases {
            let item = NSMenuItem(
                title: mode.displayName,
                action: #selector(switchTheme(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            if ThemeManager.shared.mode == mode {
                item.state = .on
            }
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        menu.addItem(.separator())

        // Report Issue / Send Feedback（GitHub Issues new issue + Discussions）
        let report = NSMenuItem(
            title: language.localized("menubar.reportIssue", fallback: "Report Issue"),
            action: #selector(reportIssue),
            keyEquivalent: ""
        )
        report.target = self
        report.image = NSImage(systemSymbolName: "exclamationmark.bubble", accessibilityDescription: "Report")
        menu.addItem(report)

        let feedback = NSMenuItem(
            title: language.localized("menubar.feedback", fallback: "Send Feedback"),
            action: #selector(sendFeedback),
            keyEquivalent: ""
        )
        feedback.target = self
        feedback.image = NSImage(systemSymbolName: "envelope", accessibilityDescription: "Feedback")
        menu.addItem(feedback)

        menu.addItem(.separator())

        // Quit
        let quit = NSMenuItem(
            title: language.localized("menubar.quit", fallback: "Quit"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func headerItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// 根据 Sparkle updateState 构造菜单项：
    /// - .available / .readyToInstall → 蓝色"可更新到 v1.x.y"
    /// - .downloading / .installing → 灰色"下载中/安装中 N%"
    /// - 其他 → 不显示
    private func makeUpdateMenuItem() -> NSMenuItem? {
        guard let state = updateStateProvider?() else { return nil }
        switch state {
        case .available(let remote, _, _):
            let item = NSMenuItem(
                title: language.localized("menubar.availableUpdate \(remote)", fallback: "Update available: \(remote)"),
                action: #selector(checkForUpdates),
                keyEquivalent: "u"
            )
            item.target = self
            item.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Update")
            return item
        case .downloading(let progress, _, _):
            let item = NSMenuItem(
                title: language.localized("home.update.downloading \(Int(progress * 100))",
                                        fallback: "Downloading \(Int(progress * 100))%"),
                action: nil,
                keyEquivalent: ""
            )
            item.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Downloading")
            item.isEnabled = false
            return item
        case .readyToInstall(let remote):
            let item = NSMenuItem(
                title: language.localized("home.update.readyToInstall \(remote)",
                                        fallback: "\(remote) ready to install"),
                action: #selector(checkForUpdates),
                keyEquivalent: "u"
            )
            item.target = self
            item.image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Ready to install")
            return item
        case .installing:
            let item = NSMenuItem(
                title: language.localized("home.update.installing", fallback: "Installing…"),
                action: nil,
                keyEquivalent: ""
            )
            item.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Installing")
            item.isEnabled = false
            return item
        default:
            return nil
        }
    }

    // MARK: - Actions

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openSettings() {
        openSettingsProvider?()
        openMainWindow()
    }

    @objc private func checkForUpdates() {
        checkForUpdatesProvider?()
    }

    @objc private func launchTool(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let tool = state?.tools.first(where: { $0.id == id }) else { return }
        state?.markRecent(id)
        // 占位启动（阶段 3 接入 MacLauncher 后由依赖驱动；这里只打开 homepage）
        if let url = URL(string: "https://example.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func switchTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ThemeMode(rawValue: raw) else { return }
        ThemeManager.shared.apply(mode)
        refreshMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Feedback / Issue

    /// 打开 GitHub Issues new issue 页面（带模板：版本 / 系统 / 复现步骤）。
    @objc private func reportIssue() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let sysVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let title = "[v\(version)+\(build) · \(sysVersion)] "
        var components = URLComponents(string: "https://github.com/yancyfeng999-star/coding-tools/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.md"),
            URLQueryItem(name: "title", value: title),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    /// 打开 GitHub Discussions（轻量反馈 / 想法）。
    @objc private func sendFeedback() {
        if let url = URL(string: "https://github.com/yancyfeng999-star/coding-tools/discussions/new?category=ideas") {
            NSWorkspace.shared.open(url)
        }
    }
}
