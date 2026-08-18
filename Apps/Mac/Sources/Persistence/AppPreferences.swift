import Foundation

/// Versioned local preferences (onboarding + crash acknowledgement).
/// Theme and language stay in their existing UserDefaults keys.
public struct AppPreferencesDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var hasCompletedOnboarding: Bool
    public var lastAcknowledgedCrashAt: Date?

    public static let currentSchemaVersion = 2

    public static var `default`: AppPreferencesDocument {
        AppPreferencesDocument(
            schemaVersion: currentSchemaVersion,
            hasCompletedOnboarding: false,
            lastAcknowledgedCrashAt: nil
        )
    }

    public init(
        schemaVersion: Int = currentSchemaVersion,
        hasCompletedOnboarding: Bool = false,
        lastAcknowledgedCrashAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.lastAcknowledgedCrashAt = lastAcknowledgedCrashAt
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case hasCompletedOnboarding
        case lastAcknowledgedCrashAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        lastAcknowledgedCrashAt = try container.decodeIfPresent(Date.self, forKey: .lastAcknowledgedCrashAt)
    }
}

public enum AppPreferencesLoadResult: Equatable, Sendable {
    case loaded(AppPreferencesDocument)
    case migrated(from: Int, document: AppPreferencesDocument)
    case recoveredFromCorruption(backupName: String)
    case createdDefault(AppPreferencesDocument)
}

public actor AppPreferencesStore {
    public static let fileName = "preferences.json"

    private let fileURL: URL
    private var document: AppPreferencesDocument = .default
    private var loadOnce = false

    public init(directory: URL = AppPreferencesStore.defaultDirectory()) {
        self.fileURL = directory.appendingPathComponent(Self.fileName)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public static func defaultDirectory() -> URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("CodingTools", isDirectory: true)
    }

    public func recoverIfNeeded() async -> AppPreferencesLoadResult {
        loadOnce = true
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            document = .default
            try? persistLocked()
            return .createdDefault(document)
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            return backupAndReset()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(AppPreferencesDocument.self, from: data) else {
            return backupAndReset()
        }
        if decoded.schemaVersion < AppPreferencesDocument.currentSchemaVersion {
            let from = decoded.schemaVersion
            var migrated = decoded
            migrated.schemaVersion = AppPreferencesDocument.currentSchemaVersion
            document = migrated
            try? persistLocked()
            return .migrated(from: from, document: migrated)
        }
        document = decoded
        return .loaded(decoded)
    }

    public func load() async -> AppPreferencesDocument {
        if !loadOnce {
            _ = await recoverIfNeeded()
        }
        return document
    }

    public func save(_ document: AppPreferencesDocument) async throws {
        self.document = document
        try persistLocked()
    }

    private func backupAndReset() -> AppPreferencesLoadResult {
        let backupName = "\(Self.fileName).corrupt-\(Int(Date().timeIntervalSince1970))"
        let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent(backupName)
        try? FileManager.default.moveItem(at: fileURL, to: backupURL)
        document = .default
        try? persistLocked()
        return .recoveredFromCorruption(backupName: backupName)
    }

    private func persistLocked() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        let tmp = fileURL.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.moveItem(at: tmp, to: fileURL)
    }
}
