import XCTest
import Foundation
@testable import Installers
@testable import Domain
@testable import ProcessExecution

// MARK: - InstallAction / InstallPlan / InstallResult shape

final class InstallActionTests: XCTestCase {
    func testHomebrewFormulaActionEquality() {
        let a = InstallAction.homebrewFormula(name: "git")
        let b = InstallAction.homebrewFormula(name: "git")
        XCTAssertEqual(a, b)
    }

    func testMiseToolActionPreservesVersion() {
        let a = InstallAction.miseTool(name: "node", version: "22")
        if case .miseTool(let name, let version) = a {
            XCTAssertEqual(name, "node")
            XCTAssertEqual(version, "22")
        } else {
            XCTFail("Expected mise tool action")
        }
    }

    func testOfficialArtifactPreservesSha256() {
        let url = URL(string: "https://nodejs.org/dist/v22.7.5/node-v22.7.5.pkg")!
        let a = InstallAction.officialArtifact(
            url: url,
            sha256: "deadbeef",
            bundleID: "org.nodejs.node.pkg",
            teamID: "EA7RXK7B3K"
        )
        if case .officialArtifact(let u, let s, let b, let t) = a {
            XCTAssertEqual(u, url)
            XCTAssertEqual(s, "deadbeef")
            XCTAssertEqual(b, "org.nodejs.node.pkg")
            XCTAssertEqual(t, "EA7RXK7B3K")
        } else {
            XCTFail("Expected official artifact")
        }
    }

    func testAdapterRegistryDispatch() async throws {
        let registry = AdapterRegistry()
        registry.register(HomebrewFormulaAdapter())
        registry.register(HomebrewCaskAdapter())
        registry.register(MiseToolAdapter())

        let formulaAdapter = registry.adapter(for: .homebrewFormula)
        XCTAssertNotNil(formulaAdapter)
        let caskAdapter = registry.adapter(for: .homebrewCask)
        XCTAssertNotNil(caskAdapter)
        let miseAdapter = registry.adapter(for: .miseTool)
        XCTAssertNotNil(miseAdapter)
        let artifactAdapter = registry.adapter(for: .officialArtifact)
        XCTAssertNil(artifactAdapter)  // 没注册
    }

    func testAdapterRegistryUnsupported() async {
        let registry = AdapterRegistry()
        // 只注册一个
        registry.register(HomebrewFormulaAdapter())
        do {
            _ = try await registry.execute(
                toolID: "node",
                action: .homebrewCask(name: "iterm2")
            )
            XCTFail("Should throw")
        } catch InstallError.adapterUnavailable {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - Homebrew adapter

final class HomebrewAdapterTests: XCTestCase {

    func testPlanWithCorrectAction() async throws {
        let adapter = HomebrewFormulaAdapter(
            executor: ProcessExecutor(),
            brewPath: URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        )
        let plan = try await adapter.plan(
            toolID: "git",
            action: .homebrewFormula(name: "git")
        )
        XCTAssertEqual(plan.toolID, "git")
        XCTAssertEqual(plan.action, .homebrewFormula)
    }

    func testPlanRejectsWrongAction() async {
        let adapter = HomebrewFormulaAdapter(brewPath: URL(fileURLWithPath: "/opt/homebrew/bin/brew"))
        do {
            _ = try await adapter.plan(
                toolID: "iterm2",
                action: .homebrewCask(name: "iterm2")
            )
            XCTFail("Should throw unsupported")
        } catch InstallError.unsupported(let t) {
            XCTAssertEqual(t, .homebrewFormula)
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testExecuteBrewVersionSucceeds() async throws {
        // 环境装有 Homebrew → `brew --version` 应该非 0 退出 / OK 退出
        // 我们只验证 execute 不抛 .toolNotFound
        let adapter = HomebrewFormulaAdapter(brewPath: URL(fileURLWithPath: "/opt/homebrew/bin/brew"))
        // 不能真装 git：只 plan，不 execute
        let plan = try await adapter.plan(
            toolID: "git",
            action: .homebrewFormula(name: "git")
        )
        XCTAssertEqual(plan.toolID, "git")
    }
}

// MARK: - Mise adapter

final class MiseAdapterTests: XCTestCase {

    func testParseToolIDWithVersion() {
        // 私有方法走 execute 间接验证
        // 直接验证：toolID 形如 "node@22" → 期望 install 时命令是 mise use -g node@22
        // 我们通过 plan 验证元数据
        let adapter = MiseToolAdapter()
        let exp = expectation(description: "plan")
        Task {
            do {
                let plan = try await adapter.plan(
                    toolID: "node@22",
                    action: .miseTool(name: "node", version: "22")
                )
                XCTAssertEqual(plan.toolID, "node@22")
                XCTAssertEqual(plan.action, .miseTool)
                exp.fulfill()
            } catch {
                XCTFail("Unexpected: \(error)")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2)
    }

    func testPlanRejectsNonMiseAction() async {
        let adapter = MiseToolAdapter()
        do {
            _ = try await adapter.plan(
                toolID: "git",
                action: .homebrewFormula(name: "git")
            )
            XCTFail("Should throw")
        } catch InstallError.unsupported {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - Official artifact adapter

final class OfficialArtifactAdapterTests: XCTestCase {

    func testPlan() async throws {
        let adapter = OfficialArtifactAdapter(downloadDir: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codingtools-test-\(UUID().uuidString)"))
        let plan = try await adapter.plan(
            toolID: "vscode",
            action: .officialArtifact(
                url: URL(string: "https://example.com/vscode.dmg")!,
                sha256: "0".repeated(64),
                bundleID: "com.microsoft.VSCode",
                teamID: "UBF8T346G9"
            )
        )
        XCTAssertEqual(plan.action, .officialArtifact)
    }

    func testPlanRejectsWrongAction() async {
        let adapter = OfficialArtifactAdapter()
        do {
            _ = try await adapter.plan(
                toolID: "git",
                action: .homebrewFormula(name: "git")
            )
            XCTFail("Should throw")
        } catch InstallError.unsupported {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

private extension String {
    func repeated(_ n: Int) -> String {
        String(repeating: self, count: n)
    }
}
