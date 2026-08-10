import Foundation
import SwiftUI
import Combine

// MARK: - Localization
//
// 中英文 + 运行时切换。完整实现见 docs/PRODUCT_SPEC.md §5。
// 架构预留：日语、韩语、法语、德语、西班牙语、葡萄牙语、俄语、阿拉伯语 RTL。
// 阶段 6 由子代理 B 实现。

/// 应用支持的语言。当前阶段实现 zh-Hans 与 en，
/// 其他 locale 提前在 enum 中占位，避免阶段 7+ 时改动 UI 引用。
public enum AppLanguage: String, Hashable, Sendable, CaseIterable, Codable, Identifiable {
    case zhHans = "zh-Hans"
    case en = "en"

    // 架构预留：未来需要时只要新增 case + String Catalog 翻译即可
    // case ja = "ja"
    // case ko = "ko"
    // case fr = "fr"
    // case de = "de"
    // case es = "es"
    // case pt = "pt"
    // case ru = "ru"
    // case ar = "ar"

    public var id: String { rawValue }

    /// 人类可读名（用 Locale.current 跟随系统回退）
    public var displayName: String {
        let locale = Locale(identifier: rawValue)
        return locale.localizedString(forIdentifier: rawValue) ?? rawValue
    }

    /// 该语言在 Bundle.main / String Catalog 里的 .lproj 目录
    public var bundleCode: String { rawValue }

    /// 是否 RTL（阿拉伯语等）
    public var isRightToLeft: Bool {
        // 架构预留：当加入 ar / he 等时这里返回 true
        return false
    }
}

/// 语言切换管理器。
/// - 运行时切换：通过 `Bundle` 的 `localizedString` 路径切换；
///   SwiftUI 的 `LocalizedStringKey` 通过 `Environment(\.locale)` 触发重新求值。
/// - 设置持久化：写到 `UserDefaults` 的 `AppLanguage.current`。
/// - 缺失翻译回退顺序：当前语言 → en → zh-Hans。
@MainActor
public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()

    @Published public private(set) var current: AppLanguage {
        didSet { apply() }
    }

    /// SwiftUI 监听 `locale` 环境变量时会用这个值；
    /// `Locale` 是 Sendable，可安全暴露。
    public var swiftUILocale: Locale {
        Locale(identifier: current.bundleCode)
    }

    private let defaults: UserDefaults
    private let storageKey = "AppLanguage.current"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: storageKey),
           let lang = AppLanguage(rawValue: raw) {
            self.current = lang
        } else {
            // 跟随系统语言；fallback 顺序：当前系统 → en → zh-Hans
            let preferred = AppLanguage.match(preferredIdentifier: Locale.preferredLanguages.first)
            self.current = preferred
        }
        apply()
    }

    /// 显式切换语言。会立刻触发 SwiftUI 重新渲染。
    public func switchTo(_ language: AppLanguage) {
        // 总是写 defaults（即使 current 已经是目标语言），让持久化保持最新；
        // didSet 会避免重复触发 objectWillChange。
        let changed = current != language
        if changed { current = language }
        defaults.set(language.rawValue, forKey: storageKey)
        if !changed { objectWillChange.send() }
    }

    /// 切换到「跟随系统」。
    public func switchToSystem() {
        let preferred = AppLanguage.match(preferredIdentifier: Locale.preferredLanguages.first)
        switchTo(preferred)
    }

    /// 缺翻译回退：当前语言 → en → zh-Hans
    public func localized(_ key: String, fallback: String? = nil) -> String {
        if let v = current.localizedString(key: key), !v.isEmpty, v != key {
            return v
        }
        if let v = AppLanguage.en.localizedString(key: key), !v.isEmpty, v != key {
            return v
        }
        if let v = AppLanguage.zhHans.localizedString(key: key), !v.isEmpty, v != key {
            return v
        }
        return fallback ?? key
    }

    // MARK: - Internals

    private func apply() {
        // Apple 推荐的运行时切换语言方法：设置用户对象 + 通知
        // 注意：使用 self.defaults（测试可注入），不用 .standard。
        defaults.set([current.bundleCode], forKey: "AppleLanguages")
        // SwiftUI 通过 Locale 环境变量重新计算 LocalizedStringKey
        objectWillChange.send()
    }
}

// MARK: - Lookup helpers

public extension AppLanguage {
    /// 在指定语言下查找翻译。String Catalog 编译后是 .strings / .stringsdict 文件，
    /// 落在 main bundle 的 .lproj/ 目录里。
    func localizedString(key: String) -> String? {
        if let path = Bundle.main.path(forResource: bundleCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return nil
    }

    /// 把系统偏好（"en-US" / "zh-Hans-CN" / "zh-CN" 等）匹配到 AppLanguage。
    /// 优先精确匹配；否则按 base（"en" / "zh"）匹配；最后 fallback 到 .zhHans。
    static func match(preferredIdentifier: String?) -> AppLanguage {
        guard let raw = preferredIdentifier, !raw.isEmpty else { return .zhHans }
        // 1. 精确匹配 "zh-Hans" / "en"
        if let lang = AppLanguage(rawValue: raw) { return lang }
        // 2. 按 base 匹配 "zh" / "en" 等
        let base = raw.split(separator: "-").first.map(String.init) ?? raw
        if base == "en" { return .en }
        if base == "zh" { return .zhHans }
        // 3. 兜底
        return .zhHans
    }
}

// MARK: - SwiftUI bridge

/// 通过 `Locale` 环境变量传递语言。SwiftUI 在 locale 变化时自动重新求值
/// 所有 `LocalizedStringKey`。`@Environment(\.locale)` + `.environment(\.locale, ...)`
/// 即可完成语言切换。
public extension View {
    /// 绑定到 LanguageManager 的当前语言。SwiftUI 会在 current 变化时重新求值
    /// 所有 LocalizedStringKey。
    func bindLanguage(_ manager: LanguageManager) -> some View {
        self.environment(\.locale, manager.swiftUILocale)
    }
}
