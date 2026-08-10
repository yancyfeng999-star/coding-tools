import XCTest
@testable import Detection
@testable import Domain
@testable import ProcessExecution

final class DetectionTests: XCTestCase {

    // MARK: - Version parser

    func testParseVersion() {
        XCTAssertEqual(InstallationDetector.parseVersion(from: "git version 2.46.0"), "2.46.0")
        XCTAssertEqual(InstallationDetector.parseVersion(from: "Python 3.12.4"), "3.12.4")
        XCTAssertEqual(InstallationDetector.parseVersion(from: "go version go1.23.0 darwin/arm64"), "1.23.0")
        XCTAssertEqual(InstallationDetector.parseVersion(from: "node v22.7.5"), "22.7.5")
        XCTAssertEqual(InstallationDetector.parseVersion(from: "rustc 1.80.0 (a2804b2 2024-07-16)"), "1.80.0")
        XCTAssertNil(InstallationDetector.parseVersion(from: ""))
        XCTAssertNil(InstallationDetector.parseVersion(from: "no version here"))
    }

    // MARK: - System architecture (real process)

    func testSystemArchitecture() async {
        let detector = InstallationDetector()
        let arch = await detector.systemArchitecture()
        #if arch(arm64)
        XCTAssertEqual(arch, .arm64)
        #elseif arch(x86_64)
        XCTAssertEqual(arch, .x86_64)
        #endif
    }

    // MARK: - CLI probe (real processes that exist on macOS)

    func testProbeGit() async {
        // /usr/bin/git 总是存在
        let tool = makeCLI(id: "git", name: "Git", command: "git")
        let detector = InstallationDetector()
        let probe = await detector.probe(tool: tool)
        XCTAssertEqual(probe.toolID, "git")
        XCTAssertNotNil(probe.detectedPath)
        XCTAssertNotNil(probe.installedVersion, "git --version should be parseable")
        XCTAssertEqual(probe.healthStatus, .installed)
    }

    func testProbeMissingCommand() async {
        let tool = makeCLI(id: "this-does-not-exist-xyz", name: "Nope", command: "this-does-not-exist-xyz")
        let detector = InstallationDetector()
        let probe = await detector.probe(tool: tool)
        XCTAssertEqual(probe.healthStatus, .notInstalled)
        XCTAssertNil(probe.detectedPath)
        XCTAssertNil(probe.installedVersion)
    }

    func testProbeAppByBundleID() async throws {
        // 找一个本机一定存在的 App
        let tool = makeApp(id: "xcode", name: "Xcode", bundleID: "com.apple.dt.Xcode")
        let detector = InstallationDetector()
        let probe = await detector.probe(tool: tool)
        if probe.healthStatus == .notInstalled {
            // Xcode 未装：跳过（不在主断言）
            throw XCTSkip("Xcode not installed on this machine")
        }
        XCTAssertEqual(probe.healthStatus, .installed)
        XCTAssertEqual(probe.bundleID, "com.apple.dt.Xcode")
        XCTAssertNotNil(probe.detectedPath)
        // teamID 依赖 codesign -dv --format=xml 的输出格式。
        // 不同 Xcode 版本可能输出略有差异；不强制断言，仅做 smoke 验证。
        if let team = probe.teamID {
            XCTAssertFalse(team.isEmpty, "Team ID should be non-empty when extracted")
        }
    }

    // MARK: - Probe all

    func testProbeAll() async {
        let tools = [
            makeCLI(id: "git", name: "Git", command: "git"),
            makeCLI(id: "missing", name: "Missing", command: "missing-xyz-123"),
        ]
        let detector = InstallationDetector()
        let probes = await detector.probeAll(tools: tools)
        XCTAssertEqual(probes.count, 2)
        let git = probes.first(where: { $0.toolID == "git" })
        let missing = probes.first(where: { $0.toolID == "missing" })
        XCTAssertEqual(git?.healthStatus, .installed)
        XCTAssertEqual(missing?.healthStatus, .notInstalled)
    }

    // MARK: - Helpers

    private func makeCLI(id: String, name: String, command: String) -> Tool {
        Tool(
            id: id,
            slug: id,
            name: name,
            localizedName: LocalizedString(name),
            description: "test",
            localizedDescription: LocalizedString("test"),
            category: .cliUtility,
            tags: [],
            homepageURL: URL(string: "https://example.com")!,
            documentationURL: nil,
            installOptions: [],
            launchCapability: LaunchCapability(type: .cli, command: command),
            supportedArchitectures: [.arm64, .x86_64],
            minimumMacOS: "14.0",
            status: .active,
            riskLevel: .low
        )
    }

    private func makeApp(id: String, name: String, bundleID: String) -> Tool {
        Tool(
            id: id,
            slug: id,
            name: name,
            localizedName: LocalizedString(name),
            description: "test",
            localizedDescription: LocalizedString("test"),
            category: .editor,
            tags: [],
            homepageURL: URL(string: "https://example.com")!,
            documentationURL: nil,
            installOptions: [],
            launchCapability: LaunchCapability(type: .app, bundleID: bundleID),
            supportedArchitectures: [.arm64, .x86_64],
            minimumMacOS: "14.0",
            status: .active,
            riskLevel: .low
        )
    }
}
