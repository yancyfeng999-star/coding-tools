import AppKit
import SwiftUI
import Localization
import Theme
import UI
import Domain

/// 菜单栏快速入口：最近使用 / 收藏 / 主题切换 / 打开主窗口。
/// 阶段 4 由子代理 B 实现。**注意**：AppDelegate 已经创建了 "CT" 占位
/// statusItem，这里我们自建一个并独立工作；重复问题写到 outbox 通知 Coordinator。
@MainActor
public final class AppMenuBar: ObservableObject {
    public static let shared = AppMenuBar()

    private var statusItem: NSStatusItem?
    private weak var state: AppState?

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

        menu.addItem(.separator())

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

    // MARK: - Actions

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
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
}
