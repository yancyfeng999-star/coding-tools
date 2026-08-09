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
