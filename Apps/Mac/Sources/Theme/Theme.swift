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
        // didSet does not run during init; apply the persisted mode now.
        applyAppearancePreference()

        // 系统外观变化时，跟随系统模式必须重新应用 inherit（nil）。
        let token = NotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
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

    /// 同步到 NSApp + 所有窗口的 appearance。跟随系统时必须清成 inherit。
    public func applyAppearancePreference() {
        guard NSApp != nil else { return }
        let app = NSApplication.shared
        AppearancePreference.apply(mode, application: app, windows: app.windows)
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

    func tokenFont(_ role: DesignTokens.TypeRole) -> some View {
        font(role.font)
    }
}

// MARK: - Appearance restore

/// 把 ThemeMode 应用到 App 和已有窗口。`.system` 必须赋 `nil` 才能恢复继承。
public enum AppearancePreference {
    public static func apply(_ mode: ThemeMode, application: NSApplication, windows: [NSWindow]) {
        let appearance = mode.appearanceName.flatMap { NSAppearance(named: $0) }
        application.appearance = appearance
        for window in windows {
            window.appearance = appearance
        }
    }
}

// MARK: - Design tokens

public enum DesignTokens {
    public enum Space {
        public static let space1: CGFloat = 4
        public static let space2: CGFloat = 8
        public static let space3: CGFloat = 12
        public static let space4: CGFloat = 16
        public static let space5: CGFloat = 20
        public static let space6: CGFloat = 24
        public static let space8: CGFloat = 32
    }

    public enum Radius {
        public static let badge: CGFloat = 6
        public static let card: CGFloat = 8
        public static let panel: CGFloat = 10
    }

    public enum TypeRole {
        case pageTitle
        case sectionTitle
        case itemTitle
        case body
        case supporting
        case metadata
        case tinyMetadata
        case code
        case compactCode

        public var font: Font {
            switch self {
            case .pageTitle: return .title2.weight(.semibold)
            case .sectionTitle: return .headline.weight(.semibold)
            case .itemTitle: return .body.weight(.semibold)
            case .body: return .body
            case .supporting: return .callout
            case .metadata: return .caption
            case .tinyMetadata: return .caption2
            case .code: return .system(.body, design: .monospaced)
            case .compactCode: return .system(.caption, design: .monospaced)
            }
        }
    }

    public enum Palette {
        public static var appBackground: Color { Color(nsColor: .windowBackgroundColor) }
        public static var contentBackground: Color { Color(nsColor: .controlBackgroundColor) }
        public static var elevatedSurface: Color { Color(nsColor: .underPageBackgroundColor) }
        public static var selectedSurface: Color { Color.accentColor.opacity(0.12) }
        public static var hoverSurface: Color { Color.primary.opacity(0.05) }
        public static var subtleBorder: Color { Color.primary.opacity(0.10) }
        public static var strongBorder: Color { Color.primary.opacity(0.32) }
        public static var primaryText: Color { Color.primary }
        public static var secondaryText: Color { Color.secondary }
        public static var tertiaryText: Color { Color.secondary.opacity(0.75) }
        public static var accent: Color { Color.accentColor }
        public static var success: Color { Color(nsColor: .systemGreen) }
        public static var warning: Color { Color(nsColor: .systemOrange) }
        public static var danger: Color { Color(nsColor: .systemRed) }

        public static func border(increaseContrast: Bool) -> Color {
            increaseContrast ? strongBorder : subtleBorder
        }

        public static func borderWidth(increaseContrast: Bool) -> CGFloat {
            increaseContrast ? 2 : 1
        }
    }

    public static func animation(reduceMotion: Bool, duration: Double = 0.15) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: min(max(duration, 0.12), 0.18))
    }
}
