import XCTest
@testable import Domain

final class ToolTests: XCTestCase {
    func testToolIdentity() {
        let tool = Tool(id: "git", slug: "git", name: "Git", category: .gitCollaboration)
        XCTAssertEqual(tool.id, "git")
        XCTAssertEqual(tool.category, .gitCollaboration)
    }

    func testToolCategoryAllCases() {
        XCTAssertGreaterThan(ToolCategory.allCases.count, 5)
    }
}

final class InstallationReportTests: XCTestCase {
    func testLegacyProbeWithoutNewFieldsStillDecodes() throws {
        let data = Data(#"{"toolID":"codex","installedVersion":"0.146.0","detectedPath":"~/.local/bin/codex","architecture":"arm64","bundleID":null,"teamID":null,"healthStatus":"installed","lastCheckedAt":0}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let probe = try decoder.decode(InstallationProbe.self, from: data)
        XCTAssertNil(probe.installSource)
        XCTAssertNil(probe.failure)
    }

    func testSameCanonicalPathIsNotAConflict() {
        let report = ToolInstallationReport(toolID: "grok-build", installations: [
            .fixture(path: "~/.grok/bin/grok", canonicalPath: "~/.grok/downloads/grok-1.0.5", version: "1.0.5"),
            .fixture(path: "~/.local/bin/grok", canonicalPath: "~/.grok/downloads/grok-1.0.5", version: "1.0.5"),
        ])
        XCTAssertEqual(report.installations.count, 1)
        XCTAssertFalse(report.isConflict)
    }

    func testDistinctSourcesAreAConflict() {
        let report = ToolInstallationReport(toolID: "codex", installations: [
            .fixture(path: "~/.local/bin/codex", canonicalPath: "~/.local/bin/codex", version: "0.1.0", source: .path),
            .fixture(path: "/Apps/ChatGPT.app/Contents/Resources/codex", canonicalPath: "/Apps/ChatGPT.app/Contents/Resources/codex", version: "0.1.0", source: .appBundle),
        ])
        XCTAssertTrue(report.isConflict)
        XCTAssertEqual(report.installations.count, 2)
    }
}

private extension DetectedToolInstallation {
    static func fixture(
        path: String,
        canonicalPath: String,
        version: String,
        source: DetectedInstallSource = .unknown
    ) -> Self {
        .init(
            path: path,
            canonicalPath: canonicalPath,
            version: version,
            source: source,
            isPreferred: false,
            failure: nil
        )
    }
}

final class OperationLogTests: XCTestCase {
    func testOperationLogSuccess() {
        let log = OperationLog(
            id: "log-1",
            operationType: "install",
            toolID: "git",
            startedAt: Date(),
            result: .success,
            exitCode: 0
        )
        XCTAssertEqual(log.result, .success)
        XCTAssertEqual(log.exitCode, 0)
    }
}
