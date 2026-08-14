import Foundation
import Domain

// MARK: - Persistence
//
// SQLite 持久化：安装记录、收藏、最近使用、阅读进度、目录缓存。
// 阶段 2 由子代理 A 接入；阶段 5 接入 ContentItem 缓存。
//
// 计划使用 GRDB（成熟、稳定、支持加密）。

public protocol Store: Sendable {
    func saveInstallation(_ installation: InstallationProbe) async throws
    func loadInstallations() async throws -> [InstallationProbe]
    func saveFavorite(toolID: String) async throws
    func removeFavorite(toolID: String) async throws
    func loadFavorites() async throws -> [String]
    func saveRecent(toolID: String, maxItems: Int) async throws
    func loadRecents() async throws -> [String]
    func saveCatalog(_ snapshot: CatalogSnapshot) async throws
    func loadLatestCatalog() async throws -> CatalogSnapshot?
    func clearOperationHistory() async throws
}

public actor InMemoryStore: Store {
    private var installations: [String: InstallationProbe] = [:]
    private var favorites: Set<String> = []
    private var recents: [String] = []
    private var catalog: CatalogSnapshot?

    public init() {}

    public func saveInstallation(_ installation: InstallationProbe) async throws {
        installations[installation.toolID] = installation
    }

    public func loadInstallations() async throws -> [InstallationProbe] {
        Array(installations.values)
    }

    public func saveFavorite(toolID: String) async throws {
        favorites.insert(toolID)
    }

    public func removeFavorite(toolID: String) async throws {
        favorites.remove(toolID)
    }

    public func loadFavorites() async throws -> [String] {
        Array(favorites)
    }

    public func saveRecent(toolID: String, maxItems: Int) async throws {
        recents.removeAll { $0 == toolID }
        recents.insert(toolID, at: 0)
        if recents.count > maxItems {
            recents = Array(recents.prefix(maxItems))
        }
    }

    public func loadRecents() async throws -> [String] {
        recents
    }

    public func saveCatalog(_ snapshot: CatalogSnapshot) async throws {
        catalog = snapshot
    }

    public func loadLatestCatalog() async throws -> CatalogSnapshot? {
        catalog
    }

    public func clearOperationHistory() async throws {
        installations.removeAll()
    }
}
