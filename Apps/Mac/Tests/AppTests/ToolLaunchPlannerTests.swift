import XCTest
import Domain
import Launching
@testable import UI

final class ToolLaunchPlannerTests: XCTestCase {
    func testCLIPlanRequiresAnExecutableOnDisk() {
        let tool = Tool(
            id: "true",
            slug: "true",
            name: "true",
            localizedName: LocalizedString("true"),
            description: "",
            localizedDescription: LocalizedString(""),
            category: .cliUtility,
            homepageURL: URL(string: "https://git-scm.com")!,
            launchCapability: LaunchCapability(type: .cli, command: "true"),
            riskLevel: .low
        )
        let result = ToolLaunchPlanner.makeTarget(for: tool)
        switch result {
        case .success(.cli(let command, _, let openInTerminal)):
            XCTAssertEqual(command, "true")
            XCTAssertFalse(openInTerminal)
            XCTAssertNotNil(ToolLaunchPlanner.locateExecutable(named: "true"))
        default:
            XCTFail("expected CLI target, got \(result)")
        }
    }

    func testMissingBinaryIsNotASilentSuccess() {
        let tool = Tool(
            id: "no-such-bin",
            slug: "no-such-bin",
            name: "Missing",
            localizedName: LocalizedString("Missing"),
            description: "",
            localizedDescription: LocalizedString(""),
            category: .cliUtility,
            homepageURL: URL(string: "https://git-scm.com")!,
            launchCapability: LaunchCapability(type: .cli, command: "coding-tools-missing-bin-xyz"),
            riskLevel: .low
        )
        let result = ToolLaunchPlanner.makeTarget(for: tool)
        if case .failure(.binaryNotFound("coding-tools-missing-bin-xyz")) = result {
            return
        }
        XCTFail("expected binaryNotFound, got \(result)")
    }

    func testUntrustedURLIsBlocked() {
        let tool = Tool(
            id: "evil",
            slug: "evil",
            name: "Evil",
            localizedName: LocalizedString("Evil"),
            description: "",
            localizedDescription: LocalizedString(""),
            category: .cliUtility,
            homepageURL: URL(string: "https://evil.example")!,
            launchCapability: LaunchCapability(type: .url, url: URL(string: "https://evil.example/p")!),
            riskLevel: .low
        )
        let result = ToolLaunchPlanner.makeTarget(for: tool)
        if case .failure(.urlBlocked("evil.example")) = result {
            return
        }
        XCTFail("expected urlBlocked, got \(result)")
    }
}

@MainActor
final class AppStateLaunchAndInstallCloseTests: XCTestCase {
    func testLaunchRecordsPlannerResultNotOnlyRecent() {
        let state = AppState()
        let tool = Tool(
            id: "true",
            slug: "true",
            name: "true",
            localizedName: LocalizedString("true"),
            description: "",
            localizedDescription: LocalizedString(""),
            category: .cliUtility,
            homepageURL: URL(string: "https://git-scm.com")!,
            launchCapability: LaunchCapability(type: .cli, command: "true"),
            riskLevel: .low
        )
        state.launch(tool)
        XCTAssertEqual(state.recent.first, "true")
        guard let result = state.lastLaunchResult else {
            XCTFail("launch must record the planner result")
            return
        }
        if case .success(.cli(let command, _, _)) = result {
            XCTAssertEqual(command, "true")
        } else {
            XCTFail("expected CLI launch plan, got \(result)")
        }
    }

    func testCloseInstallInvalidatesLateOutcomeSoNextSheetIsIdle() {
        let state = AppState()
        let tool = Tool(
            id: "git",
            slug: "git",
            name: "Git",
            category: .gitCollaboration,
            installOptions: [InstallOption(type: .homebrewFormula, packageName: "git", riskLevel: .low)]
        )
        state.installingTool = tool
        state.installState = .running
        let generation = state.installGeneration
        state.closeInstall()
        XCTAssertEqual(state.installState, .idle)
        XCTAssertNil(state.installingTool)
        state.finishInstallIfCurrent(generation: generation, .cancelled)
        XCTAssertEqual(state.installState, .idle)
        state.finishInstallIfCurrent(generation: generation, .failed)
        XCTAssertEqual(state.installState, .idle)
    }

    func testMissingProbePresentationIsNotNotInstalled() {
        let state = AppState()
        let tool = Tool(
            id: "git",
            slug: "git",
            name: "Git",
            category: .gitCollaboration,
            installOptions: [InstallOption(type: .homebrewFormula, packageName: "git", riskLevel: .low)]
        )
        let presentation = state.presentation(for: tool)
        XCTAssertNotEqual(presentation.statusKey, "tool.status.notInstalled")
        XCTAssertEqual(presentation.primaryAction, .refresh)
    }
}
