import Foundation
import SwiftUI
import AppKit

// MARK: - Theme
//
// 浅色 / 深色 / 跟随系统。复用智余项目的 NSApp.appearance 同步方案。
// 阶段 6 由子代理 B 实现；阶段 1 占位。

public enum ThemeMode: String, Hashable, Sendable, CaseIterable, Codable {
    case system
    case light
    case dark

    public var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    @Published public var mode: ThemeMode

    public init(mode: ThemeMode = .system) {
        self.mode = mode
    }

    public func apply(_ mode: ThemeMode) {
        self.mode = mode
        applyAppearancePreference()
    }

    public func applyAppearancePreference() {
        // 同步 NSApp + 所有窗口的 appearance
        let appearance: NSAppearance? = {
            switch mode {
            case .system: return nil
            case .light: return NSAppearance(named: .aqua)
            case .dark: return NSAppearance(named: .darkAqua)
            }
        }()
        NSApp.appearance = appearance
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }
}
