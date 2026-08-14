import Foundation
import Domain
import ProcessExecution

// MARK: - MiseToolAdapter
//
// `mise use <tool>@<version>` —— version 可选。
// 通过 `which mise` 探测 mise 路径。

public final class MiseToolAdapter: InstallAdapter, InstallAdapterWithAction, @unchecked Sendable {
    public let type: InstallActionType = .miseTool
    private let executor: any ProcessExecuting
    private let misePath: URL?
    private var pendingActions: [String: InstallAction] = [:]
    private let actionsLock = NSLock()

    public init(
        executor: any ProcessExecuting = ProcessExecutor(),
        misePath: URL? = nil
    ) {
        self.executor = executor
        self.misePath = misePath
    }

    public func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
        guard case .miseTool = action else { throw InstallError.unsupported(type) }
        return InstallPlan(id: UUID().uuidString, toolID: toolID, action: type)
    }

    public func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
        let action = actionsLock.withLock { pendingActions.removeValue(forKey: plan.id) }
        guard let action else {
            throw InstallError.preconditionFailed("MiseToolAdapter requires executeWithAction for action context")
        }
        return try await runMiseInstall(action: action, plan: plan, progress: progress)
    }

    /// P0-G2-2 修复：从 action 取真实 tool name + version，而非 plan.toolID。
    public func executeWithAction(
        _ action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        actionsLock.withLock { pendingActions[plan.id] = action }
        return try await runMiseInstall(action: action, plan: plan, progress: progress)
    }

    public func cancel(planID: String) async {
        actionsLock.withLock { _ = pendingActions.removeValue(forKey: planID) }
    }

    // MARK: - Helpers

    private func runMiseInstall(
        action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        guard case .miseTool(let name, let version) = action else {
            throw InstallError.unsupported(type)
        }
        guard !name.isEmpty else {
            throw InstallError.preconditionFailed("miseTool requires non-empty tool name")
        }

        let mise: URL
        if let provided = misePath {
            mise = provided
        } else if let resolved = await resolveMise() {
            mise = resolved
        } else {
            throw InstallError.toolNotFound("mise not found. Install from https://mise.jdx.dev first.")
        }

        let args: [String]
        if let v = version, !v.isEmpty {
            args = ["use", "-g", "\(name)@\(v)"]
        } else {
            args = ["use", "-g", name]
        }

        progress?(InstallProgress(planID: plan.id, stage: .installing, message: "Running \(mise.path) \(args.joined(separator: " "))"))

        let request = ProcessRequest(
            executableURL: mise,
            arguments: args,
            timeout: .seconds(1200)
        )

        do {
            let output = try await executor.run(request)
            if output.exitCode != 0 {
                throw InstallError.failed(exitCode: output.exitCode, message: output.stderr)
            }
            progress?(InstallProgress(planID: plan.id, stage: .completed, message: "mise install OK"))
            return InstallResult(planID: plan.id, exitCode: output.exitCode, resolvedVersion: version)
        } catch let e as ProcessExecutionError {
            switch e {
            case .timeout: throw InstallError.timeout
            case .cancelled:
                progress?(InstallProgress(planID: plan.id, stage: .cancelled, message: "cancelled"))
                throw InstallError.cancelled
            default: throw InstallError.failed(exitCode: -1, message: String(describing: e))
            }
        }
    }

    private func resolveMise() async -> URL? {
        for path in ["/opt/homebrew/bin/mise", "/usr/local/bin/mise", "/Users/\(NSUserName())/.local/bin/mise"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        do {
            let out = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/which"),
                arguments: ["mise"],
                timeout: .seconds(5)
            ))
            let trimmed = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, FileManager.default.isExecutableFile(atPath: trimmed) {
                return URL(fileURLWithPath: trimmed)
            }
        } catch {
            // ignore
        }
        return nil
    }
}
