import XCTest
@testable import UI
import Domain
import Detection
import LatestVersion
import ProcessExecution

@MainActor
final class AgentEnvironmentStateTests: XCTestCase {
    func testFastToolPublishesBeforeSlowTool() async {
        let state = AppState()
        state.detector = DelayedDetector(delays: ["claude-code": .milliseconds(20), "codex": .milliseconds(400)])
        let task = Task { await state.refreshProbes(toolIDs: ["claude-code", "codex"]) }
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertNotNil(state.probe(for: "claude-code"))
        XCTAssertTrue(state.probingToolIDs.contains("codex"))
        await task.value
    }

    func testOneLatestFailureDoesNotClearOtherResults() async {
        let state = AppState()
        state.latestVersionProvider = StubLatestProvider(results: [
            "claude-code": .success(.fixture("2.1.234")),
            "codex": .failure(.timedOut),
        ])
        await state.refreshLatestVersions(toolIDs: ["claude-code", "codex"], force: true)
        XCTAssertEqual(state.latestVersionRecord(for: "claude-code")?.version, "2.1.234")
        XCTAssertEqual(state.latestVersionFailure(for: "codex"), .timedOut)
    }

    func testStaleGenerationDoesNotOverwriteNewerProbe() async {
        let state = AppState()
        let detector = GenerationAwareDetector()
        state.detector = detector
        async let first: Void = state.refreshProbes(toolIDs: ["claude-code"])
        try? await Task.sleep(for: .milliseconds(30))
        detector.nextVersion = "2.0.0"
        await state.refreshProbes(toolIDs: ["claude-code"])
        await first
        XCTAssertEqual(state.probe(for: "claude-code")?.installedVersion, "2.0.0")
    }
}

private actor DelayedDetector: InstallationDetecting {
    let delays: [String: Duration]

    init(delays: [String: Duration]) {
        self.delays = delays
    }

    func probe(tool: Tool) async -> InstallationProbe {
        if let delay = delays[tool.id] {
            try? await Task.sleep(for: delay)
        }
        return InstallationProbe(
            toolID: tool.id,
            installedVersion: "1.0.0",
            detectedPath: "/tmp/\(tool.id)",
            architecture: .arm64,
            healthStatus: .installed
        )
    }

    func probeAll(tools: [Tool]) async -> [InstallationProbe] {
        var result: [InstallationProbe] = []
        for tool in tools { result.append(await probe(tool: tool)) }
        return result
    }

    func systemArchitecture() async -> Architecture { .arm64 }
}

private final class GenerationAwareDetector: InstallationDetecting, @unchecked Sendable {
    var nextVersion = "1.0.0"

    func probe(tool: Tool) async -> InstallationProbe {
        let version = nextVersion
        try? await Task.sleep(for: .milliseconds(80))
        return InstallationProbe(
            toolID: tool.id,
            installedVersion: version,
            detectedPath: "/tmp/\(tool.id)",
            architecture: .arm64,
            healthStatus: .installed
        )
    }

    func probeAll(tools: [Tool]) async -> [InstallationProbe] {
        var result: [InstallationProbe] = []
        for tool in tools { result.append(await probe(tool: tool)) }
        return result
    }

    func systemArchitecture() async -> Architecture { .arm64 }
}

private struct StubLatestProvider: LatestVersionProvider {
    let results: [String: Result<LatestVersionRecord, LatestVersionFailure>]

    func latestVersion(for tool: Tool) async -> Result<LatestVersionRecord, LatestVersionFailure> {
        results[tool.id] ?? .failure(.unsupportedSource)
    }
}

private extension LatestVersionRecord {
    static func fixture(_ version: String) -> LatestVersionRecord {
        LatestVersionRecord(version: version, source: .npm("fixture"), fetchedAt: Date(timeIntervalSince1970: 0))
    }
}
