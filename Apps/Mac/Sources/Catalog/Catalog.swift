import Foundation
import Domain

// MARK: - Catalog
//
// 工具目录解析、搜索、分类。阶段 2 由子代理 A 实现。
// 数据契约（Tool / CatalogSnapshot）见 Domain 模块。

public protocol CatalogLoading: Sendable {
    func loadCatalog() async throws -> CatalogSnapshot
    /// 仅从缓存读取（不发起网络请求）。返回 nil 表示无缓存。
    func loadCachedCatalog() async throws -> CatalogSnapshot?
    /// 当前缓存状态。
    func cachedCatalogMetadata() async throws -> CachedCatalogMetadata?
}

public enum CatalogError: Error, Sendable, Equatable {
    case network(String)
    case decoding(String)
    case schemaMismatch(expected: String, got: String)
    case signatureInvalid
    case expired
    case revoked(toolID: String)
    case cacheMiss
    case invalidURL(String)
    case httpStatus(Int)
}

public struct CachedCatalogMetadata: Hashable, Sendable, Codable {
    public let catalogVersion: String
    public let savedAt: Date
    public let sourceURL: URL
    public let bytes: Int

    public init(catalogVersion: String, savedAt: Date, sourceURL: URL, bytes: Int) {
        self.catalogVersion = catalogVersion
        self.savedAt = savedAt
        self.sourceURL = sourceURL
        self.bytes = bytes
    }
}

// MARK: - HTTP Client (injectable for tests)

public protocol CatalogHTTPClient: Sendable {
    func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse)
}

public struct URLSessionCatalogHTTPClient: CatalogHTTPClient {
    public let session: URLSession
    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        // ATS 已要求 HTTPS；这里 defensive
        guard url.scheme?.lowercased() == "https" else {
            throw CatalogError.invalidURL("Catalog URL must be HTTPS: \(url.absoluteString)")
        }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("CodingTools/0.1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw CatalogError.httpStatus(http.statusCode)
            }
            return (data, response)
        } catch let e as CatalogError {
            throw e
        } catch {
            throw CatalogError.network(String(describing: error))
        }
    }
}

// MARK: - CacheStore

public protocol CatalogCacheStoring: Sendable {
    func save(data: Data, catalogVersion: String, sourceURL: URL) throws
    func load(catalogVersion: String) throws -> Data?
    func listVersions() throws -> [String]
    func metadata() throws -> CachedCatalogMetadata?
}

public struct FileSystemCatalogCache: CatalogCacheStoring, @unchecked Sendable {
    public let directory: URL
    public let fileManager: FileManager

    public init(
        directory: URL = FileSystemCatalogCache.defaultDirectory(),
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("CodingTools/catalog", isDirectory: true)
    }

    public func save(data: Data, catalogVersion: String, sourceURL: URL) throws {
        let url = directory.appendingPathComponent("\(Self.sanitize(catalogVersion)).json")
        let meta = CachedCatalogMetadata(
            catalogVersion: catalogVersion,
            savedAt: Date(),
            sourceURL: sourceURL,
            bytes: data.count
        )
        let metaURL = directory.appendingPathComponent("\(Self.sanitize(catalogVersion)).meta.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let metaData = try encoder.encode(meta)
        try data.write(to: url, options: .atomic)
        try metaData.write(to: metaURL, options: .atomic)
    }

    public func load(catalogVersion: String) throws -> Data? {
        let url = directory.appendingPathComponent("\(Self.sanitize(catalogVersion)).json")
        return try? Data(contentsOf: url)
    }

    public func listVersions() throws -> [String] {
        let files = try fileManager.contentsOfDirectory(atPath: directory.path)
        return files.filter { $0.hasSuffix(".json") && !$0.hasSuffix(".meta.json") }
                    .map { ($0 as NSString).deletingPathExtension }
    }

    public func metadata() throws -> CachedCatalogMetadata? {
        // 返回最新版本的 metadata
        let versions = try listVersions()
        guard let latest = versions.sorted().last else { return nil }
        let metaURL = directory.appendingPathComponent("\(latest).meta.json")
        let data = try Data(contentsOf: metaURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CachedCatalogMetadata.self, from: data)
    }

    private static func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: "/", with: "_")
         .replacingOccurrences(of: "..", with: "_")
    }
}

