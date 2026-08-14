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

public final class HomebrewAdapter: InstallAdapter, InstallAdapterWithAction, @unchecked Sendable {
    public let type: InstallActionType
    private let executor: any ProcessExecuting
    private let pathResolver: HomebrewPathResolver
    private let brewPath: URL?
    private var pendingActions: [String: InstallAction] = [:]
    private let actionsLock = NSLock()

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

    /// 旧入口（plan-only）。保留 ABI 兼容；生产路径走 executeWithAction。
    public func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult {
        let action = actionsLock.withLock { pendingActions.removeValue(forKey: plan.id) }
        guard let action else {
            throw InstallError.preconditionFailed("HomebrewAdapter requires executeWithAction for action context")
        }
        return try await runBrewInstall(action: action, plan: plan, progress: progress)
    }

    /// P0-G2-2 修复：把 action 显式传给 adapter，从 action 取真实 package name
    /// 而不是从 plan.toolID 推断（之前 docker-desktop / nodejs / rust 等 4 个
    /// Homebrew tool 必失败）。
    public func executeWithAction(
        _ action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        actionsLock.withLock { pendingActions[plan.id] = action }
        return try await runBrewInstall(action: action, plan: plan, progress: progress)
    }

    public func cancel(planID: String) async {
        actionsLock.withLock { _ = pendingActions.removeValue(forKey: planID) }
    }

    // MARK: - Helpers

    private func runBrewInstall(
        action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        let packageName: String
        switch (type, action) {
        case (.homebrewFormula, .homebrewFormula(let n)):
            packageName = n
        case (.homebrewCask, .homebrewCask(let n)):
            packageName = n
        default:
            throw InstallError.unsupported(type)
        }
        guard !packageName.isEmpty else {
            throw InstallError.preconditionFailed("HomebrewAdapter requires non-empty package name")
        }

        let brew: URL
        if let provided = brewPath {
            brew = provided
        } else if let resolved = await pathResolver.resolveBrew(executor: executor) {
            brew = resolved
        } else {
            throw InstallError.toolNotFound("Homebrew not found. Install from https://brew.sh first.")
        }

        var args: [String]
        switch type {
        case .homebrewFormula: args = ["install"]
        case .homebrewCask:    args = ["install", "--cask"]
        default:               args = []
        }
        args.append(packageName)

        progress?(InstallProgress(planID: plan.id, stage: .installing, message: "Running \(brew.path) \(args.joined(separator: " "))"))

        let request = ProcessRequest(
            executableURL: brew,
            arguments: args,
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
}

public final class HomebrewFormulaAdapter: InstallAdapter, InstallAdapterWithAction, @unchecked Sendable {
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

    public func executeWithAction(
        _ action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        try await inner.executeWithAction(action, plan: plan, progress: progress)
    }

    public func cancel(planID: String) async {
        await inner.cancel(planID: planID)
    }
}

public final class HomebrewCaskAdapter: InstallAdapter, InstallAdapterWithAction, @unchecked Sendable {
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

    public func executeWithAction(
        _ action: InstallAction,
        plan: InstallPlan,
        progress: InstallProgressHandler?
    ) async throws -> InstallResult {
        try await inner.executeWithAction(action, plan: plan, progress: progress)
    }

    public func cancel(planID: String) async {
        await inner.cancel(planID: planID)
    }
}