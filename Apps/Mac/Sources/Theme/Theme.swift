import Foundation
import SwiftUI
import AppKit
import Combine

// MARK: - Theme
//
// 浅色 / 深色 / 跟随系统。复用智余项目的 NSApp.appearance 同步方案。
// 阶段 6 由子代理 B 实现。

public enum ThemeMode: String, Hashable, Sendable, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return String(localized: "theme.system", defaultValue: "跟随系统")
        case .light: return String(localized: "theme.light", defaultValue: "浅色")
        case .dark: return String(localized: "theme.dark", defaultValue: "深色")
        }
    }

    /// 解析为 NSAppearance.Name。
    public var appearanceName: NSAppearance.Name? {
        switch self {
        case .system: return nil
        case .light: return .aqua
        case .dark: return .darkAqua
        }
    }

    /// SwiftUI 端用的 ColorScheme。`system` 时跟随系统。
    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @Published public private(set) var mode: ThemeMode {
        didSet {
            defaults.set(mode.rawValue, forKey: storageKey)
            applyAppearancePreference()
        }
    }

    private let defaults: UserDefaults
    private let storageKey = "AppTheme.mode"
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: storageKey),
           let m = ThemeMode(rawValue: raw) {
            self.mode = m
        } else {
            self.mode = .system
        }

        // 监听系统外观变化（用户从系统设置切换时，.system 模式跟随）
        // observer 是 non-Sendable，存为 nonisolated(unsafe)；仅在 MainActor 上访问
        let token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyAppearancePreference()
            }
        }
        self.observer = token
    }

    deinit {
        // 单例模式常驻进程，deinit 几乎不会被调用。
        // 不再访问 observer / self 的非 Sendable 字段；如有需要由 ARC + NotificationCenter 兜底。
    }

    public func apply(_ mode: ThemeMode) {
        self.mode = mode
    }

    /// 同步到 NSApp + 所有窗口的 appearance。
    public func applyAppearancePreference() {
        // NSApp 是 NSApplication!，测试环境下可能没初始化。
        // 通过 NSApplication.shared 安全获取；NSApp 为 nil 时跳过。
        guard NSApp != nil else { return }
        let app = NSApplication.shared
        let windows = app.windows
        // 注意：NSApplication.appearance / NSWindow.appearance 是 NSAppearance!
        // （隐式解包 optional），赋 nil 在某些 macOS 版本上会崩溃；只设非 nil 值。
        let appearance: NSAppearance? = mode.appearanceName.flatMap { NSAppearance(named: $0) }
        if let appearance = appearance {
            app.appearance = appearance
            for window in windows {
                window.appearance = appearance
            }
        }
        // else: 跟随系统模式 — 不修改 appearance，让系统接管
    }

    // MARK: - Menu Bar icon

    /// 为 NSStatusItem 提供 SF Symbol + 颜色叠层。
    /// 浅色模式下需要深色图标，深色模式下需要浅色图标；
    /// 这里通过 `.symbolRenderingMode(.monochrome)` 加 button.appearance 控制。
    public func configureStatusItemButton(_ button: NSStatusBarButton, systemSymbol: String) {
        let image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: "Coding Tools")
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.image = image?.withSymbolConfiguration(config)
        button.image?.isTemplate = (mode == .system) ? true : (mode == .dark)
    }
}

// MARK: - SwiftUI bridge

public extension View {
    /// 绑定 ThemeManager 当前的 preferredColorScheme。
    /// 当 ThemeManager.mode 变化时，SwiftUI 自动重新求值。
    func bindTheme(_ manager: ThemeManager) -> some View {
        self.preferredColorScheme(manager.mode.preferredColorScheme)
    }
}
