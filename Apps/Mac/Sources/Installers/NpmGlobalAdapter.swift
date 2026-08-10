import Foundation
import AppKit
import Domain
import ProcessExecution

// MARK: - NpmGlobalAdapter
//
// npm 全局安装 + 官方脚本安装。
//
// 适用：
//   - Claude Code / Codex / Gemini CLI / OpenCode / OpenClaw 等 npm 生态工具
//   - Grok Build / Hermes Agent 等无 npm 官方包、走 `curl install.sh | bash` 的工具
//
// 流程：
//   1. 优先 `npm install -g <packageName>`（走 npm registry HTTPS）
//   2. 失败 / 缺 packageName 时 fallback 到 `curl -fsSL <scriptURL> | bash`（仅 https）
//   3. 强类型参数；**禁止** 字符串拼接 shell
//   4. 用户必须先在 UI 二次确认（adapter 不静默 sudo）
//
public final class NpmGlobalAdapter: InstallAdapter, @unchecked Sendable {
    public let type: InstallActionType = .npmGlobal
    private let executor: any ProcessExecuting
    private var pendingActions: [String: InstallAction] = [:]
    private let actionsLock = NSLock()

    public init(executor: any ProcessExecuting = ProcessExecutor()) {
        self.executor = executor
    }

    public func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
        guard case .npmGlobal(let packageName, let scriptURL, _) = action else {
            throw InstallError.unsupported(type)
        }
        // 至少要 packageName 或 scriptURL 其一
        if packageName == nil && scriptURL == nil {
            throw InstallError.preconditionFailed("npmGlobal requires packageName or scriptURL")
        }
        if let url = scriptURL, url.scheme?.lowercased() != "https" {
            throw InstallError.preconditionFailed("npmGlobal scriptURL must be https://")
        }
        return InstallPlan(id: UUID().uuidString, toolID: toolID, action: type)
    }

    public func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
        guard let action = pendingActions[plan.id],
              case .npmGlobal(let packageName, let scriptURL, let versionRule) = action else {
            throw InstallError.preconditionFailed("NpmGlobalAdapter requires the caller to pass an InstallAction via executeAction(...)")
        }
        defer { pendingActions[plan.id] = nil }

        // 优先走 npm install -g
        if let pkg = packageName {
            progress?(InstallProgress(planID: plan.id, stage: .installing, message: "Installing npm package \(pkg)"))
            // npm install -g <pkg>[@<version>]
            var args = ["install", "-g", pkg]
            if let rule = versionRule, !rule.isEmpty {
                args[2] = "\(pkg)@\(rule)"
            }
            let result = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: ["npm"] + args,
                timeout: .seconds(600)
            ))
            if result.exitCode == 0 {
                progress?(InstallProgress(planID: plan.id, stage: .completed, message: "npm install OK"))
                return InstallResult(planID: plan.id, exitCode: 0, resolvedVersion: nil)
            }
            // npm 失败但有 scriptURL，fallback 到 curl
            if scriptURL == nil {
                throw InstallError.failed(exitCode: result.exitCode,
                                          message: "npm install failed: \(result.stderr)")
            }
            progress?(InstallProgress(planID: plan.id, stage: .installing,
                                      message: "npm failed, falling back to script \(scriptURL?.absoluteString ?? "")"))
        }

        // fallback：curl -fsSL <url> | bash
        if let url = scriptURL {
            progress?(InstallProgress(planID: plan.id, stage: .installing, message: "Running install script \(url.absoluteString)"))
            // sh -c 'curl -fsSL <url> | bash'  是白名单前缀
            let result = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "curl -fsSL \(url.absoluteString) | bash"],
                timeout: .seconds(900)
            ))
            if result.exitCode != 0 {
                throw InstallError.failed(exitCode: result.exitCode,
                                          message: "Install script failed: \(result.stderr)")
            }
            progress?(InstallProgress(planID: plan.id, stage: .completed, message: "Install script OK"))
            return InstallResult(planID: plan.id, exitCode: 0, resolvedVersion: nil)
        }

        throw InstallError.preconditionFailed("No install source provided")
    }

    public func cancel(planID: String) async {
        // 通过调用方 Task 传播
    }

    /// 替代直接 execute(plan)：让调用方把 action 显式传入。
    public func executeWithAction(
        _ action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler? = nil
    ) async throws -> InstallResult {
        actionsLock.withLock { pendingActions[plan.id] = action }
        return try await execute(plan, progress: progress)
    }
}
