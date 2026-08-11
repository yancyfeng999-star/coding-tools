import XCTest
import Foundation
@testable import Catalog
@testable import Domain

// MARK: - LocalCatalogLoader

final class LocalCatalogLoaderTests: XCTestCase {
    private var tmpDir: URL!
    private var toolsDir: URL!
    private var contentDir: URL!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalCatalogLoaderTests-\(UUID().uuidString)", isDirectory: true)
        toolsDir = tmpDir.appendingPathComponent("Catalog/tools", isDirectory: true)
        contentDir = tmpDir.appendingPathComponent("Catalog/content", isDirectory: true)
        try? FileManager.default.createDirectory(at: toolsDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        toolsDir = nil
        contentDir = nil
        tmpDir = nil
        super.tearDown()
    }

    /// 测试专用 init：直接指定 tools 目录
    private func makeLoader() -> LocalCatalogLoader {
        LocalCatalogLoader(toolsDirectory: toolsDir)
    }

    private func makeTool(id: String, name: String, category: String = "cli-utility") -> Data {
        // 简单合成一个工具的 JSON（只放必需字段）
        let tool: [String: Any] = [
            "id": id,
            "slug": id,
            "name": name,
            "localizedName": ["en": name, "zh-Hans": name],
            "description": "Test \(name)",
            "localizedDescription": ["en": "Test", "zh-Hans": "测试"],
            "category": category,
            "tags": ["test"],
            "homepageURL": "https://example.com/\(id)",
            "installOptions": [
                [
                    "type": "homebrew-formula",
                    "packageName": id,
                    "riskLevel": "low"
                ]
            ],
            "supportedArchitectures": ["arm64", "x86_64"],
            "minimumMacOS": "14.0",
            "status": "active",
            "riskLevel": "low"
        ]
        return try! JSONSerialization.data(withJSONObject: tool, options: [])
    }

    private func makeSnapshotFile(tool: Data, catalogVersion: String, atURL url: URL) throws {
        // tool 已经是 JSON 字节；包成完整 snapshot 后写出
        let toolObj = try JSONSerialization.jsonObject(with: tool) as? [String: Any] ?? [:]
        let snapshot: [String: Any] = [
            "schemaVersion": "1.0.0",
            "catalogVersion": catalogVersion,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            "keyID": "test",
            "signature": "",
            "tools": [toolObj],
            "revokedItems": NSArray()  // empty
        ]
        let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted])
        try data.write(to: url)
    }

    func testLoadsRealCatalogFromProductionPath() async throws {
        // 调试 helper：直接读真实 Catalog/tools 路径
        let realDir = URL(fileURLWithPath: "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Catalog/tools", isDirectory: true)
        let loader = LocalCatalogLoader(toolsDirectory: realDir)
        let snapshot = try await loader.loadCatalog()
        XCTAssertGreaterThan(snapshot.tools.count, 20, "should load all 24 tools, got \(snapshot.tools.count)")
    }

    func testEmptyBundleReturnsZeroTools() async throws {
        let snapshot = try await makeLoader().loadCatalog()
        XCTAssertEqual(snapshot.tools.count, 0)
    }

    func testLoadsSingleFile() async throws {
        let tool = makeTool(id: "git", name: "Git")
        let fileURL = toolsDir.appendingPathComponent("git.json")
        try makeSnapshotFile(tool: tool, catalogVersion: "v1-git", atURL: fileURL)
        let snapshot = try await makeLoader().loadCatalog()
        XCTAssertEqual(snapshot.tools.count, 1, "expected 1 tool, got \(snapshot.tools.count)")
        XCTAssertEqual(snapshot.tools.first?.id, "git")
    }

    func testMergesMultipleFiles() async throws {
        let git = makeTool(id: "git", name: "Git")
        let jq = makeTool(id: "jq", name: "jq")
        let rg = makeTool(id: "rg", name: "ripgrep")
        try makeSnapshotFile(tool: git, catalogVersion: "v1-git", atURL: toolsDir.appendingPathComponent("git.json"))
        try makeSnapshotFile(tool: jq, catalogVersion: "v1-jq", atURL: toolsDir.appendingPathComponent("jq.json"))
        try makeSnapshotFile(tool: rg, catalogVersion: "v1-rg", atURL: toolsDir.appendingPathComponent("rg.json"))
        let snapshot = try await makeLoader().loadCatalog()
        XCTAssertEqual(snapshot.tools.count, 3, "expected 3 tools, got \(snapshot.tools.count)")
        let ids = Set(snapshot.tools.map { $0.id })
        XCTAssertEqual(ids, ["git", "jq", "rg"])
    }

    func testSkipsMalformedFiles() async throws {
        let good = makeTool(id: "git", name: "Git")
        try makeSnapshotFile(tool: good, catalogVersion: "v1", atURL: toolsDir.appendingPathComponent("git.json"))
        try "{invalid json".data(using: .utf8)!.write(to: toolsDir.appendingPathComponent("bad.json"))
        let snapshot = try await makeLoader().loadCatalog()
        XCTAssertEqual(snapshot.tools.count, 1, "bad file should be skipped silently, got \(snapshot.tools.count)")
    }

    func testMergesRevokedItems() async throws {
        // 直接写两个 snapshot：snap1 含 tool + revoked，snap2 只含 revoked
        let good = makeTool(id: "git", name: "Git")
        let goodObj = try JSONSerialization.jsonObject(with: good) as? [String: Any] ?? [:]

        let snap1: [String: Any] = [
            "schemaVersion": "1.0.0",
            "catalogVersion": "v1",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            "keyID": "k", "signature": "",
            "tools": [goodObj],
            "revokedItems": ["old-tool-1"]
        ]
        let snap2: [String: Any] = [
            "schemaVersion": "1.0.0",
            "catalogVersion": "v1",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            "keyID": "k", "signature": "",
            "tools": [],
            "revokedItems": ["old-tool-1", "old-tool-2"]
        ]
        let d1 = try JSONSerialization.data(withJSONObject: snap1)
        let d2 = try JSONSerialization.data(withJSONObject: snap2)
        try d1.write(to: toolsDir.appendingPathComponent("a.json"))
        try d2.write(to: toolsDir.appendingPathComponent("b.json"))

        let snapshot = try await makeLoader().loadCatalog()
        XCTAssertEqual(snapshot.revokedItems.sorted(), ["old-tool-1", "old-tool-2"])
    }
}
