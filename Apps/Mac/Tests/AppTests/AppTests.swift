import XCTest
import SwiftUI
import ObjectiveC
@testable import Localization
@testable import Theme
@testable import Content
@testable import UI
import Domain
import ProcessExecution
import Updates

@MainActor
final class AppModelTests: XCTestCase {
    /// AppModel 由 Coordinator 拥有（高冲突文件）。
    /// 不能直接访问 — 它在 CodingTools app target 里，而 app target 不支持
    /// `@testable import`。xctest CLI 模式也不会把 app 进程加载进来。
    /// 这里跳过 AppModel 测试；UI 状态由 AppState 覆盖（见 AppStateTests）。
}

final class ProcessExecutionRedactionTests: XCTestCase {
    func testBearerTokenRedacted() {
        let input = "Authorization: Bearer abc.def.ghi"
        let output = OutputRedactor.redact(input)
        XCTAssertFalse(output.contains("abc.def.ghi"))
        XCTAssertTrue(output.contains("***"))
    }

    func testUserPathRedacted() {
        let input = "/Users/johndoe/Documents/test"
        let output = OutputRedactor.redact(input)
        XCTAssertTrue(output.contains("/Users/***/"))
    }

    func testBasicAuthInUrlRedacted() {
        let input = "https://user:secretpass@github.com/repo"
        let output = OutputRedactor.redact(input)
        XCTAssertFalse(output.contains("secretpass"))
    }
}

// MARK: - LanguageManager

@MainActor
final class LanguageManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "LanguageManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultCurrentMatchesSystem() {
        defaults.removeObject(forKey: "AppLanguage.current")
        let manager = LanguageManager(defaults: defaults)
        // 无 stored value 时，current = 跟随系统 → 在 CI 环境里 "en" 匹配到 .en
        // 测试断言：要么是 .en（系统 en），要么是 .zhHans（兜底）
        XCTAssertTrue([AppLanguage.zhHans, AppLanguage.en].contains(manager.current))
    }

    func testSwitchToUpdatesCurrent() {
        let manager = LanguageManager(defaults: defaults)
        manager.switchTo(.zhHans)
        XCTAssertEqual(manager.current, .zhHans)
        XCTAssertEqual(defaults.string(forKey: "AppLanguage.current"), "zh-Hans")

        manager.switchTo(.en)
        XCTAssertEqual(manager.current, .en)
        XCTAssertEqual(defaults.string(forKey: "AppLanguage.current"), "en")
    }

    func testSwitchToSystemPrefersStoredValue() {
        defaults.set("en", forKey: "AppLanguage.current")
        let manager = LanguageManager(defaults: defaults)
        XCTAssertEqual(manager.current, .en)
    }

    func testMatchPreferredIdentifier() {
        XCTAssertEqual(AppLanguage.match(preferredIdentifier: "en"), .en)
        XCTAssertEqual(AppLanguage.match(preferredIdentifier: "en-US"), .en)
        XCTAssertEqual(AppLanguage.match(preferredIdentifier: "zh-Hans"), .zhHans)
        XCTAssertEqual(AppLanguage.match(preferredIdentifier: "zh-Hans-CN"), .zhHans)
        XCTAssertEqual(AppLanguage.match(preferredIdentifier: "zh"), .zhHans)
        XCTAssertEqual(AppLanguage.match(preferredIdentifier: "ja"), .zhHans)
        XCTAssertEqual(AppLanguage.match(preferredIdentifier: nil), .zhHans)
    }

    func testSwiftUILocaleMatchesCurrent() {
        let manager = LanguageManager(defaults: defaults)
        manager.switchTo(.en)
        XCTAssertEqual(manager.swiftUILocale.identifier, "en")
    }
}

// MARK: - ThemeManager

@MainActor
final class ThemeManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ThemeManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultIsSystem() {
        defaults.removeObject(forKey: "AppTheme.mode")
        let manager = ThemeManager(defaults: defaults)
        XCTAssertEqual(manager.mode, .system)
    }

    func testApplyPersistsMode() {
        let manager = ThemeManager(defaults: defaults)
        manager.apply(.dark)
        XCTAssertEqual(manager.mode, .dark)
        XCTAssertEqual(defaults.string(forKey: "AppTheme.mode"), "dark")
    }

    func testThemeModeAppearanceNames() {
        XCTAssertNil(ThemeMode.system.appearanceName)
        XCTAssertEqual(ThemeMode.light.appearanceName, .aqua)
        XCTAssertEqual(ThemeMode.dark.appearanceName, .darkAqua)
    }

    func testThemeModePreferredColorScheme() {
        XCTAssertNil(ThemeMode.system.preferredColorScheme)
        XCTAssertEqual(ThemeMode.light.preferredColorScheme, .light)
        XCTAssertEqual(ThemeMode.dark.preferredColorScheme, .dark)
    }
}

// MARK: - Content

