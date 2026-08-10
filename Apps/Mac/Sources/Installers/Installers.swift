import Foundation
import Domain
import ProcessExecution

// MARK: - Installers
//
// 强类型安装动作。**禁止**通过字符串拼接构造任何 shell 命令。
// 完整定义见 docs/SECURITY_MODEL.md §3。
// 阶段 3 由子代理 A 实现。

public enum InstallAction: Equatable, Sendable {
    case homebrewFormula(name: String)
    case homebrewCask(name: String)
    case miseTool(name: String, version: String?)
    case officialArtifact(
        url: URL,
        sha256: String,
        bundleID: String?,
        teamID: String?
    )
    /// npm 全局安装（适合 Node 生态 CLI 工具，如 Claude Code / Codex / Gemini CLI）。
    /// 同时支持官方 install 脚本（适合 GROK / Hermes / OpenClaw 等非 npm 工具）。
    /// scriptURL 走 `curl -fsSL <url> | bash`，需 https。
    case npmGlobal(packageName: String?, scriptURL: URL?, versionRule: String?)
}

public protocol InstallAdapter: Sendable {
    var type: InstallActionType { get }
    /// Plan 阶段：把 InstallAction 转成可执行的 InstallPlan（含 toolID 关联）。
    /// adapter 不修改参数；只检查语义合法性。
    func plan(toolID: String, action: InstallAction) async throws -> InstallPlan
    /// Execute 阶段：实际拉起进程。
    func execute(_ plan: InstallPlan, progress: InstallProgressHandler?) async throws -> InstallResult
    /// 取消正在进行的安装。
    func cancel(planID: String) async
}

public enum InstallActionType: String, Sendable, Codable, CaseIterable {
    case homebrewFormula = "homebrew-formula"
    case homebrewCask = "homebrew-cask"
    case miseTool = "mise-tool"
    case officialArtifact = "official-artifact"
    case npmGlobal = "npm-global"
}

public struct InstallPlan: Hashable, Sendable, Codable {
    public let id: String
    public let toolID: String
    public let action: InstallActionType
    public let createdAt: Date

    public init(id: String, toolID: String, action: InstallActionType, createdAt: Date = Date()) {
        self.id = id
        self.toolID = toolID
        self.action = action
        self.createdAt = createdAt
    }
}

public struct InstallResult: Hashable, Sendable, Codable {
    public let planID: String
    public let exitCode: Int32
    public let resolvedVersion: String?
    public let finishedAt: Date

    public init(planID: String, exitCode: Int32, resolvedVersion: String?, finishedAt: Date = Date()) {
        self.planID = planID
        self.exitCode = exitCode
        self.resolvedVersion = resolvedVersion
        self.finishedAt = finishedAt
    }
}

public enum InstallError: Error, Sendable, Equatable {
    case unsupported(InstallActionType)
    case cancelled
    case failed(exitCode: Int32, message: String)
    case timeout
    case adapterUnavailable(String)
    case preconditionFailed(String)
    case sha256Mismatch(expected: String, got: String)
    case bundleIDMismatch(expected: String?, actual: String?)
    case teamIDMismatch(expected: String?, actual: String?)
    case downloadFailed(String)
    case toolNotFound(String)
}

// MARK: - Progress

public struct InstallProgress: Hashable, Sendable, Codable {
    public let planID: String
    public let stage: Stage
    public let message: String
    public let percentage: Double?
    public let timestamp: Date

    public init(
        planID: String,
        stage: Stage,
        message: String,
        percentage: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.planID = planID
        self.stage = stage
        self.message = message
        self.percentage = percentage
        self.timestamp = timestamp
    }

    public enum Stage: String, Hashable, Sendable, Codable {
        case planning
        case downloading
        case verifying
        case installing
        case configuring
        case completed
        case failed
        case cancelled
    }
}

/// 进度回调。nil 表示不关心进度。
public typealias InstallProgressHandler = @Sendable (InstallProgress) -> Void

// MARK: - Registry

public final class AdapterRegistry: @unchecked Sendable {
    private var adapters: [InstallActionType: any InstallAdapter] = [:]

    public init() {}

    /// 5 个标准 adapter 全注册一遍。生产可换成可注入。
    public static func defaultRegistry() -> AdapterRegistry {
        let r = AdapterRegistry()
        r.register(HomebrewFormulaAdapter())
        r.register(HomebrewCaskAdapter())
        r.register(MiseToolAdapter())
        r.register(OfficialArtifactAdapter())
        r.register(NpmGlobalAdapter())
        return r
    }

    public func register(_ adapter: any InstallAdapter) {
        adapters[adapter.type] = adapter
    }

    public func adapter(for type: InstallActionType) -> (any InstallAdapter)? {
        adapters[type]
    }

    public func execute(
        toolID: String,
        action: InstallAction,
        progress: InstallProgressHandler? = nil
    ) async throws -> InstallResult {
        let actionType: InstallActionType
        switch action {
        case .homebrewFormula: actionType = .homebrewFormula
        case .homebrewCask: actionType = .homebrewCask
        case .miseTool: actionType = .miseTool
        case .officialArtifact: actionType = .officialArtifact
        case .npmGlobal: actionType = .npmGlobal
        }
        guard let adapter = adapters[actionType] else {
            throw InstallError.adapterUnavailable(actionType.rawValue)
        }
        let plan = try await adapter.plan(toolID: toolID, action: action)
        return try await adapter.execute(plan, progress: progress)
    }
}
