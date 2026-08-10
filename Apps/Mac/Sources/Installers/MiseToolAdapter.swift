import Foundation
import Domain
import ProcessExecution

// MARK: - MiseToolAdapter
//
// `mise use <tool>@<version>` —— version 可选。
// 通过 `which mise` 探测 mise 路径。

public final class MiseToolAdapter: InstallAdapter, @unchecked Sendable {
    public let type: InstallActionType = .miseTool
    private let executor: any ProcessExecuting
    private let misePath: URL?

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
        let mise: URL
        if let provided = misePath {
            mise = provided
        } else if let resolved = await resolveMise() {
            mise = resolved
        } else {
            throw InstallError.toolNotFound("mise not found. Install from https://mise.jdx.dev first.")
        }

        // 把 toolID 解析为 tool name + version（约定：toolID == tool name）
        // 真实使用方应在 InstallAction.miseTool 阶段传入 version；这里做
        // 兜底（如果 InstallAction 用了 .homebrewFormula 等被错误路由过来，
        // toolID 通常就是 tool name）。
        let (toolName, version) = parseToolID(plan.toolID)

        let args: [String]
        if let v = version {
            args = ["use", "-g", "\(toolName)@\(v)"]
        } else {
            args = ["use", "-g", toolName]
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

    public func cancel(planID: String) async {
        // 取消通过调用方 Task 传播（同 HomebrewAdapter 注释）
    }

    // MARK: - Helpers

    private func parseToolID(_ id: String) -> (name: String, version: String?) {
        // 约定: "node@22" → ("node", "22")
        let parts = id.split(separator: "@", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return (parts[0], parts[1])
        }
        return (id, nil)
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
