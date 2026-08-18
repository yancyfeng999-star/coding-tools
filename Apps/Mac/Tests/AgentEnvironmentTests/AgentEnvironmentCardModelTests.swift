import XCTest
@testable import UI
import Domain
import LatestVersion

final class AgentEnvironmentCardModelTests: XCTestCase {
    func testEveryAgentCardStateHasCompleteAccessibilitySummary() {
        let fixtures = AgentEnvironmentPreviewState.allCases.map(\.model)
        for model in fixtures {
            XCTAssertFalse(model.toolName.isEmpty)
            XCTAssertFalse(model.localSummary.isEmpty)
            XCTAssertFalse(model.latestSummary.isEmpty)
            XCTAssertFalse(model.primaryLabelKey.isEmpty)
            XCTAssertTrue(model.accessibilitySummary.contains(model.toolName))
            XCTAssertTrue(model.accessibilitySummary.contains(model.localSummary))
            XCTAssertTrue(model.accessibilitySummary.contains(model.latestSummary))
        }
    }

    func testLocalAheadNeverOffersDowngrade() {
        let presentation = ToolPresentationMapper.map(
            options: [Self.trusted],
            probe: .result(Self.installed(id: "hermes", version: "0.20.0")),
            latest: .known("0.19.0"),
            operation: .idle
        )
        XCTAssertEqual(presentation.status, .localAhead(localVersion: "0.20.0", latestVersion: "0.19.0"))
        XCTAssertEqual(presentation.primaryAction, .open)
        XCTAssertFalse(presentation.showsUpdateAction)
    }

    func testEqualDateStyleVersionIsCurrent() {
        XCTAssertEqual(ToolPresentationMapper.compareVersions("2026.7.1-2", "2026.7.1-2"), .orderedSame)
    }

    func testNetworkFailedKeepsLocalOpenAction() {
        let probe = Self.installed(id: "grok-build", version: "1.0.5")
        let presentation = ToolPresentationMapper.map(
            options: [Self.trusted],
            probe: .result(probe),
            latest: .unavailable,
            operation: .idle
        )
        let model = AgentEnvironmentCardModel.make(
            tool: Self.tool(id: "grok-build", name: "Grok Build"),
            presentation: presentation,
            probeState: .loaded(probe),
            latestState: .failed(
                LoadFailure(localizationKey: "tool.latest.networkUnavailable", redactedMessage: "timedOut"),
                previous: Self.record("1.0.4")
            ),
            report: nil
        )
        XCTAssertEqual(presentation.primaryAction, .open)
        XCTAssertFalse(presentation.showsUpdateAction)
        XCTAssertEqual(presentation.latestDisplay, .unavailable)
        XCTAssertEqual(model.healthStatus, .installed)
        XCTAssertEqual(model.localSummary, "1.0.5")
        XCTAssertEqual(model.latestSummary, "tool.latest.networkUnavailable")
        XCTAssertEqual(model.primaryAction, .open)
        XCTAssertEqual(model.primaryLabelKey, "tool.action.open")
    }

    func testLoadingKeepsStaleLocalAndLatestVersions() {
        let probe = Self.installed(id: "claude-code", version: "2.1.221")
        let staleLatest = Self.record("2.1.221")
        let presentation = ToolPresentationMapper.map(
            options: [Self.trusted],
            probe: .result(probe),
            latest: .known("2.1.221"),
            operation: .idle
        )
        let model = AgentEnvironmentCardModel.make(
            tool: Self.tool(id: "claude-code", name: "Claude Code"),
            presentation: presentation,
            probeState: .loading(previous: probe),
            latestState: .loading(previous: staleLatest),
            report: nil
        )
        XCTAssertEqual(model.localSummary, "2.1.221")
        XCTAssertEqual(model.latestSummary, "2.1.221")
        XCTAssertNotEqual(model.localSummary, "tool.probe.checking")
        XCTAssertNotEqual(model.latestSummary, "tool.probe.checking")
        XCTAssertEqual(model.healthStatus, .installed)
        XCTAssertEqual(model.primaryAction, .open)
    }

    static let trusted = InstallOption(
        type: .npmGlobal,
        packageName: "@anthropic-ai/claude-code",
        riskLevel: .low
    )

    static func tool(id: String, name: String) -> Tool {
        Tool(
            id: id,
            slug: id,
            name: name,
            category: .aiCoding,
            installOptions: [trusted]
        )
    }

