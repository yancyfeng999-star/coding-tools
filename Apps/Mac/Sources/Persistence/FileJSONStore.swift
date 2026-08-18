import Foundation
import Domain
import Catalog

// MARK: - FileJSONStore
//
// 阶段 9 + 11 修复（P0-G3-1）：用 Foundation 纯 JSON 把
// favorites / recent / catalog 缓存 / 安装记录写到
// ~/Library/Application Support/CodingTools/store.json。
//
// 不引第三方（GRDB / SQLite.swift）以避免改动 Tuist 依赖图。
// 单文件 + atomic write；并发安全（actor 隔离）。
//
// 数据模型：所有内容塞一个 JSON object：
//   {
//     "version": 1,
//     "favorites": [...],
//     "recents":  [...],
//     "catalogCache": { "catalogVersion": "...", "savedAt": ..., "sourceURL": "...", "bytes": ... } | null,
//     "installations": { "<toolID>": InstallationProbe }
//   }
// 安装记录（probe）只存状态字段，不存命令行 / 输出。

public actor FileJSONStore: Store {
    private static let storeFileName = "store.json"
    fileprivate static let storeVersion = 1

    private let fileURL: URL
    private var state: StoreState = StoreState()
    private var loadOnce = false
    private var recovered = false

    public init(directory: URL = FileJSONStore.defaultDirectory()) {
        self.fileURL = directory.appendingPathComponent(Self.storeFileName)
    }

    // MARK: - Default location

    public static func defaultDirectory() -> URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = support
            .appendingPathComponent("CodingTools", isDirectory: true)
            .appendingPathComponent("store", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Store protocol

    public func saveInstallation(_ installation: InstallationProbe) async throws {
        try await ensureLoaded()
        state.installations[installation.toolID] = installation
        try await persistLocked()
    }

    public func loadInstallations() async throws -> [InstallationProbe] {
        try await ensureLoaded()
        return Array(state.installations.values)
    }

    public func saveFavorite(toolID: String) async throws {
        try await ensureLoaded()
        state.favorites.insert(toolID)
        try await persistLocked()
    }

    public func removeFavorite(toolID: String) async throws {
        try await ensureLoaded()
        state.favorites.remove(toolID)
        try await persistLocked()
    }

    public func loadFavorites() async throws -> [String] {
        try await ensureLoaded()
        return Array(state.favorites)
    }

    public func saveRecent(toolID: String, maxItems: Int = 10) async throws {
        try await ensureLoaded()
        // 移除已存在的同名（保持最近一次在最前）
        state.recents.removeAll { $0 == toolID }
        state.recents.insert(toolID, at: 0)
        if state.recents.count > maxItems {
            state.recents = Array(state.recents.prefix(maxItems))
        }
        try await persistLocked()
    }

    public func loadRecents() async throws -> [String] {
        try await ensureLoaded()
        return state.recents
    }

    public func saveCatalog(_ snapshot: CatalogSnapshot) async throws {
        try await ensureLoaded()
        state.catalogCache = CachedCatalogMetadata(
            catalogVersion: snapshot.catalogVersion,
            savedAt: Date(),
            sourceURL: URL(fileURLWithPath: "/Catalog/local"),
            bytes: 0
        )
        try await persistLocked()
    }

    public func loadLatestCatalog() async throws -> CatalogSnapshot? {
        try await ensureLoaded()
        return nil  // 我们不把整个 snapshot 持久化（太大）；重启时由 LocalCatalogLoader 重读 Bundle
    }

    public func clearOperationHistory() async throws {
        try await ensureLoaded()
        state.installations.removeAll()
        try await persistLocked()
    }

    public func replaceFavorites(_ ids: [String]) async throws {
        try await ensureLoaded()
        state.favorites = Set(ids)
        try await persistLocked()
    }

    public func replaceRecents(_ ids: [String]) async throws {
        try await ensureLoaded()
        state.recents = Array(ids.prefix(10))
        try await persistLocked()
    }

    public func resetCatalogCache() async throws {
        try await ensureLoaded()
        state.catalogCache = nil
        try await persistLocked()
    }

    public func recoveredFromCorruption() -> Bool {
        recovered
    }

    // MARK: - Internals

    private func ensureLoaded() async throws {
        guard !loadOnce else { return }
        loadOnce = true
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data: Data
        do { data = try Data(contentsOf: fileURL) }
        catch { return }
        let iso = JSONDecoder()
        iso.dateDecodingStrategy = .iso8601
        if let raw = try? iso.decode(StoreState.self, from: data) {
            state = raw
            return
        }
        if let raw = try? JSONDecoder().decode(StoreState.self, from: data) {
            state = raw
            return
        }
        recovered = true
        let backupName = "store.json.corrupt-\(Int(Date().timeIntervalSince1970))"
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent(backupName)
        try? FileManager.default.moveItem(at: fileURL, to: backup)
        state = StoreState()
    }

    private func persistLocked() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        // 原子写：先写 .tmp 再 rename，避免半截文件
        let tmp = fileURL.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.moveItem(at: tmp, to: fileURL)
    }
}

// MARK: - Store state（持久化形态）

fileprivate struct StoreState: Codable {
    var version: Int = 1
    var favorites: Set<String> = []
    var recents: [String] = []
    var catalogCache: CachedCatalogMetadata?
    var installations: [String: InstallationProbe] = [:]

    init() {}
}