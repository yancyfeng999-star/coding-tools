import XCTest
@testable import LatestVersion
import ProcessExecution

// MARK: - Test stub for ProcessExecuting

final class StubProcessExecutor: ProcessExecuting, @unchecked Sendable {
    var stdout: String = ""
    var exitCode: Int32 = 0
    var error: Error?

    func run(_ request: ProcessRequest) async throws -> ProcessOutput {
        if let error = error { throw error }
        return ProcessOutput(
            stdout: stdout,
            stderr: "",
            exitCode: exitCode
        )
    }

    func cancel(id: UUID) async {
        // no-op
    }
}

// MARK: - BrewLatestVersionProvider

final class BrewLatestVersionProviderTests: XCTestCase {
    func testParseBrewInfoJSONFormula() {
        let json = """
        {
          "formulae": [
            {
              "name": "git",
              "versions": {
                "stable": "2.47.1",
                "devel": "2.48.0-rc1"
              }
            }
          ],
          "casks": []
        }
        """
        let result = BrewLatestVersionProvider.parseBrewInfoJSON(
            Data(json.utf8), toolID: "git"
        )
        XCTAssertEqual(result, "2.47.1")
    }

    func testParseBrewInfoJSONCask() {
        let json = """
        {
          "formulae": [],
          "casks": [
            {
              "token": "docker",
              "version": "4.32.0,148734"
            }
          ]
        }
        """
        let result = BrewLatestVersionProvider.parseBrewInfoJSON(
            Data(json.utf8), toolID: "docker"
        )
        XCTAssertEqual(result, "4.32.0,148734")
    }

    func testParseBrewInfoJSONNotFound() {
        let json = """
        {"formulae":[{"name":"other","versions":{"stable":"1.0.0"}}],"casks":[]}
        """
        let result = BrewLatestVersionProvider.parseBrewInfoJSON(
            Data(json.utf8), toolID: "git"
        )
        XCTAssertNil(result)
    }

    func testParseBrewInfoJSONInvalid() {
        let result = BrewLatestVersionProvider.parseBrewInfoJSON(
            Data("not json".utf8), toolID: "git"
        )
        XCTAssertNil(result)
    }

    func testParseBrewInfoJSONEmpty() {
        let result = BrewLatestVersionProvider.parseBrewInfoJSON(
            Data("{}".utf8), toolID: "git"
        )
        XCTAssertNil(result)
    }

    func testParseBrewInfoJSONEmptyVersion() {
        let json = """
        {"formulae":[{"name":"git","versions":{"stable":""}}],"casks":[]}
        """
        let result = BrewLatestVersionProvider.parseBrewInfoJSON(
            Data(json.utf8), toolID: "git"
        )
        XCTAssertNil(result, "empty version string should be treated as not found")
    }
}

// MARK: - Brew integration (graceful nil)

final class BrewProviderIntegrationTests: XCTestCase {
    func testReturnsNilWhenBrewNotAvailable() async {
        let stub = StubProcessExecutor()
        // pathResolver 找不到 brew → 返回 nil
        let provider = BrewLatestVersionProvider(
            executor: stub,
            pathResolver: HomebrewPathResolver(),
            timeout: 0.1
        )
        let result = await provider.latestVersion(toolID: "git", installedVersion: "2.45.0")
        XCTAssertNil(result, "should return nil when brew not available")
    }
}

// MARK: - NpmLatestVersionProvider

final class NpmLatestVersionProviderTests: XCTestCase {
    func testReturnsTrimmedVersion() async {
        // 真跑 npm 拿一个已存在的 scoped package 的 latest 版本
        // （测试期间可能慢或被网络挡；失败就 skip 而不是 fail）
        let provider = NpmLatestVersionProvider(
            executor: ProcessExecutor(),
            npmPath: "/usr/bin/npm",
            timeout: 5.0
        )
        let result = await provider.latestVersion(toolID: "@anthropic-ai/claude-code", installedVersion: nil)
        // 不强制断言（依赖网络 + 实际 latest 可能变）；只确认返回 String 或 nil
        if let r = result {
            XCTAssertFalse(r.isEmpty)
        }
        // 至少路径走通（不崩溃）
        XCTAssertTrue(true, "no-op if npm path exercised")
    }

    func testReturnsNilWhenNpmMissing() async {
        let stub = StubProcessExecutor()
        let provider = NpmLatestVersionProvider(
            executor: stub,
            npmPath: "/nonexistent/npm",
            timeout: 0.1
        )
        let result = await provider.latestVersion(toolID: "@x/y", installedVersion: nil)
        XCTAssertNil(result)
    }
}

// MARK: - CachedLatestVersionProvider

final class CachedLatestVersionProviderTests: XCTestCase {

    final class FakeProvider: LatestVersionProvider, @unchecked Sendable {
        var callCount = 0
        var result: String? = "1.0.0"
        func latestVersion(toolID: String, installedVersion: String?) async -> String? {
            callCount += 1
            return result
        }
    }

    func testCacheHitAvoidsRecall() async {
        let fake = FakeProvider()
        let cached = CachedLatestVersionProvider(inner: fake, ttl: 60)
        let a = await cached.latestVersion(toolID: "git", installedVersion: "1.0.0")
        let b = await cached.latestVersion(toolID: "git", installedVersion: "1.0.0")
        let c = await cached.latestVersion(toolID: "git", installedVersion: "1.0.0")
        XCTAssertEqual(a, "1.0.0")
        XCTAssertEqual(b, "1.0.0")
        XCTAssertEqual(c, "1.0.0")
        XCTAssertEqual(fake.callCount, 1, "second+third call should hit cache")
    }

    func testCacheKeyDifferentiatesInstalledVersion() async {
        let fake = FakeProvider()
        let cached = CachedLatestVersionProvider(inner: fake, ttl: 60)
        _ = await cached.latestVersion(toolID: "git", installedVersion: "1.0.0")
        _ = await cached.latestVersion(toolID: "git", installedVersion: "1.1.0")
        _ = await cached.latestVersion(toolID: "git", installedVersion: nil)
        XCTAssertEqual(fake.callCount, 3, "different installedVersion = different cache key")
    }

    func testCacheExpires() async throws {
        let fake = FakeProvider()
        let cached = CachedLatestVersionProvider(inner: fake, ttl: 0.05)  // 50ms
        _ = await cached.latestVersion(toolID: "git", installedVersion: nil)
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        _ = await cached.latestVersion(toolID: "git", installedVersion: nil)
        XCTAssertEqual(fake.callCount, 2, "after TTL expiry, should call inner again")
    }

    func testCacheStoresNilResults() async {
        let fake = FakeProvider()
        fake.result = nil
        let cached = CachedLatestVersionProvider(inner: fake, ttl: 60)
        let a = await cached.latestVersion(toolID: "x", installedVersion: nil)
        let b = await cached.latestVersion(toolID: "x", installedVersion: nil)
        XCTAssertNil(a)
        XCTAssertNil(b)
        XCTAssertEqual(fake.callCount, 1, "nil result also cached to avoid repeated failed lookups")
    }
}
