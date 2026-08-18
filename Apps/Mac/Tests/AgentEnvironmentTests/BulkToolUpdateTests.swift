import XCTest
@testable import UI
import Domain

final class BulkToolUpdatePlannerTests: XCTestCase {
    func testBulkPlanIncludesOnlyTrustedUpdateActions() {
        let claude = Tool(
            id: "claude-code",
            slug: "claude-code",
            name: "Claude Code",
            category: .aiCoding,
            installOptions: [
                InstallOption(type: .npmGlobal, packageName: "@anthropic-ai/claude-code", riskLevel: .low),
            ]
        )
        let hermes = Tool(id: "hermes", slug: "hermes", name: "Hermes", category: .aiCoding)
        let items = BulkToolUpdatePlanner.makeItems(
            tools: [claude, hermes],
            presentations: [
                "claude-code": updatePresentation("2.1.234"),
                "hermes": localAheadPresentation("0.20.0", "0.19.0"),
            ]
        )
        XCTAssertEqual(items.map(\.tool.id), ["claude-code"])
    }
}

@MainActor
final class BulkToolUpdateRunnerTests: XCTestCase {
    func testBulkRunnerExecutesSequentiallyAndContinuesAfterFailure() async {
        let runner = RecordingToolOperationRunner(results: [.failed, .completed])
        let state = AppState()
        state.toolOperationRunner = { tool, option in await runner.run(tool: tool, option: option) }
        await state.runBulkAgentUpdate(items: [
            makeBulkItem("claude-code", package: "@anthropic-ai/claude-code"),
            makeBulkItem("codex", package: "@openai/codex"),
        ])
        let maxConcurrent = await runner.maximumConcurrentOperations
        let finished = await runner.finishedIDs
        XCTAssertEqual(maxConcurrent, 1)
        XCTAssertEqual(state.bulkUpdateState.completedCount, 1)
        XCTAssertEqual(state.bulkUpdateState.failedCount, 1)
        XCTAssertEqual(finished, ["claude-code", "codex"])
    }
}

private actor RecordingToolOperationRunner {
    var remaining: [InstallRunState]
    var activeOperations = 0
    var maximumConcurrentOperations = 0
    var finishedIDs: [String] = []

    init(results: [InstallRunState]) {
        remaining = results
    }

    func run(tool: Tool, option: InstallOption) async -> InstallRunState {
        activeOperations += 1
        maximumConcurrentOperations = max(maximumConcurrentOperations, activeOperations)
        defer { activeOperations -= 1 }
        try? await Task.sleep(for: .milliseconds(20))
        let result = remaining.isEmpty ? InstallRunState.failed : remaining.removeFirst()
        finishedIDs.append(tool.id)
        return result
    }
}

private func makeBulkItem(_ id: String, package: String) -> BulkToolUpdateItem {
    BulkToolUpdateItem(
        tool: Tool(
            id: id,
            slug: id,
            name: id,
            category: .aiCoding,
            installOptions: [InstallOption(type: .npmGlobal, packageName: package, riskLevel: .low)]
        ),
        option: InstallOption(type: .npmGlobal, packageName: package, riskLevel: .low),
        localVersion: "1.0.0",
        targetVersion: "2.0.0"
    )
}

private func updatePresentation(_ target: String) -> ToolPresentation {
    ToolPresentationMapper.map(
        options: [InstallOption(type: .npmGlobal, packageName: "@anthropic-ai/claude-code", riskLevel: .low)],
        probe: .result(
            InstallationProbe(
                toolID: "claude-code",
                installedVersion: "1.0.0",
                detectedPath: "/opt/bin/claude",
                architecture: .arm64,
                healthStatus: .installed
            )
        ),
        latest: .known(target),
        operation: .idle
    )
}

private func localAheadPresentation(_ local: String, _ remote: String) -> ToolPresentation {
    ToolPresentationMapper.map(
        options: [],
        probe: .result(
            InstallationProbe(
                toolID: "hermes",
                installedVersion: local,
                detectedPath: "/opt/bin/hermes",
                architecture: .arm64,
                healthStatus: .installed
            )
        ),
        latest: .known(remote),
        operation: .idle
    )
}
