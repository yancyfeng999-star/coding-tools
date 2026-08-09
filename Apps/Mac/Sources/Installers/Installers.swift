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
}

public protocol InstallAdapter: Sendable {
    var type: InstallActionType { get }
    func plan(_ action: InstallAction) async throws -> InstallPlan
    func execute(_ plan: InstallPlan) async throws -> InstallResult
    func cancel(planID: String) async
}

public enum InstallActionType: String, Sendable, Codable, CaseIterable {
    case homebrewFormula = "homebrew-formula"
    case homebrewCask = "homebrew-cask"
    case miseTool = "mise-tool"
    case officialArtifact = "official-artifact"
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
}
