import Foundation
import Domain

// MARK: - ManifestCanonicalizer
//
// 目录签名的 canonical JSON 序列化：
//   - 去除 `keyID` 和 `signature` 字段（这两个字段本身是被签的对象，不能
//     参与签名）
//   - 顶层 keys 按字典序升序排序
//   - 无空白（无换行、无缩进）
//   - 数组保持原顺序
//   - 字符串/数字/布尔/null 按 JSON 规范
//   - 二进制（如 teamID、sha256）始终是 hex 字符串，保持原样
//
// 用途：阶段 2 测试 + 阶段 7 子代理 C 签发真实目录。
//
// 注意：Foundation 的 JSONSerialization 无法保证 key 顺序，所以这里手工
// 构造。我们不需要重新实现整个 RFC 8259 —— 只需要足以覆盖 CatalogSnapshot
// 当前 schema 的子集。

public enum ManifestCanonicalizer {

    /// 入口：把 snapshot 序列化为 canonical 字节流。
    public static func canonicalize(_ snapshot: CatalogSnapshot) throws -> Data {
        // 1. 用 JSONEncoder 拿到标准 JSON（顺序不确定 → 我们手工重新排序）
        let intermediate: [String: Any] = [
            "schemaVersion": snapshot.schemaVersion,
            "catalogVersion": snapshot.catalogVersion,
            "createdAt": snapshot.createdAt.formatted(Self.iso8601Style),
            "expiresAt": snapshot.expiresAt.formatted(Self.iso8601Style),
            "tools": snapshot.tools.map { Self.encode($0) },
            "revokedItems": snapshot.revokedItems,
        ]
        let data = try Self.encodeSortedJSON(intermediate)
        return data
    }

    /// 工具方法：直接序列化任意 JSON-Value（测试用）。
    public static func encodeSortedJSON(_ value: Any) throws -> Data {
        var output = ""
        try Self.write(value, into: &output)
        return Data(output.utf8)
    }

    // MARK: - Internals

    static let iso8601Style = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

    private static func encode(_ tool: Tool) -> [String: Any] {
        var dict: [String: Any] = [
            "id": tool.id,
            "slug": tool.slug,
            "name": tool.name,
            "localizedName": tool.localizedName.values,
            "description": tool.description,
            "localizedDescription": tool.localizedDescription.values,
            "category": tool.category.rawValue,
            "homepageURL": tool.homepageURL.absoluteString,
            "installOptions": tool.installOptions.map { Self.encode($0) },
            "supportedArchitectures": tool.supportedArchitectures.map { $0.rawValue },
            "minimumMacOS": tool.minimumMacOS,
            "status": tool.status.rawValue,
            "riskLevel": tool.riskLevel.rawValue,
        ]
        if !tool.tags.isEmpty { dict["tags"] = tool.tags }
        if let u = tool.documentationURL { dict["documentationURL"] = u.absoluteString }
        if let lc = tool.launchCapability { dict["launchCapability"] = Self.encode(lc) }
        return dict
    }

    private static func encode(_ option: InstallOption) -> [String: Any] {
        var dict: [String: Any] = [
            "type": option.type.rawValue,
            "riskLevel": option.riskLevel.rawValue,
        ]
        if let v = option.packageName { dict["packageName"] = v }
        if let v = option.versionRule { dict["versionRule"] = v }
        if let v = option.toolName { dict["toolName"] = v }
        if let v = option.version { dict["version"] = v }
        if let v = option.url { dict["url"] = v.absoluteString }
        if let v = option.sha256 { dict["sha256"] = v }
        if let v = option.bundleID { dict["bundleID"] = v }
        if let v = option.teamID { dict["teamID"] = v }
        if !option.supportedArchitectures.isEmpty {
            dict["supportedArchitectures"] = option.supportedArchitectures.map { $0.rawValue }
        }
        if let v = option.minimumMacOS { dict["minimumMacOS"] = v }
        if option.requiresAuthorization { dict["requiresAuthorization"] = true }
        return dict
    }

    private static func encode(_ cap: LaunchCapability) -> [String: Any] {
        var dict: [String: Any] = ["type": cap.type.rawValue]
        if let v = cap.command { dict["command"] = v }
        if !cap.arguments.isEmpty { dict["arguments"] = cap.arguments }
        if cap.openInTerminal { dict["openInTerminal"] = true }
        if let v = cap.bundleID { dict["bundleID"] = v }
        if let v = cap.url { dict["url"] = v.absoluteString }
        return dict
    }

    private static func write(_ value: Any, into out: inout String) throws {
        if let dict = value as? [String: Any] {
            try writeObject(dict, into: &out)
        } else if let arr = value as? [Any] {
            try writeArray(arr, into: &out)
        } else if let s = value as? String {
            out += encodeString(s)
        } else if let b = value as? Bool {
            out += b ? "true" : "false"
        } else if value is NSNull {
            out += "null"
        } else if let n = value as? Int {
            out += String(n)
        } else if let n = value as? Int64 {
            out += String(n)
        } else if let n = value as? UInt64 {
            out += String(n)
        } else if let n = value as? Double {
            // JSON 不接受 NaN/Inf；如果遇到，直接 throw。
            if n.isNaN || n.isInfinite {
                throw ManifestSecurityError.canonicalizationFailed
            }
            out += String(n)
        } else {
            throw ManifestSecurityError.canonicalizationFailed
        }
    }

    private static func writeObject(_ dict: [String: Any], into out: inout String) throws {
        out += "{"
        let keys = dict.keys.sorted()
        for (i, k) in keys.enumerated() {
            if i > 0 { out += "," }
            out += encodeString(k)
            out += ":"
            try write(dict[k] as Any, into: &out)
        }
        out += "}"
    }

    private static func writeArray(_ arr: [Any], into out: inout String) throws {
        out += "["
        for (i, item) in arr.enumerated() {
            if i > 0 { out += "," }
            try write(item, into: &out)
        }
        out += "]"
    }

    /// 极简 JSON 字符串转义（覆盖控制字符、quote、backslash）。
    private static func encodeString(_ s: String) -> String {
        var out = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if u.value < 0x20 {
                    out += String(format: "\\u%04x", u.value)
                } else {
                    out += String(u)
                }
            }
        }
        out += "\""
        return out
    }
}
