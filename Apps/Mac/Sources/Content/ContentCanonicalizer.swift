import Foundation
import Domain
import ManifestSecurity

// MARK: - ContentCanonicalizer
//
// Content manifest 签名用的 canonical JSON 序列化。
// 规则与 ManifestCanonicalizer 一致：
//   - 顶层 keys 按字典序排序
//   - 无空白（无换行、无缩进）
//   - 数组保持原顺序
//   - 字符串 / 数字 / 布尔 / null 按 JSON 规范
//   - ISO8601 字符串（无小数秒）
//
// 字段：
//   - schemaVersion / contentVersion / createdAt / expiresAt / items
//   - 排除 keyID + signature（被签的对象不能自签）
//
// 与 Catalog 的 ManifestCanonicalizer 共用一套 write / encodeString 实现
// 以避免编码漂移。

public enum ContentCanonicalizer {

    public static func canonicalize(_ manifest: ContentManifest) throws -> Data {
        let fmt = ISO8601Format()
        let intermediate: [String: Any] = [
            "schemaVersion": manifest.schemaVersion,
            "contentVersion": manifest.contentVersion,
            "createdAt": fmt.format(manifest.createdAt),
            "expiresAt": fmt.format(manifest.expiresAt),
            "items": manifest.items.map { Self.encode($0) },
        ]
        return try ManifestCanonicalizer.encodeSortedJSON(intermediate)
    }

    private static func encode(_ item: ContentItem) -> [String: Any] {
        let fmt = ISO8601Format()
        var dict: [String: Any] = [
            "id": item.id,
            "toolID": item.toolID as Any,
            "type": item.type.rawValue,
            "title": item.title,
            "sourceURL": item.sourceURL.absoluteString,
            "language": item.language,
            "tags": item.tags,
        ]
        if let a = item.author { dict["author"] = a }
        if let u = item.thumbnailURL { dict["thumbnailURL"] = u.absoluteString }
        if let d = item.publishedAt { dict["publishedAt"] = fmt.format(d) }
        if let l = item.license { dict["license"] = l }
        return dict
    }
}

/// 统一 ISO8601 格式（无小数秒）。Foundation `ISO8601DateFormatter` 行为。
struct ISO8601Format {
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    func format(_ date: Date) -> String { formatter.string(from: date) }
}