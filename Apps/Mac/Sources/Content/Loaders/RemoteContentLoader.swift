import Foundation
import Domain
import Persistence

// MARK: - Remote Content Loader
//
// 教程/视频元数据同步与缓存。同 Catalog 模式：
// - HTTPS only
// - 本地缓存：`~/Library/Caches/CodingTools/content/<contentVersion>.json`
// - 失败回退到缓存
// 阶段 5 由子代理 B 实现。

/// 内容远程加载器。`HTTPS` only；离线/网络失败时回退到本地缓存。
public actor RemoteContentLoader: ContentLoading {
    public let manifestURL: URL
    public let cacheDirectory: URL
    public let session: URLSession

    private let fileManager: FileManager

    public init(
        manifestURL: URL,
        cacheDirectory: URL = RemoteContentLoader.defaultCacheDirectory,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.manifestURL = manifestURL
        self.cacheDirectory = cacheDirectory
        self.session = session
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    public func loadContent(toolID: String?) async throws -> [ContentItem] {
        let manifest = try await fetchManifest()
        guard let toolID = toolID else { return manifest.items }
        return manifest.items.filter { $0.toolID == toolID }
    }

    public func loadAll() async throws -> [ContentItem] {
        try await fetchManifest().items
    }

    /// 强制从远端刷新；失败时如果本地有缓存就回退。
    @discardableResult
    public func refresh() async throws -> ContentManifest {
        do {
            let manifest = try await fetchRemote()
            try persist(manifest: manifest)
            return manifest
        } catch {
            if let cached = loadFromCache() {
                return cached
            }
            throw error
        }
    }

    // MARK: - Fetch

    private func fetchManifest() async throws -> ContentManifest {
        do {
            let manifest = try await fetchRemote()
            try persist(manifest: manifest)
            return manifest
        } catch {
            if let cached = loadFromCache() {
                return cached
            }
            throw error
        }
    }

    private func fetchRemote() async throws -> ContentManifest {
        // HTTPS-only 校验
        guard manifestURL.scheme == "https" else {
            throw ContentError.invalidURL
        }
        let request = URLRequest(
            url: manifestURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ContentError.network("non-http response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ContentError.network("http \(http.statusCode)")
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let manifest = try decoder.decode(ContentManifest.self, from: data)
            guard manifest.schemaVersion == "1.0.0" else {
                throw ContentError.schemaMismatch(expected: "1.0.0", got: manifest.schemaVersion)
            }
            return manifest
        } catch let err as DecodingError {
            throw ContentError.decoding(String(describing: err))
        } catch let err as ContentError {
            throw err
        } catch {
            throw ContentError.decoding(error.localizedDescription)
        }
    }

    // MARK: - Cache

    private func cacheFileURL(for contentVersion: String) -> URL {
        cacheDirectory.appendingPathComponent("\(contentVersion).json")
    }

    private func currentCacheFileURL() -> URL? {
        // 找 cacheDirectory 里最新（按 mtime）的 .json
        guard let urls = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return urls
            .filter { $0.pathExtension == "json" }
            .max { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l < r
            }
    }

    private func loadFromCache() -> ContentManifest? {
        guard let url = currentCacheFileURL() else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ContentManifest.self, from: data)
    }

    private func persist(manifest: ContentManifest) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        let url = cacheFileURL(for: manifest.contentVersion)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Defaults

    public static var defaultCacheDirectory: URL {
        let support = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("CodingTools", isDirectory: true)
            .appendingPathComponent("content", isDirectory: true)
    }
}
