import XCTest
import Domain
@testable import UI

final class ToolPresentationMapperTests: XCTestCase {
    private let brew = InstallOption(type: .homebrewFormula, packageName: "git", riskLevel: .low)
    private let scriptOnly = InstallOption(
        type: .npmGlobal,
        url: URL(string: "https://example.com/install.sh"),
        riskLevel: .low
    )

    func testNotInstalledMapsToInstall() {
        let probe = InstallationProbe(
            toolID: "git",
            installedVersion: nil,
            detectedPath: nil,
            architecture: nil,
            healthStatus: .notInstalled
        )
        let result = ToolPresentationMapper.map(
            options: [brew],
            probe: .result(probe),
            latest: .known("2.46.0"),
            operation: .idle
        )
        XCTAssertEqual(result.status, .notInstalled(latestVersion: "2.46.0"))
        XCTAssertEqual(result.primaryAction, .install)
        XCTAssertEqual(result.statusKey, "tool.status.notInstalled")
        XCTAssertTrue(result.primaryEnabled)
        XCTAssertFalse(result.showsUpdateAction)
    }

    func testInstalledAndLatestKnownNotHigherHasNoUpdate() {
        let probe = installedProbe(version: "2.46.0")
        let result = ToolPresentationMapper.map(
            options: [brew],
            probe: .result(probe),
            latest: .known("2.46.0"),
            operation: .idle
        )
        XCTAssertEqual(result.status, .installedCurrent(localVersion: "2.46.0", latestVersion: "2.46.0"))
        XCTAssertEqual(result.primaryAction, .open)
        XCTAssertFalse(result.showsUpdateAction)
        XCTAssertTrue(result.isConfirmedCurrent)
        XCTAssertEqual(result.statusKey, "tool.status.installed")
    }

