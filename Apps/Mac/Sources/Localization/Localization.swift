import Foundation
import SwiftUI

// MARK: - Localization
//
// 中英文 + 运行时切换。阶段 6 由子代理 B 实现。
// 架构预留：日语、韩语、法语、德语、西班牙语、葡萄牙语、俄语、阿拉伯语 RTL。

public enum AppLanguage: String, Hashable, Sendable, CaseIterable, Codable {
    case zhHans = "zh-Hans"
    case en = "en"

    public var displayName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

@MainActor
final class LanguageManager: ObservableObject {
    @Published public var current: AppLanguage

    public init(current: AppLanguage = .zhHans) {
        self.current = current
    }

    public func switchTo(_ language: AppLanguage) {
        current = language
    }

    public func localized(_ key: String, fallback: String? = nil) -> String {
        // 阶段 6 由子代理 B 接入 String Catalog
        // 当前占位：直接返回 key
        return key
    }
}
