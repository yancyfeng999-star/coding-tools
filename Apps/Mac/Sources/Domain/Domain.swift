import Foundation

// MARK: - Domain Models
//
// 这是 Coding Tools 的核心数据模型。完整定义见 docs/CATALOG_SCHEMA.md。
// 阶段 0/1 占位（Tool 仅 4 字段）；阶段 2 由子代理 A 补全为完整 schema 对齐
// 版本，并保留 4 字段 init 以保持现有测试可用。

public struct Tool: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let slug: String
    public let name: String
    public let localizedName: LocalizedString
    public let description: String
    public let localizedDescription: LocalizedString
    public let category: ToolCategory
    public let tags: [String]
    public let homepageURL: URL
    public let documentationURL: URL?
    public let installOptions: [InstallOption]
    public let launchCapability: LaunchCapability?
    public let supportedArchitectures: [Architecture]
    public let minimumMacOS: String
    public let status: ToolStatus
    public let riskLevel: RiskLevel

    public init(
        id: String,
        slug: String,
        name: String,
        category: ToolCategory,
        installOptions: [InstallOption] = []
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.localizedName = LocalizedString(name)
        self.description = ""
        self.localizedDescription = LocalizedString("")
        self.category = category
        self.tags = []
        self.homepageURL = URL(string: "https://example.com")!
        self.documentationURL = nil
        self.installOptions = installOptions
        self.launchCapability = nil
        self.supportedArchitectures = []
        self.minimumMacOS = "14.0"
        self.status = .active
        self.riskLevel = .low
    }

    public init(
        id: String,
        slug: String,
        name: String,
        localizedName: LocalizedString,
        description: String,
        localizedDescription: LocalizedString,
        category: ToolCategory,
        tags: [String] = [],
        homepageURL: URL,
        documentationURL: URL? = nil,
        installOptions: [InstallOption] = [],
        launchCapability: LaunchCapability? = nil,
        supportedArchitectures: [Architecture] = [],
        minimumMacOS: String = "14.0",
        status: ToolStatus = .active,
        riskLevel: RiskLevel
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.localizedName = localizedName
        self.description = description
        self.localizedDescription = localizedDescription
        self.category = category
        self.tags = tags
        self.homepageURL = homepageURL
        self.documentationURL = documentationURL
        self.installOptions = installOptions
        self.launchCapability = launchCapability
        self.supportedArchitectures = supportedArchitectures
        self.minimumMacOS = minimumMacOS
        self.status = status
        self.riskLevel = riskLevel
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.slug = try c.decode(String.self, forKey: .slug)
        self.name = try c.decode(String.self, forKey: .name)
        self.localizedName = try c.decode(LocalizedString.self, forKey: .localizedName)
        self.description = try c.decode(String.self, forKey: .description)
        self.localizedDescription = try c.decode(LocalizedString.self, forKey: .localizedDescription)
        self.category = try c.decode(ToolCategory.self, forKey: .category)
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.homepageURL = try c.decode(URL.self, forKey: .homepageURL)
        self.documentationURL = try c.decodeIfPresent(URL.self, forKey: .documentationURL)
        self.installOptions = try c.decodeIfPresent([InstallOption].self, forKey: .installOptions) ?? []
        self.launchCapability = try c.decodeIfPresent(LaunchCapability.self, forKey: .launchCapability)
        self.supportedArchitectures = try c.decodeIfPresent([Architecture].self, forKey: .supportedArchitectures) ?? []
        self.minimumMacOS = try c.decodeIfPresent(String.self, forKey: .minimumMacOS) ?? "14.0"
        self.status = try c.decodeIfPresent(ToolStatus.self, forKey: .status) ?? .active
        self.riskLevel = try c.decodeIfPresent(RiskLevel.self, forKey: .riskLevel) ?? .low
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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(String.self, forKey: .schemaVersion)
        self.catalogVersion = try c.decode(String.self, forKey: .catalogVersion)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.expiresAt = try c.decode(Date.self, forKey: .expiresAt)
        self.keyID = try c.decode(String.self, forKey: .keyID)
        self.signature = try c.decode(String.self, forKey: .signature)
        self.tools = try c.decode([Tool].self, forKey: .tools)
        self.revokedItems = try c.decodeIfPresent([String].self, forKey: .revokedItems) ?? []
    }

    public var isExpired: Bool { expiresAt < Date() }

    public func isRevoked(toolID: String) -> Bool {
        revokedItems.contains(toolID)
    }

    public var supportedSchemaVersion: String { "1.0.0" }
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
    public let installSource: DetectedInstallSource?
    public let failure: ProbeFailure?

    public init(
        toolID: String,
        installedVersion: String?,
        detectedPath: String?,
        architecture: Architecture?,
        bundleID: String? = nil,
        teamID: String? = nil,
        healthStatus: HealthStatus,
        lastCheckedAt: Date = Date(),
        installSource: DetectedInstallSource? = nil,
        failure: ProbeFailure? = nil
    ) {
        self.toolID = toolID
        self.installedVersion = installedVersion
        self.detectedPath = detectedPath
        self.architecture = architecture
        self.bundleID = bundleID
        self.teamID = teamID
        self.healthStatus = healthStatus
        self.lastCheckedAt = lastCheckedAt
        self.installSource = installSource
        self.failure = failure
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