    func testLocalAheadNeverOffersDowngrade() {
        let presentation = ToolPresentationMapper.map(
            options: [brew],
            probe: .result(installedProbe(version: "0.20.0")),
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

    func testLocalBelowLatestMapsToUpdateWithBothVersions() {
        let probe = installedProbe(version: "1.2.0")
        let result = ToolPresentationMapper.map(
            options: [brew],
            probe: .result(probe),
            latest: .known("1.3.0"),
            operation: .idle
        )
        XCTAssertEqual(result.status, .updateAvailable(localVersion: "1.2.0", latestVersion: "1.3.0"))
        XCTAssertEqual(result.primaryAction, .update(targetVersion: "1.3.0"))
        XCTAssertTrue(result.showsUpdateAction)
        if case .updateAvailable(let local, let remote) = result.status {
            XCTAssertEqual(local, "1.2.0")
            XCTAssertEqual(remote, "1.3.0")
        } else {
            XCTFail("expected updateAvailable")
        }
    }

    func testBrokenMapsToRepair() {
        let probe = InstallationProbe(
            toolID: "git",
            installedVersion: "2.0.0",
            detectedPath: "/opt/homebrew/bin/git",
            architecture: .arm64,
            healthStatus: .broken
        )
        let result = ToolPresentationMapper.map(
            options: [brew],
            probe: .result(probe),
            latest: .known("2.46.0"),
            operation: .idle
        )
        XCTAssertEqual(result.status, .broken(localVersion: "2.0.0", reason: nil))
        XCTAssertEqual(result.primaryAction, .repair)
        XCTAssertEqual(result.statusKey, "tool.status.broken")
    }

    func testFailedProbeMapsToRecheckNeverNotInstalled() {
        let result = ToolPresentationMapper.map(
            options: [brew],
            probe: .failed,
            latest: .notQueried,
            operation: .idle
        )
        XCTAssertEqual(result.primaryAction, .refresh)
        XCTAssertEqual(result.statusKey, "tool.status.probeFailed")
        XCTAssertNotEqual(result.statusKey, "tool.status.notInstalled")
        if case .notInstalled = result.status {
            XCTFail("failed probe must not become notInstalled")
        }
        if case .versionUnknown = result.status {
            // expected
        } else {
            XCTFail("failed probe should be versionUnknown")
        }
    }

    func testMissingProbeMapsToUnconfirmedNeverNotInstalled() {
        let result = ToolPresentationMapper.map(
            options: [brew],
            probe: .missing,
            latest: .notQueried,
            operation: .idle
        )
        XCTAssertEqual(result.statusKey, "tool.status.unconfirmed")
        XCTAssertEqual(result.primaryAction, .refresh)
        if case .notInstalled = result.status {
            XCTFail("unknown probe must not become notInstalled")
        }
    }

    func testNoTrustedOptionIsUnavailable() {
        let probe = InstallationProbe(
            toolID: "hermes",
            installedVersion: nil,
            detectedPath: nil,
            architecture: nil,
            healthStatus: .notInstalled
        )
        let result = ToolPresentationMapper.map(
            options: [scriptOnly],
            probe: .result(probe),
            latest: .unavailable,
            operation: .idle
        )
        XCTAssertEqual(result.primaryAction, .unavailable)
        XCTAssertFalse(result.primaryEnabled)
        if case .sourceUnavailable = result.status {
            // expected
        } else {
            XCTFail("missing trusted option must be sourceUnavailable, got \(result.status)")
        }
    }

    func testMissingLatestIsNotConfirmedCurrent() {
        let probe = installedProbe(version: "1.0.0")
        let result = ToolPresentationMapper.map(
            options: [brew],
            probe: .result(probe),
            latest: .notQueried,
            operation: .idle
        )
        XCTAssertFalse(result.isConfirmedCurrent)
        XCTAssertFalse(result.showsUpdateAction)
        XCTAssertEqual(result.latestDisplay, .notQueried)
        XCTAssertNotEqual(result.statusKey, "tool.status.installed")
    }

    func testUnsupportedLatestSourceShowsUnavailable() {
        let probe = installedProbe(version: "1.0.0")
        let result = ToolPresentationMapper.map(
            options: [brew],
            probe: .result(probe),
            latest: .unavailable,
            operation: .idle
        )
        XCTAssertEqual(result.latestDisplay, .unavailable)
        XCTAssertFalse(result.isConfirmedCurrent)
        XCTAssertNotEqual(result.statusKey, "tool.status.installed")
    }

    func testInstallConfirmationRefusesMissingAndScriptOnlyOptions() {
        let empty = Tool(
            id: "none",
            slug: "none",
            name: "None",
            category: .cliUtility
        )
        XCTAssertNil(InstallConfirmation.resolvedOption(tool: empty))

        let scriptTool = Tool(
            id: "hermes",
            slug: "hermes",
            name: "Hermes",
            category: .aiCoding,
            installOptions: [scriptOnly]
        )
        XCTAssertNil(InstallConfirmation.resolvedOption(tool: scriptTool))
        XCTAssertFalse(TrustedInstallOption.isTrusted(scriptOnly))
    }

    func testInstallConfirmationUsesTrustedPreferredOption() {
        let tool = Tool(
            id: "git",
            slug: "git",
            name: "Git",
            category: .gitCollaboration,
            installOptions: [brew]
        )
        let resolved = InstallConfirmation.resolvedOption(tool: tool)
        XCTAssertEqual(resolved?.type, .homebrewFormula)
        XCTAssertEqual(resolved?.packageName, "git")
    }

    func testMidTruncatedPathKeepsHeadAndTail() {
        let path = "/opt/homebrew/Cellar/git/2.46.0/bin/git"
        let clipped = ToolPresentationMapper.midTruncatedPath(path, maxLength: 20)
        XCTAssertLessThanOrEqual(clipped.count, 20)
        XCTAssertTrue(clipped.contains("…"))
        XCTAssertTrue(clipped.hasPrefix("/opt"))
        XCTAssertTrue(clipped.hasSuffix("git"))
    }

    private func installedProbe(version: String) -> InstallationProbe {
        InstallationProbe(
            toolID: "git",
            installedVersion: version,
            detectedPath: "/opt/homebrew/bin/git",
            architecture: .arm64,
            healthStatus: .installed
        )
    }
}
