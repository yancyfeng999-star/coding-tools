import XCTest
import Foundation
@testable import Catalog
@testable import Domain

// MARK: - URLSessionCatalogHTTPClient

final class URLSessionCatalogHTTPClientTests: XCTestCase {
    /// Stubs `CatalogHTTPClient` for deterministic loader tests.
    struct StubClient: CatalogHTTPClient {
        let data: Data
        let response: URLResponse
        let error: Error?
        func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
            if let error { throw error }
            return (data, response)
        }
    }

    func testRejectsHTTPURL() async {
        let client = URLSessionCatalogHTTPClient()
        do {
            _ = try await client.data(from: URL(string: "http://example.com/c.json")!, timeout: 1)
            XCTFail("expected failure")
        } catch let e as CatalogError {
            if case .invalidURL = e { /* ok */ } else { XCTFail("unexpected: \(e)") }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testAcceptsHTTPSURLWhenServerOK() async throws {
        // 用一个本地 HTTPS URL（GitHub raw 是 HTTPS 且无 auth）
        let url = URL(string: "https://raw.githubusercontent.com/anthropics/anthropic-cookbook/main/.gitignore")!
        let client = URLSessionCatalogHTTPClient()
        let (data, response) = try await client.data(from: url, timeout: 10)
        XCTAssertFalse(data.isEmpty)
        XCTAssertNotNil(response as? HTTPURLResponse)
    }

    func testMapsNon2xxStatusToHttpStatusError() async throws {
        // 404 path on a stable endpoint
        let url = URL(string: "https://raw.githubusercontent.com/anthropics/anthropic-cookbook/main/this-does-not-exist.json")!
        let client = URLSessionCatalogHTTPClient()
        do {
            _ = try await client.data(from: url, timeout: 10)
            XCTFail("expected 404")
        } catch let e as CatalogError {
            if case .httpStatus(let code) = e { XCTAssertEqual(code, 404) }
            else { XCTFail("unexpected: \(e)") }
        }
    }
}

// MARK: - FileSystemCatalogCache

final class FileSystemCatalogCacheTests: XCTestCase {
    private var tmpDir: URL!
    private var cache: FileSystemCatalogCache!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatalogCacheTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        cache = FileSystemCatalogCache(directory: tmpDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        cache = nil
        tmpDir = nil
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() throws {
        let data = "{\"hello\":\"world\"}".data(using: .utf8)!
        try cache.save(data: data, catalogVersion: "v1", sourceURL: URL(string: "https://example.com/v1.json")!)
        let loaded = try cache.load(catalogVersion: "v1")
        XCTAssertEqual(loaded, data)
    }

    func testLoadMissingReturnsNil() throws {
        let loaded = try cache.load(catalogVersion: "absent")
        XCTAssertNil(loaded)
    }

    func testListVersions() throws {
        try cache.save(data: Data("a".utf8), catalogVersion: "v1", sourceURL: URL(string: "https://example.com/v1.json")!)
        try cache.save(data: Data("b".utf8), catalogVersion: "v2", sourceURL: URL(string: "https://example.com/v2.json")!)
        let versions = try cache.listVersions()
        XCTAssertTrue(versions.contains("v1"))
        XCTAssertTrue(versions.contains("v2"))
    }

    func testMetadataReturnsLatest() throws {
        try cache.save(data: Data("a".utf8), catalogVersion: "v1", sourceURL: URL(string: "https://example.com/v1.json")!)
        try cache.save(data: Data("b".utf8), catalogVersion: "v2", sourceURL: URL(string: "https://example.com/v2.json")!)
        let meta = try cache.metadata()
        XCTAssertNotNil(meta)
        XCTAssertEqual(meta?.catalogVersion, "v2")
    }

    func testMetadataEmptyReturnsNil() throws {
        let meta = try cache.metadata()
        XCTAssertNil(meta)
    }

    func testSanitizeReplacesPathTraversal() throws {
        // ".." 应被替换成 "_"，避免写到上层目录
        try cache.save(data: Data("x".utf8), catalogVersion: "../../etc/passwd", sourceURL: URL(string: "https://example.com/x.json")!)
        // 期望写入 _.._.._etc_passwd.json
        let contents = try FileManager.default.contentsOfDirectory(atPath: tmpDir.path)
        XCTAssertFalse(contents.contains { $0.contains("..") && !$0.contains("_.._.._") },
                       "path traversal should be sanitized")
    }
}

// MARK: - RemoteCatalogLoader

final class RemoteCatalogLoaderNetworkTests: XCTestCase {
    private var tmpDir: URL!
    private var cache: FileSystemCatalogCache!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatalogLoaderTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        cache = FileSystemCatalogCache(directory: tmpDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        cache = nil
        tmpDir = nil
        super.tearDown()
    }

    private func makeSnapshotJSON() -> Data {
        let snapshot = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "test-1",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "k",
            signature: "s",
            tools: []
        )
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return try! enc.encode(snapshot)
    }

    func testHTTPSOnlyEnforced() async {
        let loader = RemoteCatalogLoader(
            url: URL(string: "http://example.com/c.json")!,
            httpClient: URLSessionCatalogHTTPClient(),
            cache: cache
        )
        do {
            _ = try await loader.loadCatalog()
            XCTFail("expected invalidURL")
        } catch let e as CatalogError {
            if case .invalidURL = e { /* ok */ } else { XCTFail("unexpected: \(e)") }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testNetworkFailureFallsBackToCache() async throws {
        // 预先缓存一份
        let cached = makeSnapshotJSON()
        try cache.save(data: cached, catalogVersion: "test-1", sourceURL: URL(string: "https://example.com/test-1.json")!)

        // 构造一个永远失败的 http client
        struct FailingClient: CatalogHTTPClient {
            func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
                throw URLError(.notConnectedToInternet)
            }
        }
        let loader = RemoteCatalogLoader(
            url: URL(string: "https://nonexistent.invalid.local/c.json")!,
            httpClient: FailingClient(),
            cache: cache
        )
        let snapshot = try await loader.loadCatalog()
        XCTAssertEqual(snapshot.catalogVersion, "test-1")
    }

    func testNetworkFailureNoCacheThrowsNetworkError() async {
        struct FailingClient: CatalogHTTPClient {
            func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
                throw URLError(.notConnectedToInternet)
            }
        }
        let loader = RemoteCatalogLoader(
            url: URL(string: "https://nonexistent.invalid.local/c.json")!,
            httpClient: FailingClient(),
            cache: cache
        )
        do {
            _ = try await loader.loadCatalog()
            XCTFail("expected throw")
        } catch let e as CatalogError {
            if case .network = e { /* ok */ } else { XCTFail("unexpected: \(e)") }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testSchemaMismatchThrows() async {
        struct FixedClient: CatalogHTTPClient {
            let data: Data
            func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (data, resp)
            }
        }
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "9.9.9",  // wrong
            catalogVersion: "test-1",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "k",
            signature: "s",
            tools: []
        )
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try! enc.encode(badSnapshot)

        let loader = RemoteCatalogLoader(
            url: URL(string: "https://example.com/c.json")!,
            httpClient: FixedClient(data: data),
            cache: cache
        )
        do {
            _ = try await loader.loadCatalog()
            XCTFail("expected schemaMismatch")
        } catch let e as CatalogError {
            if case .schemaMismatch(let expected, let got) = e {
                XCTAssertEqual(expected, "1.0.0")
                XCTAssertEqual(got, "9.9.9")
            } else { XCTFail("unexpected: \(e)") }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testLoadCachedReturnsLatestSnapshot() async throws {
        let cached = makeSnapshotJSON()
        try cache.save(data: cached, catalogVersion: "test-1", sourceURL: URL(string: "https://example.com/test-1.json")!)
        let loader = RemoteCatalogLoader(
            url: URL(string: "https://example.com/c.json")!,
            cache: cache
        )
        let snapshot = try await loader.loadCachedCatalog()
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.catalogVersion, "test-1")
    }

    func testLoadCachedEmptyReturnsNil() async throws {
        let loader = RemoteCatalogLoader(
            url: URL(string: "https://example.com/c.json")!,
            cache: cache
        )
        let snapshot = try await loader.loadCachedCatalog()
        XCTAssertNil(snapshot)
    }
}

// MARK: - CatalogError

final class CatalogErrorTests: XCTestCase {
    func testEquatable() {
        let pastExpiry = Date(timeIntervalSince1970: 1700000000)
        XCTAssertEqual(
            CatalogError.expired(filename: "x.json", expiresAt: pastExpiry),
            CatalogError.expired(filename: "x.json", expiresAt: pastExpiry)
        )
        XCTAssertEqual(CatalogError.signatureInvalid, CatalogError.signatureInvalid)
        XCTAssertEqual(
            CatalogError.signatureInvalidDetailed(filename: "x", reason: "y"),
            CatalogError.signatureInvalidDetailed(filename: "x", reason: "y")
        )
        XCTAssertEqual(CatalogError.revoked(toolID: "x"), CatalogError.revoked(toolID: "x"))
        XCTAssertNotEqual(CatalogError.revoked(toolID: "x"), CatalogError.revoked(toolID: "y"))
        XCTAssertNotEqual(
            CatalogError.expired(filename: "a", expiresAt: pastExpiry),
            CatalogError.signatureInvalid
        )
    }
}