final class ContentManifestTests: XCTestCase {
    func testDecodeValidManifest() throws {
        let json = """
        {
          "schemaVersion": "1.0.0",
          "contentVersion": "test-1",
          "createdAt": "2026-01-01T00:00:00Z",
          "expiresAt": "2027-01-01T00:00:00Z",
          "items": [
            {
              "id": "x",
              "type": "video",
              "title": "Test",
              "sourceURL": "https://example.com/x",
              "language": "en",
              "tags": []
            }
          ]
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ContentManifest.self, from: json)
        XCTAssertEqual(manifest.items.count, 1)
        XCTAssertEqual(manifest.items.first?.type, .video)
    }

    func testIsExpired() {
        let m = ContentManifest(
            contentVersion: "x",
            createdAt: Date(timeIntervalSince1970: 0),
            expiresAt: Date(timeIntervalSince1970: 1),
            items: []
        )
        XCTAssertTrue(m.isExpired)
    }
}

final class ContentLoadingHTTPSOnlyTests: XCTestCase {
    func testRejectsNonHTTPS() async {
        let loader = RemoteContentLoader(manifestURL: URL(string: "http://example.com/c.json")!)
        do {
            _ = try await loader.loadAll()
            XCTFail("expected failure")
        } catch ContentError.invalidURL {
            // OK
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }
}

final class ContentLoadingCacheTests: XCTestCase {
    func testLoadsFromCacheWhenRemoteFails() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContentLoadingCacheTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }

        // 准备一个有效 manifest 的 cache 文件
        let manifest = ContentManifest(
            contentVersion: "cached-1",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            items: [
                ContentItem(
                    id: "cached-item",
                    toolID: "git",
                    type: .docs,
                    title: "Cached Docs",
                    sourceURL: URL(string: "https://example.com/docs")!,
                    language: "en"
                )
            ]
        )
        let cacheDir = tmp.appendingPathComponent("content", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cacheFile = cacheDir.appendingPathComponent("\(manifest.contentVersion).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: cacheFile)

        // 用一个不存在的 HTTPS URL（会网络失败），期望回退到缓存
        let loader = RemoteContentLoader(
            manifestURL: URL(string: "https://nonexistent.invalid.local/c.json")!,
            cacheDirectory: cacheDir
        )
        let items = try await loader.loadAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, "cached-item")
    }
}

// MARK: - AppState

@MainActor
final class AppStateTests: XCTestCase {
    func testPlaceholderToolsHaveTenItems() {
        let state = AppState()
        // 子代理 A 把 v1.0.0 占位数据扩展为 7 AI CLI + 3 传统 CLI = 10 个。
        XCTAssertEqual(state.tools.count, 10)
        XCTAssertTrue(state.tools.contains(where: { $0.id == "git" }))
        XCTAssertTrue(state.tools.contains(where: { $0.id == "claude-code" }))
    }

    func testToggleFavoriteRoundTrip() async throws {
        let state = AppState()
        let id = "git"
        XCTAssertFalse(state.isFavorite(id))
        state.toggleFavorite(id)
        XCTAssertTrue(state.isFavorite(id))
        state.toggleFavorite(id)
        XCTAssertFalse(state.isFavorite(id))
    }

    func testMarkRecentLimitsToTen() {
        let state = AppState()
        for i in 0..<15 {
            state.markRecent("tool-\(i)")
        }
        XCTAssertEqual(state.recent.count, 10)
        XCTAssertEqual(state.recent.first, "tool-14")
    }

    func testRecentToolsResolvesToRealTools() {
        let state = AppState()
        state.markRecent("git")
        state.markRecent("missing-tool")
        let resolved = state.recentTools()
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.id, "git")
    }

    func testCheckForUpdatesIsNoOpWhileChecking() {
        final class CountingUpdater: AppUpdating {
            var count = 0
            var isAutomaticChecksEnabled: Bool = true
            var isAutomaticDownloadEnabled: Bool = false
            func checkForUpdates() { count += 1 }
            func setAutomaticChecksEnabled(_ enabled: Bool) {}
            func setAutomaticDownloadEnabled(_ enabled: Bool) {}
        }
        let updater = CountingUpdater()
        let state = AppState()
        state.appUpdatingProvider = { updater }
        state.updateState = .checking
        state.checkForUpdates()
        XCTAssertEqual(updater.count, 0)
        state.updateState = .idle
        state.checkForUpdates()
        XCTAssertEqual(updater.count, 1)
    }

    func testPerformAppUpdateActionInstallsWhenReplyIsPending() {
        let state = AppState()
        let model = UpdateFlowModel()
        state.bindUpdates(model)
        model.transition(.readyToInstall(remoteVersion: "1.5.5"))
        var decided: UpdateFlowModel.UpdateDecision?
        model.setPendingReply { decided = $0 }
        state.performAppUpdateAction()
        XCTAssertEqual(decided, .install)
    }

    func testPerformAppUpdateActionChecksWhenReadyWithoutReply() {
        final class CountingUpdater: AppUpdating {
            var count = 0
            var isAutomaticChecksEnabled: Bool = false
            var isAutomaticDownloadEnabled: Bool = false
            func checkForUpdates() { count += 1 }
            func setAutomaticChecksEnabled(_ enabled: Bool) {}
            func setAutomaticDownloadEnabled(_ enabled: Bool) {}
        }
        let updater = CountingUpdater()
        let state = AppState()
        state.appUpdatingProvider = { updater }
        state.updateState = .readyToInstall(remoteVersion: "1.5.5")
        state.performAppUpdateAction()
        XCTAssertEqual(updater.count, 1)
    }

    func testStartInstallRefusesToolWithoutTrustedOption() {
        let state = AppState()
        let tool = Tool(
            id: "none",
            slug: "none",
            name: "None",
            category: .cliUtility
        )
        state.startInstall(tool)
        XCTAssertEqual(state.installState, .idle)
        XCTAssertNil(state.installingTool)
    }
}
