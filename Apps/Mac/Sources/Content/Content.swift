import Foundation
import Domain

// MARK: - Content
//
// 教程 / 视频元数据同步与缓存。**只保存元数据 + 原文链接**，不下载不重写。
// 完整定义见 docs/PRODUCT_SPEC.md §8。
// 阶段 5 由子代理 B 实现。

public struct ContentItem: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let toolID: String?
    public let type: ContentType
    public let title: String
    public let author: String?
    public let sourceURL: URL
    public let thumbnailURL: URL?
    public let publishedAt: Date?
    public let language: String
    public let license: String?
    public let tags: [String]

    public init(
        id: String,
        toolID: String? = nil,
        type: ContentType,
        title: String,
        author: String? = nil,
        sourceURL: URL,
        thumbnailURL: URL? = nil,
        publishedAt: Date? = nil,
        language: String,
        license: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.toolID = toolID
        self.type = type
        self.title = title
        self.author = author
        self.sourceURL = sourceURL
        self.thumbnailURL = thumbnailURL
        self.publishedAt = publishedAt
        self.language = language
        self.license = license
        self.tags = tags
    }
}

public enum ContentType: String, Hashable, Sendable, Codable, CaseIterable {
    case article
    case video
    case docs
    case rss
}

public protocol ContentLoading: Sendable {
    func loadContent(toolID: String?) async throws -> [ContentItem]
    func loadAll() async throws -> [ContentItem]
}

/// 单次内容快照的 manifest 格式。Catalog 也用类似的 v1 + 签名 + 缓存。
/// 阶段 5 占位：先不加签名验证（子代理 A 走 Catalog 签名）。
public struct ContentManifest: Hashable, Sendable, Codable {
    public let schemaVersion: String
    public let contentVersion: String
    public let createdAt: Date
    public let expiresAt: Date
    public let items: [ContentItem]

    public init(
        schemaVersion: String = "1.0.0",
        contentVersion: String,
        createdAt: Date,
        expiresAt: Date,
        items: [ContentItem]
    ) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.items = items
    }

    public var isExpired: Bool { expiresAt < Date() }
}

public enum ContentError: Error, Sendable, Equatable {
    case invalidURL
    case network(String)
    case decoding(String)
    case schemaMismatch(expected: String, got: String)
}
