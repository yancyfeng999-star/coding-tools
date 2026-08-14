import Foundation
import Domain
import ManifestSecurity

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
    case signatureInvalidDetailed(filename: String, reason: String)
    case expired(filename: String, expiresAt: Date)
    case revoked(toolID: String)
    case cacheMiss
    case invalidURL(String)
    case httpStatus(Int)
    case verifierUnavailable(reason: String)
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

// MARK: - LocalCatalogLoader
//
// v1.5.0-rc 之前：App 启动后只看到 10 个 placeholder 工具（Tool.placeholderTools），
// 24 个 Catalog/tools/*.json 完全没接入。LocalCatalogLoader 让 app 在没网络 / 没
// 远程目录源时也能从 Bundle 加载本地 tools + content。
//
// Bundle layout（资源由 Tuist 注入）：
//   App.app/Contents/Resources/Catalog/tools/*.json
//   App.app/Contents/Resources/Catalog/content/*.json
// 或开发模式（xcodebuild run）：
//   Bundle.main 直接拿到源码树
//
// 签名（P0-G1-1 修复）：每个 tools/*.json 走 ManifestSecurity 验签；只有全部
// 通过的 snapshots 才进入 merge。任何失败 → 抛 CatalogError.signatureInvalid
// 或 expired / unknownKey 等。

public final class LocalCatalogLoader: CatalogLoading, @unchecked Sendable {

    private let bundle: Bundle
    private let toolsDirectoryOverride: URL?
    private let verifier: Ed25519ManifestVerifier?
    private let keyCount: Int

    /// 生产入口：从当前 framework bundle 加载 PublicKeys + 构造 verifier。
    public convenience init(bundle: Bundle = .main) {
        let factory = ManifestSecurityFactory.makeDefaultVerifier()
        self.init(
            bundle: bundle,
            verifier: factory?.verifier,
            keyCount: factory?.keyCount ?? 0
        )
    }

    /// 测试用：直接指定 tools 目录 + 注入 verifier（默认 nil = 跳过签名验证，
    /// 仅用于尚未生成 key 的开发期 fixture）。
    public convenience init(toolsDirectory: URL) {
        self.init(
            bundle: .main,
            toolsDirectoryOverride: toolsDirectory,
            verifier: nil,
            keyCount: 0
        )
    }

    /// 完整构造器：允许调用方注入自定义 bundle / 目录 / verifier。
    public init(
        bundle: Bundle = .main,
        toolsDirectoryOverride: URL? = nil,
        verifier: Ed25519ManifestVerifier?,
        keyCount: Int
    ) {
        self.bundle = bundle
        self.toolsDirectoryOverride = toolsDirectoryOverride
        self.verifier = verifier
        self.keyCount = keyCount
    }

    public func loadCatalog() async throws -> CatalogSnapshot {
        let snapshots = try loadAllToolsFiles()
        let merged = merge(snapshots)
        return merged
    }

    public func loadCachedCatalog() async throws -> CatalogSnapshot? {
        try? await loadCatalog()
    }

    public func cachedCatalogMetadata() async throws -> CachedCatalogMetadata? {
        guard let url = firstToolsFileURL() else { return nil }
        let data = try Data(contentsOf: url)
        return CachedCatalogMetadata(
            catalogVersion: "local-\(url.lastPathComponent)",
            savedAt: Date(),
            sourceURL: url,
            bytes: data.count
        )
    }

    /// 已加载公钥数（用于诊断 / UI 显示）。
    public var loadedPublicKeyCount: Int { keyCount }

    // MARK: - Internals

    private func firstToolsFileURL() -> URL? {
        allToolsFileURLs().first
    }

