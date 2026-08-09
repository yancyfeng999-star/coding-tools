import Foundation

// MARK: - Domain Models
//
// 这是 Coding Tools 的核心数据模型。完整定义见 docs/CATALOG_SCHEMA.md。
// 阶段 0 仅占位；阶段 2 由子代理 A 完善。

public struct Tool: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let slug: String
    public let name: String
    public let category: ToolCategory

    public init(id: String, slug: String, name: String, category: ToolCategory) {
        self.id = id
        self.slug = slug
        self.name = name
        self.category = category
    }
}

public enum ToolCategory: String, Hashable, Sendable, Codable, CaseIterable {
    case editor
    case terminal
    case gitCollaboration = "git-collaboration"
    case node
    case python
    case go
    case rust
    case java
    case database
    case apiDebug = "api-debug"
    case docker
    case aiCoding = "ai-coding"
    case frontend
    case backend
    case devops
    case cliUtility = "cli-utility"
    case languageRuntime = "language-runtime"
}

public enum RiskLevel: String, Hashable, Sendable, Codable {
    case low
    case medium
    case high
}

public struct OperationLog: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let operationType: String
    public let toolID: String?
    public let startedAt: Date
    public let finishedAt: Date?
    public let result: Result
    public let exitCode: Int32?
    public let redactedOutput: String

    public enum Result: String, Hashable, Sendable, Codable {
        case success
        case failure
        case cancelled
        case timeout
    }

    public init(
        id: String,
        operationType: String,
        toolID: String? = nil,
        startedAt: Date,
        finishedAt: Date? = nil,
        result: Result,
        exitCode: Int32? = nil,
        redactedOutput: String = ""
    ) {
        self.id = id
        self.operationType = operationType
        self.toolID = toolID
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.result = result
        self.exitCode = exitCode
        self.redactedOutput = redactedOutput
    }
}

// MARK: - Catalog Snapshot
//
// CatalogSnapshot 是远程签名目录在客户端的"视图"，属于数据契约层。
// 完整定义见 docs/CATALOG_SCHEMA.md。

public struct CatalogSnapshot: Hashable, Sendable, Codable {
    public let schemaVersion: String
    public let catalogVersion: String
    public let createdAt: Date
    public let expiresAt: Date
    public let keyID: String
    public let signature: String
    public let tools: [Tool]
    public let revokedItems: [String]

    public init(
        schemaVersion: String,
        catalogVersion: String,
        createdAt: Date,
        expiresAt: Date,
        keyID: String,
        signature: String,
        tools: [Tool],
        revokedItems: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.catalogVersion = catalogVersion
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.keyID = keyID
        self.signature = signature
        self.tools = tools
        self.revokedItems = revokedItems
    }

    public var isExpired: Bool { expiresAt < Date() }

    public func isRevoked(toolID: String) -> Bool {
        revokedItems.contains(toolID)
    }
}

// MARK: - Installation Probe
//
// Detection 模块的输出契约。属于数据契约层，所以放在 Domain。

public struct InstallationProbe: Hashable, Sendable, Codable {
    public let toolID: String
    public let installedVersion: String?
    public let detectedPath: String?
    public let architecture: Architecture?
    public let bundleID: String?
    public let teamID: String?
    public let healthStatus: HealthStatus
    public let lastCheckedAt: Date

    public init(
        toolID: String,
        installedVersion: String?,
        detectedPath: String?,
        architecture: Architecture?,
        bundleID: String? = nil,
        teamID: String? = nil,
        healthStatus: HealthStatus,
        lastCheckedAt: Date = Date()
    ) {
        self.toolID = toolID
        self.installedVersion = installedVersion
        self.detectedPath = detectedPath
        self.architecture = architecture
        self.bundleID = bundleID
        self.teamID = teamID
        self.healthStatus = healthStatus
        self.lastCheckedAt = lastCheckedAt
    }
}

public enum Architecture: String, Hashable, Sendable, Codable {
    case arm64
    case x86_64
}

public enum HealthStatus: String, Hashable, Sendable, Codable {
    case installed
    case outdated
    case broken
    case notInstalled
}
