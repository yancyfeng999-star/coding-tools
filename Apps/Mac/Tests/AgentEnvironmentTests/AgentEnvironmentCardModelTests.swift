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
            options: [InstallOption(type: .homebrewFormula, packageName: "git", riskLevel: .low)],
            probe: .result(
                InstallationProbe(
                    toolID: "hermes",
                    installedVersion: "0.20.0",
                    detectedPath: "/opt/bin/hermes",
                    architecture: .arm64,
                    healthStatus: .installed
                )
            ),
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
            return make(name: "Claude Code", local: "2.1.221", latest: "2.1.221", action: .open, key: "tool.action.open")
        case .updateAvailable:
            return make(name: "Codex", local: "0.1.0", latest: "0.2.0", action: .update(targetVersion: "0.2.0"), key: "tool.action.update")
        case .notInstalled:
            return make(name: "OpenClaw", local: "tool.status.notInstalled", latest: "1.0.0", action: .install, key: "tool.action.install")
        case .installedButBroken:
            return make(name: "Gemini CLI", local: "tool.probe.installedButBroken", latest: "0.9.0", action: .repair, key: "tool.action.repair")
        case .localAhead:
            return make(name: "Hermes", local: "0.20.0", latest: "0.19.0", action: .open, key: "tool.action.open")
        case .latestNetworkFailed:
            return make(name: "Grok Build", local: "1.0.5", latest: "tool.latest.networkUnavailable", action: .open, key: "tool.action.open")
        case .multipleInstallations:
            return make(name: "Codex", local: "0.146.0", latest: "0.146.0", action: .open, key: "tool.action.open", conflicts: 2)
        }
    }

    private func make(
        name: String,
        local: String,
        latest: String,
        action: ToolPrimaryAction,
        key: String,
        conflicts: Int = 0
    ) -> AgentEnvironmentCardModel {
        AgentEnvironmentCardModel(
            toolName: name,
            healthStatus: .installed,
            localSummary: local,
            latestSummary: latest,
            sourceLabel: "tool.installSource.path",
            conflictCount: conflicts,
            primaryAction: action,
            primaryLabelKey: key,
            primaryEnabled: true,
            accessibilitySummary: "\(name). \(local). \(latest)"
        )
    }
}
