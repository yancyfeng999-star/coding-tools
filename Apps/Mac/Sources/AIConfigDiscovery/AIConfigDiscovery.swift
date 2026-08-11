import Foundation

// MARK: - AIConfig
//
// 启动时在用户 home 目录里扫到的已存在 AI CLI 配置文件。
// 不读 secret / API key；只读顶层 metadata（model / mtime / size）。
//
// toolID 对应 Catalog 里的 tool id（claude-code / codex / gemini-cli / opencode / grok-build / hermes / openclaw）。

public struct AIConfig: Hashable, Sendable, Identifiable {
    public let toolID: String
    public let configPath: URL
    public let mtime: Date
    public let sizeBytes: Int
    public let hasAPIKey: Bool
    public let model: String?
    public let detectedFormat: ConfigFormat

    public var id: URL { configPath }

    public init(
        toolID: String,
        configPath: URL,
        mtime: Date,
        sizeBytes: Int,
        hasAPIKey: Bool,
        model: String?,
        detectedFormat: ConfigFormat
    ) {
        self.toolID = toolID
        self.configPath = configPath
        self.mtime = mtime
        self.sizeBytes = sizeBytes
        self.hasAPIKey = hasAPIKey
        self.model = model
        self.detectedFormat = detectedFormat
    }
}

public enum ConfigFormat: String, Sendable, Hashable {
    case json
    case toml
    case unknown
}

// MARK: - AIConfigDiscovering
//
// 启动时跑一次，扫所有已知 AI CLI 的配置目录。
// 不抛错（path 不存在 / 损坏 JSON 都 graceful skip）。

public protocol AIConfigDiscovering: Sendable {
    func discover() async -> [AIConfig]
}
