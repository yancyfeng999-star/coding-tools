import Foundation

// MARK: - LocalizedString
//
// 简单的 key→value 翻译表。优先匹配传入的 locale；fallback 到 "en"，最后
// fallback 到第一个非空 value。设计目标：与 JSON `localizedName` /
// `localizedDescription` 一一对应；不依赖 Foundation 的 `.strings` 文件。
//
// v1.0.0 仅支持 en / zh-Hans；其它 locale 通过 fallback 链处理。

public struct LocalizedString: Hashable, Sendable, Codable {
    public let values: [String: String]

    public init(values: [String: String]) {
        self.values = values
    }

    public init(_ single: String) {
        self.values = ["": single]
    }

    public func localized(for locale: String = Locale.current.identifier) -> String {
        if let v = values[locale], !v.isEmpty { return v }
        if let v = values["en"], !v.isEmpty { return v }
        if let v = values["zh-Hans"], !v.isEmpty { return v }
        return values.values.first(where: { !$0.isEmpty }) ?? ""
    }

    /// Convenience: 取 zh-Hans 优先；回退到第一个非空。
    public func chineseOrFirst() -> String {
        if let v = values["zh-Hans"], !v.isEmpty { return v }
        if let v = values["en"], !v.isEmpty { return v }
        return values.values.first(where: { !$0.isEmpty }) ?? ""
    }
}
