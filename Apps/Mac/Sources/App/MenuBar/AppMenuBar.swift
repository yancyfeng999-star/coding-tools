import AppKit
import SwiftUI
import Localization
import Theme
import UI
import Domain
import Updates
import ProcessExecution

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
        let logo = Bundle.main.url(forResource: "CodingToolsLogo", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
        let statusImage = logo
            ?? NSImage(systemSymbolName: "curlybraces", accessibilityDescription: "Coding Tools")
        statusImage?.size = NSSize(width: 18, height: 18)
        statusImage?.isTemplate = false
        button.image = statusImage
        button.image?.accessibilityDescription = "Coding Tools"
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
        let header = headerItem("Coding Tools")
        if let logoURL = Bundle.main.url(forResource: "CodingToolsLogo", withExtension: "png"),
           let logo = NSImage(contentsOf: logoURL) {
            logo.size = NSSize(width: 16, height: 16)
            logo.isTemplate = false
            header.image = logo
        }
        menu.addItem(header)
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
        // P0-G4-1 修复：分发到 tool.launchCapability（cli / app / url+白名单）
        guard let cap = tool.launchCapability else {
            state?.toastCenter?.show(Toast(
                kind: .warning,
                messageKey: "menubar.launch_error",
                messageArg: "no launch capability"
            ))
            return
        }
        switch cap.type {
        case .cli:
            launchCLI(command: cap.command ?? tool.slug, arguments: cap.arguments, openInTerminal: cap.openInTerminal)
        case .app:
            launchApp(bundleID: cap.bundleID ?? tool.id)
        case .url:
            launchURL(cap.url?.absoluteString ?? tool.homepageURL.absoluteString)
        case .none:
            launchURL(tool.homepageURL.absoluteString)
        }
    }

    /// CLI 工具启动：用 `/usr/bin/env` 跑二进制并把输出重定向到 /dev/null，
    /// 或在 Terminal 打开（如果 openInTerminal = true）。
    private func launchCLI(command: String, arguments: [String], openInTerminal: Bool) {
        // PATH 搜索最常见路径
        let candidates = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)",
            "\(NSHomeDirectory())/.local/bin/\(command)",
            "\(NSHomeDirectory())/.cargo/bin/\(command)",
        ]
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let pathCandidates = pathEnv.split(separator: ":").map { "\($0)/\(command)" }
        let allCandidates = candidates + pathCandidates
        guard let exe = allCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
        else {
            state?.toastCenter?.show(Toast(
                kind: .warning,
                messageKey: "menubar.launch_error",
                messageArg: "binary not found: \(command)"
            ))
            return
        }
        if openInTerminal {
            let script = "'\(exe)'" + arguments.map { " '\\(\($0))'" }.joined()
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"))
            _ = script  // 真实路径需要 AppleScript 桥；此处降级到直接 open
            return
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: exe)
        proc.arguments = arguments
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try? proc.run()
    }

    /// App 工具启动：按 bundle id 找 .app 然后 open。
    private func launchApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            state?.toastCenter?.show(Toast(
                kind: .warning,
                messageKey: "menubar.launch_error",
                messageArg: "app not found: \(bundleID)"
            ))
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// URL 启动：仅允许白名单 host（与 ContentLinkRow 同一白名单）。
    private func launchURL(_ urlString: String?) {
        guard let urlString,
              let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            state?.toastCenter?.show(Toast(
                kind: .warning,
                messageKey: "menubar.launch_error",
                messageArg: "no url"
            ))
            return
        }
        let trusted: Set<String> = [
            "github.com", "docs.docker.com", "git-scm.com",
            "nodejs.org", "python.org", "go.dev", "rust-lang.org",
            "npmjs.com", "brew.sh", "mise.jdx.dev", "opencode.ai",
            "anthropic.com", "openai.com", "google.dev", "x.ai",
            "hermes-agent.nousresearch.com", "openclaw.ai", "developer.apple.com",
        ]
        let allowed = trusted.contains(host) || trusted.contains(where: { host.hasSuffix(".\($0)") })
        guard allowed else {
            state?.toastCenter?.show(Toast(
                kind: .warning,
                messageKey: "content.url_blocked",
                messageArg: host
            ))
            return
        }
        NSWorkspace.shared.open(url)
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