// MARK: - RemoteCatalogLoader

public actor RemoteCatalogLoader: CatalogLoading {
    public let url: URL
    public let httpClient: any CatalogHTTPClient
    public let cache: any CatalogCacheStoring
    public let expectedSchemaVersion: String
    public let timeout: TimeInterval
    public let decoder: JSONDecoder

    public init(
        url: URL,
        httpClient: any CatalogHTTPClient = URLSessionCatalogHTTPClient(),
        cache: any CatalogCacheStoring = FileSystemCatalogCache(),
        expectedSchemaVersion: String = "1.0.0",
        timeout: TimeInterval = 30
    ) {
        self.url = url
        self.httpClient = httpClient
        self.cache = cache
        self.expectedSchemaVersion = expectedSchemaVersion
        self.timeout = timeout
        let dec = JSONDecoder()
        // 用 ISO8601 date strategy（JSON 中是 string date-time）
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    public func loadCatalog() async throws -> CatalogSnapshot {
        // HTTPS-only：在 loader 层强制检查（mock 客户端可能不检查）
        guard url.scheme?.lowercased() == "https" else {
            throw CatalogError.invalidURL("Catalog URL must be HTTPS: \(url.absoluteString)")
        }
        do {
            let (data, _) = try await httpClient.data(from: url, timeout: timeout)
            let snapshot = try decode(data)
            // 保存到缓存
            try? cache.save(data: data, catalogVersion: snapshot.catalogVersion, sourceURL: url)
            return snapshot
        } catch let e as CatalogError {
            // 网络/解码失败 → 尝试离线缓存
            if let cached = try? loadCachedCatalog() {
                return cached
            }
            throw e
        } catch {
            // 其他错误 → fallback to cache
            if let cached = try? loadCachedCatalog() {
                return cached
            }
            throw CatalogError.network(String(describing: error))
        }
    }

    public func loadCachedCatalog() throws -> CatalogSnapshot? {
        let versions = try cache.listVersions()
        guard let latest = versions.sorted().last else { return nil }
        guard let data = try cache.load(catalogVersion: latest) else { return nil }
        return try decode(data)
    }

    public func cachedCatalogMetadata() throws -> CachedCatalogMetadata? {
        try cache.metadata()
    }

    // MARK: - Internals

    private func decode(_ data: Data) throws -> CatalogSnapshot {
        do {
            let snapshot = try decoder.decode(CatalogSnapshot.self, from: data)
            guard snapshot.schemaVersion == expectedSchemaVersion else {
                throw CatalogError.schemaMismatch(
                    expected: expectedSchemaVersion,
                    got: snapshot.schemaVersion
                )
            }
            return snapshot
        } catch let e as CatalogError {
            throw e
        } catch let DecodingError.dataCorrupted(ctx) {
            throw CatalogError.decoding("data corrupted: \(ctx.debugDescription)")
        } catch let DecodingError.keyNotFound(key, _) {
            throw CatalogError.decoding("missing key: \(key.stringValue)")
        } catch let DecodingError.typeMismatch(_, ctx) {
            throw CatalogError.decoding("type mismatch at \(ctx.codingPath.map { $0.stringValue }.joined(separator: "."))")
        } catch let DecodingError.valueNotFound(_, ctx) {
            throw CatalogError.decoding("value not found at \(ctx.codingPath.map { $0.stringValue }.joined(separator: "."))")
        } catch {
            throw CatalogError.decoding(String(describing: error))
        }
    }
}