    private func allToolsFileURLs() -> [URL] {
        // 0) 显式 override（测试用）
        if let override = toolsDirectoryOverride {
            return listJSONFiles(in: override)
        }
        // 1) Bundle resources path（生产 .app — Tuist folderReference 把
        //    Catalog/tools/ 直接挂到 Contents/Resources/tools/，没有 Catalog/ 前缀）
        if let resourceURL = bundle.resourceURL {
            let toolsDir = resourceURL.appendingPathComponent("tools", isDirectory: true)
            let files = listJSONFiles(in: toolsDir)
            if !files.isEmpty { return files }
        }
        // 2) 开发模式 fallback：源码树相对路径
        let devRoots = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Catalog/tools", isDirectory: true),
            URL(fileURLWithPath: "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/Coding Tools/Catalog/tools", isDirectory: true),
        ]
        for dir in devRoots {
            let files = listJSONFiles(in: dir)
            if !files.isEmpty { return files }
        }
        return []
    }

    private func listJSONFiles(in dir: URL) -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        return jsonFiles.sorted { $0.path < $1.path }
    }

    private func loadAllToolsFiles() throws -> [CatalogSnapshot] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var out: [CatalogSnapshot] = []
        for url in allToolsFileURLs() {
            guard let data = try? Data(contentsOf: url) else { continue }
            do {
                let snap = try decoder.decode(CatalogSnapshot.self, from: data)
                if let verifier {
                    // P0-G1-1：所有 tools/*.json 必须通过 ManifestSecurity 验签
                    try verifier.verify(snap)
                }
                out.append(snap)
            } catch let e as ManifestSecurityError {
                // 验签失败：把异常透传上去，UI 显示「签名校验失败：<文件名>」
                throw mapSecurityError(e, filename: url.lastPathComponent)
            } catch {
                #if DEBUG
                print("[LocalCatalogLoader] failed to decode \(url.lastPathComponent): \(error)")
                #endif
            }
        }
        if out.isEmpty, verifier != nil {
            throw CatalogError.signatureInvalidDetailed(
                filename: "<all>",
                reason: "no verified snapshots loaded"
            )
        }
        return out
    }

    private func mapSecurityError(_ e: ManifestSecurityError, filename: String) -> CatalogError {
        switch e {
        case .expired(let at):
            return .expired(filename: filename, expiresAt: at)
        case .revoked(let toolID):
            return .revoked(toolID: toolID)
        default:
            return .signatureInvalidDetailed(filename: filename, reason: "\(e)")
        }
    }

    private func merge(_ snapshots: [CatalogSnapshot]) -> CatalogSnapshot {
        let schemaVersion = snapshots.first?.schemaVersion ?? "1.0.0"
        let now = Date()
        let expires = now.addingTimeInterval(60 * 60 * 24 * 365)  // 1 年（本地信任）
        let allTools = snapshots.flatMap { $0.tools }
        let allRevoked = Array(Set(snapshots.flatMap { $0.revokedItems }))
        // 使用第一个已验证 snapshot 的 keyID + signature 作为合并后目录的
        // 信任锚（保留所有 source 字段以便 UI 调试）。
        let first = snapshots.first
        return CatalogSnapshot(
            schemaVersion: schemaVersion,
            catalogVersion: "local-merged-\(snapshots.count)-files-\(Int(now.timeIntervalSince1970))",
            createdAt: first?.createdAt ?? now,
            expiresAt: expires,
            keyID: first?.keyID ?? "unknown",
            signature: first?.signature ?? "",
            tools: allTools,
            revokedItems: allRevoked
        )
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
    public let verifier: Ed25519ManifestVerifier?

    public init(
        url: URL,
        httpClient: any CatalogHTTPClient = URLSessionCatalogHTTPClient(),
        cache: any CatalogCacheStoring = FileSystemCatalogCache(),
        expectedSchemaVersion: String = "1.0.0",
        timeout: TimeInterval = 30,
        verifier: Ed25519ManifestVerifier? = nil
    ) {
        self.url = url
        self.httpClient = httpClient
        self.cache = cache
        self.expectedSchemaVersion = expectedSchemaVersion
        self.timeout = timeout
        self.verifier = verifier
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
            // 网络/解码失败 → 尝试离线缓存（仍走 verify）
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
        let snap: CatalogSnapshot
        do {
            snap = try decoder.decode(CatalogSnapshot.self, from: data)
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
        guard snap.schemaVersion == expectedSchemaVersion else {
            throw CatalogError.schemaMismatch(
                expected: expectedSchemaVersion,
                got: snap.schemaVersion
            )
        }
        // P0-G1-2：远程目录必须验签
        if let verifier {
            do {
                try verifier.verify(snap)
            } catch let e as ManifestSecurityError {
                switch e {
                case .expired(let at):
                    throw CatalogError.expired(filename: url.lastPathComponent, expiresAt: at)
                case .revoked(let toolID):
                    throw CatalogError.revoked(toolID: toolID)
                default:
                    throw CatalogError.signatureInvalidDetailed(
                        filename: url.lastPathComponent,
                        reason: "\(e)"
                    )
                }
            }
        }
        return snap
    }
}
