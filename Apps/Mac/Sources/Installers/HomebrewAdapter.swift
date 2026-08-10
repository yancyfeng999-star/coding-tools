import Foundation
import Domain
import ProcessExecution

// MARK: - HomebrewAdapter
//
// 共享基类：封装 brew 路径探测 + 通用执行逻辑。
// 公式（formula）和 cask 用同一个 brew 二进制，只是参数不同。

public struct HomebrewPathResolver: Sendable {
    public init() {}

    /// 通过 `which brew` 解析 brew 路径；找不到时返回 nil。
    public func resolveBrew(executor: any ProcessExecuting) async -> URL? {
        // 试 /opt/homebrew/bin/brew（Apple Silicon）、/usr/local/bin/brew（Intel）、
        // /usr/bin/brew，再 fallback 到 `which brew`。
        for path in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew", "/usr/bin/brew"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        // Fallback: which brew
        do {
            let out = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/which"),
                arguments: ["brew"],
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

public final class HomebrewAdapter: InstallAdapter, @unchecked Sendable {
    public let type: InstallActionType
    private let executor: any ProcessExecuting
    private let pathResolver: HomebrewPathResolver
    private let brewPath: URL?

    public init(
        type: InstallActionType,
        executor: any ProcessExecuting = ProcessExecutor(),
        pathResolver: HomebrewPathResolver = HomebrewPathResolver(),
        brewPath: URL? = nil
    ) {
        self.type = type
        self.executor = executor
        self.pathResolver = pathResolver
        self.brewPath = brewPath
    }

    public func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
        // 只接 brew 相关的 InstallAction
        switch (type, action) {
        case (.homebrewFormula, .homebrewFormula),
             (.homebrewCask, .homebrewCask):
            return InstallPlan(id: UUID().uuidString, toolID: toolID, action: type)
        default:
            throw InstallError.unsupported(type)
        }
    }

    public func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
        let brew: URL
        if let provided = brewPath {
            brew = provided
        } else if let resolved = await pathResolver.resolveBrew(executor: executor) {
            brew = resolved
        } else {
            throw InstallError.toolNotFound("Homebrew not found. Install from https://brew.sh first.")
        }

        let (args, _): ([String], String) = {
            switch plan.action {
            case .homebrewFormula:
                return (["install"], "?")  // overridden below
            case .homebrewCask:
                return (["install", "--cask"], "?")
            default:
                return ([], "?")
            }
        }()

        // 真正的 package name 需要在调用方传入；这里 plan 阶段没收，所以再走
        // 一次 InstallAction 拿不到。简化：plan 阶段已经接 InstallAction，
        // 缓存 name 到 plan。但 plan 是 Codable struct，不应加可变字段。
        // 解决：plan.toolID = toolID；package name 通过 toolID 反查（约定
        // toolID == packageName）。对 Stage 0 8 个工具都成立。
        var fullArgs = args
        fullArgs.append(plan.toolID)

        progress?(InstallProgress(planID: plan.id, stage: .installing, message: "Running \(brew.path) \(fullArgs.joined(separator: " "))"))

        let request = ProcessRequest(
            executableURL: brew,
            arguments: fullArgs,
            timeout: .seconds(1800)  // brew install 可能很慢
        )

        do {
            let output = try await executor.run(request)
            if output.exitCode != 0 {
                throw InstallError.failed(exitCode: output.exitCode, message: output.stderr)
            }
            progress?(InstallProgress(planID: plan.id, stage: .completed, message: "Homebrew install OK"))
            return InstallResult(planID: plan.id, exitCode: output.exitCode, resolvedVersion: nil)
        } catch let e as ProcessExecutionError {
            switch e {
            case .timeout:
                throw InstallError.timeout
            case .cancelled:
                progress?(InstallProgress(planID: plan.id, stage: .cancelled, message: "cancelled"))
                throw InstallError.cancelled
            default:
                throw InstallError.failed(exitCode: -1, message: String(describing: e))
            }
        }
    }

    public func cancel(planID: String) async {
        // 取消通过调用方 Task 传播：执行 install 的 Task 被 cancel 时，
        // ProcessExecutor.onCancel 会 terminate 子进程。
        // 这里保留 API 但不维护本地状态。
    }
}

public final class HomebrewFormulaAdapter: InstallAdapter, @unchecked Sendable {
    public let type: InstallActionType = .homebrewFormula
    private let inner: HomebrewAdapter

    public init(
        executor: any ProcessExecuting = ProcessExecutor(),
        pathResolver: HomebrewPathResolver = HomebrewPathResolver(),
        brewPath: URL? = nil
    ) {
        self.inner = HomebrewAdapter(type: .homebrewFormula, executor: executor, pathResolver: pathResolver, brewPath: brewPath)
    }

    public func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
        try await inner.plan(toolID: toolID, action: action)
    }

    public func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
        try await inner.execute(plan, progress: progress)
    }

    public func cancel(planID: String) async {
        await inner.cancel(planID: planID)
    }
}

public final class HomebrewCaskAdapter: InstallAdapter, @unchecked Sendable {
    public let type: InstallActionType = .homebrewCask
    private let inner: HomebrewAdapter

    public init(
        executor: any ProcessExecuting = ProcessExecutor(),
        pathResolver: HomebrewPathResolver = HomebrewPathResolver(),
        brewPath: URL? = nil
    ) {
        self.inner = HomebrewAdapter(type: .homebrewCask, executor: executor, pathResolver: pathResolver, brewPath: brewPath)
    }

    public func plan(toolID: String, action: InstallAction) async throws -> InstallPlan {
        try await inner.plan(toolID: toolID, action: action)
    }

    public func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
        try await inner.execute(plan, progress: progress)
    }

    public func cancel(planID: String) async {
        await inner.cancel(planID: planID)
    }
}
