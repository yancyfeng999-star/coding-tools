import XCTest
import Foundation
@testable import AIConfigDiscovery

final class FilesystemAIConfigDiscoveryTests: XCTestCase {

    private var tmpHome: URL!

    override func setUp() {
        super.setUp()
        tmpHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIConfigDiscoveryTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpHome, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpHome)
        tmpHome = nil
        super.tearDown()
    }

    // MARK: - Happy path

    func testDiscoversExistingClaudeConfig() async throws {
        let claudeDir = tmpHome.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        let settingsURL = claudeDir.appendingPathComponent("settings.json")
        let json = """
        {
          "model": "claude-3-5-sonnet",
          "apiKey": "sk-ant-12345"
        }
        """
        try Data(json.utf8).write(to: settingsURL)

        let discovery = FilesystemAIConfigDiscovery(homeDirectory: tmpHome)
        let results = await discovery.discover()

        XCTAssertEqual(results.count, 1)
        let cfg = results[0]
        XCTAssertEqual(cfg.toolID, "claude-code")
        XCTAssertEqual(cfg.configPath, settingsURL)
        XCTAssertEqual(cfg.model, "claude-3-5-sonnet")
        XCTAssertTrue(cfg.hasAPIKey, "apiKey field exists")
        XCTAssertEqual(cfg.detectedFormat, .json)
        XCTAssertGreaterThan(cfg.sizeBytes, 0)
    }

    func testDiscoversMultipleConfigs() async throws {
        for (dir, file, body) in [
            (".claude", "settings.json", #"{"model": "claude-3-5", "apiKey": "x"}"#),
            (".codex", "config.toml", #"model = "gpt-4o""# + "\napi_key = \"sk-abc\""),
            (".gemini", "settings.json", #"{"model": "gemini-1.5-pro"}"#),
        ] {
            let d = tmpHome.appendingPathComponent(dir, isDirectory: true)
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            try Data(body.utf8).write(to: d.appendingPathComponent(file))
        }

        let discovery = FilesystemAIConfigDiscovery(homeDirectory: tmpHome)
        let results = await discovery.discover()

        XCTAssertEqual(results.count, 3)
        let ids = Set(results.map { $0.toolID })
        XCTAssertEqual(ids, ["claude-code", "codex", "gemini-cli"])
    }

    // MARK: - Error / edge cases

    func testNoConfigsReturnsEmpty() async {
        let discovery = FilesystemAIConfigDiscovery(homeDirectory: tmpHome)
        let results = await discovery.discover()
        XCTAssertTrue(results.isEmpty)
    }

    func testCorruptedJSONSkippedGracefully() async throws {
        let claudeDir = tmpHome.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        let settingsURL = claudeDir.appendingPathComponent("settings.json")
        try Data("{not json".utf8).write(to: settingsURL)

        let discovery = FilesystemAIConfigDiscovery(homeDirectory: tmpHome)
        let results = await discovery.discover()
        // corrupted → 跳过整个 config（model nil，fields 空，hasAPIKey false）
        XCTAssertEqual(results.count, 1, "file exists → still surfaces, just empty metadata")
        XCTAssertNil(results[0].model)
        XCTAssertFalse(results[0].hasAPIKey)
    }

    func testEmptyJSONFile() async throws {
        let claudeDir = tmpHome.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        let settingsURL = claudeDir.appendingPathComponent("settings.json")
        try Data("{}".utf8).write(to: settingsURL)

        let discovery = FilesystemAIConfigDiscovery(homeDirectory: tmpHome)
        let results = await discovery.discover()
        XCTAssertEqual(results.count, 1)
        XCTAssertNil(results[0].model)
        XCTAssertFalse(results[0].hasAPIKey)
    }

    // MARK: - TOML parsing

    func testCodexTOMLConfigParsed() async throws {
        let codexDir = tmpHome.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
        let toml = """
        model = "gpt-4o"
        api_key = "sk-abc"

        [provider]
        name = "openai"
        """
        try Data(toml.utf8).write(to: codexDir.appendingPathComponent("config.toml"))

        let discovery = FilesystemAIConfigDiscovery(homeDirectory: tmpHome)
        let results = await discovery.discover()

        XCTAssertEqual(results.count, 1)
        let cfg = results[0]
        XCTAssertEqual(cfg.toolID, "codex")
        XCTAssertEqual(cfg.model, "gpt-4o")
        XCTAssertTrue(cfg.hasAPIKey, "api_key field detected in [provider] section")
        XCTAssertEqual(cfg.detectedFormat, .toml)
    }

    // MARK: - Security

    func testSecretValueNotLeakedInMetadata() async throws {
        // 即使有 apiKey 字段，AIConfig 不应回显值
        let claudeDir = tmpHome.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        let secret = "sk-1234567890ABCDEFGHIJKLMNOP"
        let json = "{\"apiKey\": \"\(secret)\"}"
        try Data(json.utf8).write(to: claudeDir.appendingPathComponent("settings.json"))

        let discovery = FilesystemAIConfigDiscovery(homeDirectory: tmpHome)
        let results = await discovery.discover()
        XCTAssertEqual(results.count, 1)
        // 反序列化后的 AIConfig 不该有 secret
        let dump = String(describing: results[0])
        XCTAssertFalse(dump.contains(secret), "secret value must not appear in AIConfig representation")
    }

    // MARK: - mtime / size

    func testSizeAndMtimePopulated() async throws {
        let claudeDir = tmpHome.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        let url = claudeDir.appendingPathComponent("settings.json")
        try Data("{\"model\": \"claude-3\"}".utf8).write(to: url)

        let discovery = FilesystemAIConfigDiscovery(homeDirectory: tmpHome)
        let results = await discovery.discover()
        // `{"model": "claude-3"}` = 21 字节
        XCTAssertEqual(results.first?.sizeBytes, 21)
        XCTAssertLessThanOrEqual(
            Date().timeIntervalSince(results.first?.mtime ?? Date()),
            5.0
        )
    }
}
