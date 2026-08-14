import XCTest
import Foundation
import Domain
import ProcessExecution
@testable import Installers

// MARK: - P0-G2-1 修复：AdapterRegistry.executeWithAction 接线 action 上下文

final class AdapterRegistryExecuteWithActionTests: XCTestCase {

    /// 跟踪 adapter 是否真的拿到了 action（而不是只有 plan）。
    actor ActionRecorder {
        private var actionsReceived: [InstallAction] = []
        func record(_ a: InstallAction) { actionsReceived.append(a) }
        func count() -> Int { actionsReceived.count }
        func last() -> InstallAction? { actionsReceived.last }
    }

    /// Homebrew 测试用：record action 而不是真跑 brew
    final class TestHomebrewAdapter: InstallAdapter, InstallAdapterWithAction, @unchecked Sendable {
        let recorder: ActionRecorder
        init(recorder: ActionRecorder) { self.recorder = recorder }
        let type: InstallActionType = .homebrewFormula
        func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
            InstallPlan(id: "plan-\(UUID().uuidString)", toolID: toolID, action: type)
        }
        func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
            throw InstallError.preconditionFailed("must use executeWithAction")
        }
        func executeWithAction(
            _ action: InstallAction,
            plan: InstallPlan,
            progress: InstallProgressHandler?
        ) async throws -> InstallResult {
            await recorder.record(action)
            return InstallResult(planID: plan.id, exitCode: 0, resolvedVersion: nil)
        }
        func cancel(planID: String) async {}
    }

    /// Npm 测试用：record action（验证 NpmGlobalAdapter 也能接到 action）
    final class TestNpmAdapter: InstallAdapter, InstallAdapterWithAction, @unchecked Sendable {
        let recorder: ActionRecorder
        init(recorder: ActionRecorder) { self.recorder = recorder }
        let type: InstallActionType = .npmGlobal
        func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
            InstallPlan(id: "plan-\(UUID().uuidString)", toolID: toolID, action: type)
        }
        func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
            throw InstallError.preconditionFailed("must use executeWithAction")
        }
        func executeWithAction(
            _ action: InstallAction,
            plan: InstallPlan,
            progress: InstallProgressHandler?
        ) async throws -> InstallResult {
            await recorder.record(action)
            return InstallResult(planID: plan.id, exitCode: 0, resolvedVersion: nil)
        }
        func cancel(planID: String) async {}
    }

    func testExecuteWithActionForwardsActionToAdapter() async throws {
        let recorder = ActionRecorder()
        let registry = AdapterRegistry()
        registry.register(TestHomebrewAdapter(recorder: recorder))
        let action = InstallAction.homebrewFormula(name: "ripgrep")
        let result = try await registry.executeWithAction(
            toolID: "ripgrep",
            action: action,
            progress: nil
        )
        XCTAssertEqual(result.exitCode, 0)
        let count = await recorder.count()
        XCTAssertEqual(count, 1)
        let last = await recorder.last()
        if case .homebrewFormula(let name) = last {
            XCTAssertEqual(name, "ripgrep")
        } else {
            XCTFail("expected homebrewFormula")
        }
    }

    func testNpmAdapterReceivesPackageNameViaExecuteWithAction() async throws {
        let recorder = ActionRecorder()
        let registry = AdapterRegistry()
        registry.register(TestNpmAdapter(recorder: recorder))
        let action = InstallAction.npmGlobal(
            packageName: "@anthropic-ai/claude-code",
            scriptURL: nil,
            versionRule: nil
        )
        _ = try await registry.executeWithAction(
            toolID: "claude-code",
            action: action,
            progress: nil
        )
        let count = await recorder.count()
        XCTAssertEqual(count, 1)
        let last = await recorder.last()
        if case .npmGlobal(let pkg, _, _) = last {
            XCTAssertEqual(pkg, "@anthropic-ai/claude-code")
        } else {
            XCTFail("expected npmGlobal")
        }
    }

    func testPackageNameFromActionNotFromToolID() async throws {
        // P0-G2-2 修复：从 action 取真实 package name（而不是 plan.toolID）。
        // docker-desktop toolID ≠ docker packageName，应从 action 取 docker。
        let recorder = ActionRecorder()
        let registry = AdapterRegistry()
        registry.register(TestHomebrewFormulaAdapter(recorder: recorder))
        let action = InstallAction.homebrewFormula(name: "docker")
        // 即使 toolID 是 docker-desktop，action 内仍带 docker
        _ = try await registry.executeWithAction(
            toolID: "docker-desktop",
            action: action,
            progress: nil
        )
        let last = await recorder.last()
        if case .homebrewFormula(let name) = last {
            XCTAssertEqual(name, "docker", "应取 action.name=docker，而非 toolID=docker-desktop")
        } else {
            XCTFail("expected homebrewFormula")
        }
    }
}

/// 测试用：homebrew-formula adapter
final class TestHomebrewFormulaAdapter: InstallAdapter, InstallAdapterWithAction, @unchecked Sendable {
    let recorder: AdapterRegistryExecuteWithActionTests.ActionRecorder
    init(recorder: AdapterRegistryExecuteWithActionTests.ActionRecorder) { self.recorder = recorder }
    let type: InstallActionType = .homebrewFormula
    func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
        InstallPlan(id: "plan-\(UUID().uuidString)", toolID: toolID, action: type)
    }
    func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
        throw InstallError.preconditionFailed("must use executeWithAction")
    }
    func executeWithAction(
        _ action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        await recorder.record(action)
        return InstallResult(planID: plan.id, exitCode: 0, resolvedVersion: nil)
    }
    func cancel(planID: String) async {}
}

// MARK: - P0-G1-5 修复：NpmGlobalAdapter 不再走 curl|bash

final class NpmGlobalAdapterSecurityTests: XCTestCase {

    /// 真实 npm 全局安装失败应该立刻抛错，不 fallback 到 curl|bash。
    func testMissingPackageNameRejected() async throws {
        let adapter = NpmGlobalAdapter(executor: ProcessExecutor())
        let action = InstallAction.npmGlobal(packageName: nil, scriptURL: nil, versionRule: nil)
        do {
            _ = try await adapter.executeWithAction(action, plan: InstallPlan(
                id: UUID().uuidString, toolID: "x", action: .npmGlobal), progress: nil as InstallProgressHandler?)
            XCTFail("应该拒绝")
        } catch InstallError.preconditionFailed {
            // 期望
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    /// 仅给 scriptURL 不给 packageName 也会被拒绝（不再走 curl|bash）。
    func testScriptURLOnlyRejected() async throws {
        let adapter = NpmGlobalAdapter(executor: ProcessExecutor())
        let action = InstallAction.npmGlobal(
            packageName: nil,
            scriptURL: URL(string: "https://attacker.example/install.sh"),
            versionRule: nil
        )
        do {
            _ = try await adapter.executeWithAction(action, plan: InstallPlan(
                id: UUID().uuidString, toolID: "x", action: .npmGlobal), progress: nil as InstallProgressHandler?)
            XCTFail("应该拒绝（无 packageName）")
        } catch InstallError.preconditionFailed {
            // 期望
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}