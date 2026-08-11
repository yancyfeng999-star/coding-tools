import XCTest
@testable import Installers
@testable import Domain

// MARK: - AdapterRegistry

final class AdapterRegistryTests: XCTestCase {
    func testDefaultRegistryRegistersAllTypes() {
        let r = AdapterRegistry.defaultRegistry()
        for type in InstallActionType.allCases {
            XCTAssertNotNil(r.adapter(for: type), "missing adapter for \(type.rawValue)")
        }
    }

    func testRegisterAndLookup() {
        struct StubAdapter: InstallAdapter {
            let type: InstallActionType = .npmGlobal
            func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
                InstallPlan(id: "stub", toolID: toolID, action: type)
            }
            func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
                InstallResult(planID: plan.id, exitCode: 0, resolvedVersion: nil)
            }
            func cancel(planID: String) async {}
        }
        let r = AdapterRegistry()
        r.register(StubAdapter())
        XCTAssertNotNil(r.adapter(for: .npmGlobal))
        XCTAssertNil(r.adapter(for: .homebrewFormula))
    }

    func testRegisterOverwrites() {
        struct FirstAdapter: InstallAdapter {
            let type: InstallActionType = .npmGlobal
            func plan(toolID: String, action: InstallAction) async throws -> InstallPlan { fatalError() }
            func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult { fatalError() }
            func cancel(planID: String) async {}
        }
        struct SecondAdapter: InstallAdapter {
            let type: InstallActionType = .npmGlobal
            func plan(toolID: String, action: InstallAction) async throws -> InstallPlan { fatalError() }
            func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult { fatalError() }
            func cancel(planID: String) async {}
        }
        let r = AdapterRegistry()
        r.register(FirstAdapter())
        r.register(SecondAdapter())
        // 不验证具体类型（因为都是 stub），但确认查找不崩
        XCTAssertNotNil(r.adapter(for: .npmGlobal))
    }
}

// MARK: - InstallAction

final class InstallActionEqualityTests: XCTestCase {
    func testEquality() {
        XCTAssertEqual(
            InstallAction.homebrewFormula(name: "git"),
            InstallAction.homebrewFormula(name: "git")
        )
        XCTAssertNotEqual(
            InstallAction.homebrewFormula(name: "git"),
            InstallAction.homebrewFormula(name: "curl")
        )
        XCTAssertEqual(
            InstallAction.npmGlobal(packageName: "@x/y", scriptURL: nil, versionRule: nil),
            InstallAction.npmGlobal(packageName: "@x/y", scriptURL: nil, versionRule: nil)
        )
        XCTAssertNotEqual(
            InstallAction.npmGlobal(packageName: "@x/y", scriptURL: nil, versionRule: nil),
            InstallAction.npmGlobal(packageName: "@x/z", scriptURL: nil, versionRule: nil)
        )
    }

    func testSendable() {
        // 编译期保证 Sendable — 运行期只需断言无 crash
        let action: InstallAction = .homebrewFormula(name: "git")
        let _: Sendable = action
    }
}

// MARK: - InstallError

final class InstallErrorTests: XCTestCase {
    func testEquatable() {
        XCTAssertEqual(InstallError.cancelled, InstallError.cancelled)
        XCTAssertEqual(InstallError.timeout, InstallError.timeout)
        XCTAssertEqual(
            InstallError.failed(exitCode: 1, message: "x"),
            InstallError.failed(exitCode: 1, message: "x")
        )
        XCTAssertNotEqual(
            InstallError.failed(exitCode: 1, message: "x"),
            InstallError.failed(exitCode: 2, message: "x")
        )
    }
}

// MARK: - InstallProgress.Stage

final class InstallProgressStageTests: XCTestCase {
    func testAllStagesHaveRawValues() {
        for stage in [InstallProgress.Stage.planning,
                      .downloading, .verifying, .installing, .configuring,
                      .completed, .failed, .cancelled] {
            XCTAssertFalse(stage.rawValue.isEmpty)
        }
    }
}

// MARK: - AdapterRegistry.execute action mapping

final class AdapterRegistryExecuteTests: XCTestCase {
    func testExecuteUnsupportedThrows() async {
        // 默认 registry 没注册某种假 adapter 的情形
        let r = AdapterRegistry()  // 空 registry
        do {
            _ = try await r.execute(
                toolID: "x",
                action: .homebrewFormula(name: "git"),
                progress: nil
            )
            XCTFail("expected adapterUnavailable")
        } catch let e as InstallError {
            if case .adapterUnavailable = e { /* ok */ } else { XCTFail("unexpected: \(e)") }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }
}
