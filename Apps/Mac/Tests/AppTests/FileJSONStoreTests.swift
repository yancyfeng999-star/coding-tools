import XCTest
import Foundation
import Domain
@testable import Persistence

// MARK: - P0-G3-1 修复：FileJSONStore 持久化测试

final class FileJSONStoreTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("file-json-store-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testSaveAndLoadFavorites() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileJSONStore(directory: dir)

        try await store.saveFavorite(toolID: "git")
        try await store.saveFavorite(toolID: "fzf")
        try await store.saveFavorite(toolID: "lazygit")
        let list = try await store.loadFavorites()
        XCTAssertEqual(Set(list), Set(["git", "fzf", "lazygit"]))

        try await store.removeFavorite(toolID: "fzf")
        let list2 = try await store.loadFavorites()
        XCTAssertEqual(Set(list2), Set(["git", "lazygit"]))
    }

    func testRecentsOrderAndDedup() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileJSONStore(directory: dir)

        try await store.saveRecent(toolID: "git", maxItems: 10)
        try await store.saveRecent(toolID: "fzf", maxItems: 10)
        try await store.saveRecent(toolID: "lazygit", maxItems: 10)
        try await store.saveRecent(toolID: "git", maxItems: 10)  // 移到最前
        let recents = try await store.loadRecents()
        XCTAssertEqual(recents.first, "git")
        XCTAssertEqual(recents.count, 3)
    }

    func testRecentsTruncateAtMax() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileJSONStore(directory: dir)

        for i in 0..<15 {
            try await store.saveRecent(toolID: "t\(i)", maxItems: 10)
        }
        let recents = try await store.loadRecents()
        XCTAssertEqual(recents.count, 10)
        // 最后写进去的在最前
        XCTAssertEqual(recents.first, "t14")
    }

    func testAtomicWriteLeavesNoTmpFile() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileJSONStore(directory: dir)

        try await store.saveFavorite(toolID: "git")
        // store.json 存在
        let json = dir.appendingPathComponent("store.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: json.path))
        // 不应有 .tmp 残留
        let tmp = json.appendingPathExtension("tmp")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
    }

    func testPersistenceAcrossInstances() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store1 = FileJSONStore(directory: dir)
        try await store1.saveFavorite(toolID: "git")

        let store2 = FileJSONStore(directory: dir)
        let list = try await store2.loadFavorites()
        XCTAssertEqual(list, ["git"])
    }

    func testClearOperationHistoryDoesNotAffectFavorites() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileJSONStore(directory: dir)

        let probe = InstallationProbe(
            toolID: "git",
            installedVersion: "2.40.0",
            detectedPath: nil,
            architecture: nil,
            healthStatus: .installed,
            lastCheckedAt: Date()
        )
        try await store.saveInstallation(probe)
        try await store.saveFavorite(toolID: "git")

        try await store.clearOperationHistory()
        let favs = try await store.loadFavorites()
        XCTAssertEqual(favs, ["git"])
        let installs = try await store.loadInstallations()
        XCTAssertEqual(installs.count, 0)
    }

    func testReplaceFavoritesAndRecents() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileJSONStore(directory: dir)
        try await store.saveFavorite(toolID: "old")
        try await store.replaceFavorites(["git", "nodejs"])
        try await store.replaceRecents(["git", "python", "rust"])
        let favorites = try await store.loadFavorites()
        let recents = try await store.loadRecents()
        XCTAssertEqual(Set(favorites), Set(["git", "nodejs"]))
        XCTAssertEqual(recents, ["git", "python", "rust"])
    }

    func testResetCatalogCacheKeepsFavorites() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileJSONStore(directory: dir)
        try await store.saveFavorite(toolID: "git")
        let snapshot = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "cache-test",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "k",
            signature: "s",
            tools: []
        )
        try await store.saveCatalog(snapshot)
        try await store.resetCatalogCache()
        let favorites = try await store.loadFavorites()
        XCTAssertEqual(favorites, ["git"])
    }

    func testCorruptStoreIsBackedUp() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let json = dir.appendingPathComponent("store.json")
        try Data("not-json".utf8).write(to: json)
        let store = FileJSONStore(directory: dir)
        let favorites = try await store.loadFavorites()
        let recovered = await store.recoveredFromCorruption()
        XCTAssertTrue(favorites.isEmpty)
        XCTAssertTrue(recovered)
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(backups.contains { $0.hasPrefix("store.json.corrupt-") })
    }
}

// MARK: - P0-G3-2/3/4 修复：OutputRedactor 新增规则 + path 重写

import ProcessExecution

final class OutputRedactorExtendedTests: XCTestCase {

    func testNpmTokensRedacted() {
        let text = "//registry.npmjs.org/:_authToken=npm_abcdef0123456789abcdef0123456789abcdef"
        let out = OutputRedactor.redact(text)
        XCTAssertFalse(out.contains("npm_abcdef"))
        XCTAssertTrue(out.contains("***"))
    }

    func testAwsAccessKeyRedacted() {
        let text = "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"
        let out = OutputRedactor.redact(text)
        XCTAssertFalse(out.contains("AKIAIOSFODNN7EXAMPLE"))
    }

    func testAnthropicApiKeyRedacted() {
        let text = "Authorization: sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789"
        let out = OutputRedactor.redact(text)
        XCTAssertFalse(out.contains("sk-ant-api03-"))
    }

    func testOpenAiApiKeyRedacted() {
        let text = "OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz0123456789"
        let out = OutputRedactor.redact(text)
        XCTAssertFalse(out.contains("sk-abcdefghij"))
    }

    func testPostgresConnectionStringRedacted() {
        let text = "postgres://user:secret@host:5432/db"
        let out = OutputRedactor.redact(text)
        XCTAssertFalse(out.contains("user:secret"))
        XCTAssertTrue(out.contains("***POSTGRES_URL***"))
    }

    func testRedactPathHidesHome() {
        let home = NSHomeDirectory()
        let path = "\(home)/.claude/settings.json"
        let out = OutputRedactor.redactPath(path, keepLastSegments: 2)
        XCTAssertFalse(out.contains(home))
        XCTAssertTrue(out.contains("/Users/***/"))
        XCTAssertTrue(out.hasSuffix(".claude/settings.json"))
    }

    func testRedactPathNonHomeUnchanged() {
        let path = "/opt/homebrew/bin/brew"
        let out = OutputRedactor.redactPath(path, keepLastSegments: 2)
        XCTAssertEqual(out, path)
    }
}