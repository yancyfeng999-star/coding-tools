import XCTest
@testable import LatestVersion
import Domain

final class VersionSourceResolverTests: XCTestCase {
    func testAgentVersionSourcesAreExact() {
        XCTAssertEqual(VersionSourceResolver.sources(for: tool("claude-code")), [.npm("@anthropic-ai/claude-code")])
        XCTAssertEqual(VersionSourceResolver.sources(for: tool("codex")), [.npm("@openai/codex")])
        XCTAssertEqual(VersionSourceResolver.sources(for: tool("gemini-cli")), [.npm("@google/gemini-cli")])
        XCTAssertEqual(VersionSourceResolver.sources(for: tool("grok-build")), [.npm("@xai-official/grok")])
        XCTAssertEqual(VersionSourceResolver.sources(for: tool("opencode")), [.npm("opencode-ai"), .github(owner: "anomalyco", repo: "opencode")])
        XCTAssertEqual(VersionSourceResolver.sources(for: tool("openclaw")), [.npm("openclaw")])
        XCTAssertEqual(VersionSourceResolver.sources(for: tool("hermes")), [.pypi("hermes-agent")])
    }

    func testNpmPackageNormalization() {
        XCTAssertEqual(VersionSourceResolver.normalizeNpmPackage("opencode-ai@latest"), "opencode-ai")
        XCTAssertEqual(VersionSourceResolver.normalizeNpmPackage("@openai/codex"), "@openai/codex")
        XCTAssertEqual(VersionSourceResolver.normalizeNpmPackage("@scope/name@beta"), "@scope/name")
    }

    private func tool(_ id: String) -> Tool {
        Tool(id: id, slug: id, name: id, category: .aiCoding)
    }
}

final class RegistryLatestVersionProviderTests: XCTestCase {
    func testParsesInjectedRegistryJSON() async {
        let client = FixtureHTTPClient(payloads: [
            "https://registry.npmjs.org/@anthropic-ai/claude-code/latest": #"{"version":"2.1.234"}"#,
            "https://pypi.org/pypi/hermes-agent/json": #"{"info":{"version":"0.19.0"}}"#,
            "https://api.github.com/repos/anomalyco/opencode/releases/latest": #"{"tag_name":"v1.18.18"}"#,
        ])
        let registry = RegistryLatestVersionProvider(client: client)
        let npm = await registry.fetch(source: .npm("@anthropic-ai/claude-code"))
        let pypi = await registry.fetch(source: .pypi("hermes-agent"))
        let github = await registry.fetch(source: .github(owner: "anomalyco", repo: "opencode"))
        XCTAssertEqual(try npm.get().version, "2.1.234")
        XCTAssertEqual(try pypi.get().version, "0.19.0")
        XCTAssertEqual(try github.get().version, "1.18.18")
    }

    func testAllowlistTimeoutAndSizeBecomeTerminalFailures() async {
        let client = FixtureHTTPClient(errors: [
            "https://registry.npmjs.org/openclaw/latest": .timedOut,
            "https://pypi.org/pypi/hermes-agent/json": .responseTooLarge,
            "https://api.github.com/repos/anomalyco/opencode/releases/latest": .httpStatus(500),
            "https://registry.npmjs.org/bad/latest": .hostNotAllowlisted,
        ])
        let registry = RegistryLatestVersionProvider(client: client)
        let timedOut = await registry.fetch(source: .npm("openclaw"))
        let tooLarge = await registry.fetch(source: .pypi("hermes-agent"))
        let http = await registry.fetch(source: .github(owner: "anomalyco", repo: "opencode"))
        let blocked = await registry.fetch(source: .npm("bad"))
        XCTAssertEqual(timedOut, .failure(.timedOut))
        XCTAssertEqual(tooLarge, .failure(.responseTooLarge))
        XCTAssertEqual(http, .failure(.httpStatus(500)))
        XCTAssertEqual(blocked, .failure(.unsupportedSource))
    }

    func testMalformedJSONIsInvalidResponse() async {
        let client = FixtureHTTPClient(payloads: [
            "https://registry.npmjs.org/openclaw/latest": #"{"not":"a version"}"#,
        ])
        let registry = RegistryLatestVersionProvider(client: client)
        let result = await registry.fetch(source: .npm("openclaw"))
        XCTAssertEqual(result, .failure(.invalidResponse))
    }

    func testRoutedProviderFallsBackToGitHub() async {
        let client = FixtureHTTPClient(
            payloads: [
                "https://api.github.com/repos/anomalyco/opencode/releases/latest": #"{"tag_name":"v1.18.18"}"#,
            ],
            errors: [
                "https://registry.npmjs.org/opencode-ai/latest": .httpStatus(404),
            ]
        )
        let provider = RoutedLatestVersionProvider(registry: RegistryLatestVersionProvider(client: client))
        let result = await provider.latestVersion(for: Tool(id: "opencode", slug: "opencode", name: "OpenCode", category: .aiCoding))
        XCTAssertEqual(try result.get().version, "1.18.18")
        XCTAssertEqual(try result.get().source, .github(owner: "anomalyco", repo: "opencode"))
    }
}

final class CachedLatestVersionProviderTests: XCTestCase {
    actor CountingProvider: LatestVersionProvider {
        var calls = 0
        func latestVersion(for tool: Tool) async -> Result<LatestVersionRecord, LatestVersionFailure> {
            calls += 1
            return .success(LatestVersionRecord(version: "1.0.0", source: .npm("fixture"), fetchedAt: Date(timeIntervalSince1970: 0)))
        }
    }

    func testSuccessIsCachedAndFailureIsNot() async {
        let inner = CountingProvider()
        let cached = CachedLatestVersionProvider(inner: inner, ttl: 600)
        let tool = Tool(id: "claude-code", slug: "claude-code", name: "Claude", category: .aiCoding)
        _ = await cached.latestVersion(for: tool)
        _ = await cached.latestVersion(for: tool)
        let calls = await inner.calls
        XCTAssertEqual(calls, 1)
    }

    func testInvalidateForcesRefresh() async {
        let inner = CountingProvider()
        let cached = CachedLatestVersionProvider(inner: inner, ttl: 600)
        let tool = Tool(id: "claude-code", slug: "claude-code", name: "Claude", category: .aiCoding)
        _ = await cached.latestVersion(for: tool)
        await cached.invalidate(toolIDs: ["claude-code"])
        _ = await cached.latestVersion(for: tool)
        let calls = await inner.calls
        XCTAssertEqual(calls, 2)
    }
}

final class BrewLatestVersionProviderTests: XCTestCase {
    func testParseBrewInfoJSONFormula() {
        let json = """
        {"formulae":[{"name":"git","versions":{"stable":"2.47.1"}}],"casks":[]}
        """
        XCTAssertEqual(
            BrewLatestVersionProvider.parseBrewInfoJSON(Data(json.utf8), toolID: "git"),
            "2.47.1"
        )
    }
}

private final class FixtureHTTPClient: VersionHTTPClient, @unchecked Sendable {
    var payloads: [String: String]
    var errors: [String: VersionHTTPClientError]

    init(payloads: [String: String] = [:], errors: [String: VersionHTTPClientError] = [:]) {
        self.payloads = payloads
        self.errors = errors
    }

    func data(from url: URL, timeout: TimeInterval, maximumBytes: Int) async throws -> Data {
        let key = url.absoluteString
        if let error = errors[key] { throw error }
        if let body = payloads[key] { return Data(body.utf8) }
        throw VersionHTTPClientError.networkUnavailable
    }
}