    static func installed(id: String, version: String) -> InstallationProbe {
        InstallationProbe(
            toolID: id,
            installedVersion: version,
            detectedPath: "/opt/bin/\(id)",
            architecture: .arm64,
            healthStatus: .installed
        )
    }

    static func record(_ version: String) -> LatestVersionRecord {
        LatestVersionRecord(
            version: version,
            source: .npm("fixture"),
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

enum AgentEnvironmentPreviewState: CaseIterable {
    case installedCurrent
    case updateAvailable
    case notInstalled
    case installedButBroken
    case localAhead
    case latestNetworkFailed
    case multipleInstallations

    var model: AgentEnvironmentCardModel {
        switch self {
        case .installedCurrent:
            return mapped(
                id: "claude-code",
                name: "Claude Code",
                probe: AgentEnvironmentCardModelTests.installed(id: "claude-code", version: "2.1.221"),
                latest: .known("2.1.221")
            )
        case .updateAvailable:
            return mapped(
                id: "codex",
                name: "Codex",
                probe: AgentEnvironmentCardModelTests.installed(id: "codex", version: "0.1.0"),
                latest: .known("0.2.0")
            )
        case .notInstalled:
            return mapped(
                id: "openclaw",
                name: "OpenClaw",
                probe: InstallationProbe(
                    toolID: "openclaw",
                    installedVersion: nil,
                    detectedPath: nil,
                    architecture: nil,
                    healthStatus: .notInstalled
                ),
                latest: .known("1.0.0")
            )
        case .installedButBroken:
            return mapped(
                id: "gemini-cli",
                name: "Gemini CLI",
                probe: InstallationProbe(
                    toolID: "gemini-cli",
                    installedVersion: "0.8.0",
                    detectedPath: "/opt/bin/gemini",
                    architecture: .arm64,
                    healthStatus: .broken,
                    failure: ProbeFailure(kind: .nonZeroExit, redactedMessage: "version command exited 1")
                ),
                latest: .known("0.9.0")
            )
        case .localAhead:
            return mapped(
                id: "hermes",
                name: "Hermes",
                probe: AgentEnvironmentCardModelTests.installed(id: "hermes", version: "0.20.0"),
                latest: .known("0.19.0")
            )
        case .latestNetworkFailed:
            return mapped(
                id: "grok-build",
                name: "Grok Build",
                probe: AgentEnvironmentCardModelTests.installed(id: "grok-build", version: "1.0.5"),
                latest: .unavailable,
                latestState: .failed(
                    LoadFailure(localizationKey: "tool.latest.networkUnavailable", redactedMessage: "timedOut"),
                    previous: AgentEnvironmentCardModelTests.record("1.0.4")
                )
            )
        case .multipleInstallations:
            let probe = AgentEnvironmentCardModelTests.installed(id: "codex", version: "0.146.0")
            return mapped(
                id: "codex",
                name: "Codex",
                probe: probe,
                latest: .known("0.146.0"),
                report: ToolInstallationReport(toolID: "codex", installations: [
                    DetectedToolInstallation(
                        path: "/opt/bin/codex",
                        canonicalPath: "/opt/bin/codex",
                        version: "0.146.0",
                        source: .path,
                        isPreferred: true,
                        failure: nil
                    ),
                    DetectedToolInstallation(
                        path: "/Apps/ChatGPT.app/Contents/Resources/codex",
                        canonicalPath: "/Apps/ChatGPT.app/Contents/Resources/codex",
                        version: "0.146.0",
                        source: .appBundle,
                        isPreferred: false,
                        failure: nil
                    ),
                ])
            )
        }
    }

    private func mapped(
        id: String,
        name: String,
        probe: InstallationProbe,
        latest: LatestVersionFact,
        latestState: Loadable<LatestVersionRecord>? = nil,
        report: ToolInstallationReport? = nil
    ) -> AgentEnvironmentCardModel {
        let presentation = ToolPresentationMapper.map(
            options: [AgentEnvironmentCardModelTests.trusted],
            probe: .result(probe),
            latest: latest,
            operation: .idle
        )
        let resolvedLatestState: Loadable<LatestVersionRecord>
        if let latestState {
            resolvedLatestState = latestState
        } else if case .known(let version) = latest {
            resolvedLatestState = .loaded(AgentEnvironmentCardModelTests.record(version))
        } else {
            resolvedLatestState = .idle
        }
        return AgentEnvironmentCardModel.make(
            tool: AgentEnvironmentCardModelTests.tool(id: id, name: name),
            presentation: presentation,
            probeState: .loaded(probe),
            latestState: resolvedLatestState,
            report: report
        )
    }
}
