import Foundation
import AppKit
import Domain
import ProcessExecution

// MARK: - NpmGlobalAdapter
//
// npm 全局安装。**不再提供 `curl | bash` fallback**（P0-G1-5 修复）：
// 之前在 npm 失败 / 缺 packageName 时回退到 `curl -fsSL <url> | bash`，
// 与未签名目录组合形成远程代码执行漏洞。Grok / Hermes 这类无 npm 官方
// 包的工具应在 catalog installOptions 里直接给 type="official-artifact"
// 或类似受控类型，不再走本 adapter。
//
// 适用：
//   - Claude Code / Codex / Gemini CLI / OpenCode / OpenClaw 等 npm 生态工具
//
// 流程：
//   1. 仅走 `npm install -g <packageName>[@<versionRule>]`（强类型参数）
//   2. 失败 → 直接抛 InstallError，不再 fallback 到任意 shell
//   3. 用户必须先在 UI 二次确认（adapter 不静默 sudo）
//
public final class NpmGlobalAdapter: InstallAdapter, InstallAdapterWithAction, @unchecked Sendable {
    public let type: InstallActionType = .npmGlobal
    private let executor: any ProcessExecuting
    private var pendingActions: [String: InstallAction] = [:]
    private let actionsLock = NSLock()

    public init(executor: any ProcessExecuting = ProcessExecutor()) {
        self.executor = executor
    }

    public func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
        guard case .npmGlobal = action else {
            throw InstallError.unsupported(type)
        }
        return InstallPlan(id: UUID().uuidString, toolID: toolID, action: type)
    }

    public func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
        let action = actionsLock.withLock { pendingActions.removeValue(forKey: plan.id) }
        guard let action else {
            throw InstallError.preconditionFailed("NpmGlobalAdapter requires executeWithAction for action context")
        }
        return try await runNpmInstall(action: action, plan: plan, progress: progress)
    }

    /// P0-G2-1 / G1-5 修复：只走 npm install -g；删除 curl|bash 回退。
    public func executeWithAction(
        _ action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        actionsLock.withLock { pendingActions[plan.id] = action }
        return try await runNpmInstall(action: action, plan: plan, progress: progress)
    }

    public func cancel(planID: String) async {
        actionsLock.withLock { _ = pendingActions.removeValue(forKey: planID) }
    }

    // MARK: - Internals

    private func runNpmInstall(
        action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        guard case .npmGlobal(let packageName, let scriptURL, let versionRule) = action else {
            throw InstallError.unsupported(type)
        }
        // P0-G1-5：必须提供 packageName；scriptURL 不再支持任意执行。
        guard let pkg = packageName, !pkg.isEmpty else {
            throw InstallError.preconditionFailed(
                "NpmGlobalAdapter requires packageName (scriptURL fallback removed for security)"
            )
        }
        if scriptURL != nil {
            // 记录但不执行 — 提示用户改用 official-artifact 类型
            progress?(InstallProgress(planID: plan.id, stage: .installing,
                                      message: "Note: install script fallback disabled; using npm only"))
        }

        progress?(InstallProgress(planID: plan.id, stage: .installing, message: "Installing npm package \(pkg)"))
        // npm install -g <pkg>[@<versionRule>]
        var args = ["install", "-g"]
        if let rule = versionRule, !rule.isEmpty {
            args.append("\(pkg)@\(rule)")
        } else {
            args.append(pkg)
        }
        let result = try await executor.run(ProcessRequest(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["npm"] + args,
            timeout: .seconds(600)
        ))
        if result.exitCode != 0 {
            throw InstallError.failed(exitCode: result.exitCode,
                                      message: "npm install failed: \(result.stderr)")
        }
        progress?(InstallProgress(planID: plan.id, stage: .completed, message: "npm install OK"))
        return InstallResult(planID: plan.id, exitCode: 0, resolvedVersion: nil)
    }
}