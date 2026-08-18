import Foundation

/// User-controlled portable snapshot. No paths, tokens, logs, or install output.
public struct UserDataExport: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var exportedAt: Date
    public var favorites: [String]
    public var recents: [String]
    public var theme: String
    public var language: String
    public var autoCheckUpdates: Bool
    public var autoDownloadUpdates: Bool

    public static let currentFormatVersion = 1
}

public enum UserDataPortableError: Error, Equatable, Sendable {
    case unsupportedFormat(Int)
    case forbiddenPayload
    case invalidJSON
}

public enum UserDataPortable {
    public static func make(
        favorites: [String],
        recents: [String],
        theme: String,
        language: String,
        autoCheckUpdates: Bool,
        autoDownloadUpdates: Bool,
        exportedAt: Date = Date()
    ) -> UserDataExport {
        UserDataExport(
            formatVersion: UserDataExport.currentFormatVersion,
            exportedAt: exportedAt,
            favorites: sanitizeToolIDs(favorites),
            recents: sanitizeToolIDs(recents),
            theme: theme,
            language: language,
            autoCheckUpdates: autoCheckUpdates,
            autoDownloadUpdates: autoDownloadUpdates
        )
    }

    public static func encode(_ export: UserDataExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    public static func decode(_ data: Data) throws -> UserDataExport {
        if containsForbiddenPayload(data) {
            throw UserDataPortableError.forbiddenPayload
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let export = try? decoder.decode(UserDataExport.self, from: data) else {
            throw UserDataPortableError.invalidJSON
        }
        guard export.formatVersion == UserDataExport.currentFormatVersion else {
            throw UserDataPortableError.unsupportedFormat(export.formatVersion)
        }
        return UserDataExport(
            formatVersion: export.formatVersion,
            exportedAt: export.exportedAt,
            favorites: sanitizeToolIDs(export.favorites),
            recents: sanitizeToolIDs(export.recents),
            theme: export.theme,
            language: export.language,
            autoCheckUpdates: export.autoCheckUpdates,
            autoDownloadUpdates: export.autoDownloadUpdates
        )
    }

    public static func sanitizeToolIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in ids {
            guard isSafeToolID(id) else { continue }
            if seen.insert(id).inserted {
                result.append(id)
            }
        }
        return result
    }

    public static func isSafeToolID(_ id: String) -> Bool {
        guard (1...64).contains(id.count) else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard id.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return id.first?.isLetter == true || id.first?.isNumber == true
    }

    public static func containsForbiddenPayload(_ data: Data) -> Bool {
        let text = String(decoding: data, as: UTF8.self)
        if text.range(of: #"/Users/[^*/\s]+"#, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"(?i)(sk-|ghp_|github_pat_|Bearer )"#, options: .regularExpression) != nil {
            return true
        }
        if text.contains("PATH=") || text.contains("\"PATH\"") || text.contains("signed-download") {
            return true
        }
        return false
    }
}
