import XCTest
import Foundation
@testable import Catalog
@testable import Domain

// MARK: - Domain round-trip

final class CatalogSnapshotTests: XCTestCase {
    func testFreshSnapshotIsNotExpired() {
        let snapshot = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "test",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "test-key",
            signature: "sig",
            tools: []
        )
        XCTAssertFalse(snapshot.isExpired)
    }

    func testExpiredSnapshotIsExpired() {
        let snapshot = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "test",
            createdAt: Date().addingTimeInterval(-7200),
            expiresAt: Date().addingTimeInterval(-3600),
            keyID: "test-key",
            signature: "sig",
            tools: []
        )
        XCTAssertTrue(snapshot.isExpired)
    }

    func testSnapshotRevoked() {
        let snapshot = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "test",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "k1",
            signature: "sig",
            tools: [],
            revokedItems: ["evil-tool"]
        )
        XCTAssertTrue(snapshot.isRevoked(toolID: "evil-tool"))
        XCTAssertFalse(snapshot.isRevoked(toolID: "good-tool"))
    }

    func testSnapshotCodableRoundTrip() throws {
        let tool = Tool(
            id: "git", slug: "git", name: "Git",
            localizedName: LocalizedString(values: ["en": "Git", "zh-Hans": "Git"]),
            description: "vcs",
            localizedDescription: LocalizedString(values: ["en": "vcs", "zh-Hans": "版本控制"]),
            category: .gitCollaboration,
            tags: ["vcs"],
            homepageURL: URL(string: "https://git-scm.com")!,
            installOptions: [
                InstallOption(type: .homebrewFormula, packageName: "git", riskLevel: .low)
            ],
            launchCapability: LaunchCapability(type: .cli, command: "git"),
            supportedArchitectures: [.arm64, .x86_64],
            minimumMacOS: "14.0",
            status: .active,
            riskLevel: .low
        )
        let snapshot = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "round-trip-1",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            expiresAt: Date(timeIntervalSince1970: 1800000000),
            keyID: "k1",
            signature: "sig",
            tools: [tool],
            revokedItems: []
        )
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(snapshot)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let back = try dec.decode(CatalogSnapshot.self, from: data)
        XCTAssertEqual(back, snapshot)
    }
}

// MARK: - Loader with mock HTTP

final class RemoteCatalogLoaderTests: XCTestCase {

    private let sampleSnapshot = CatalogSnapshot(
        schemaVersion: "1.0.0",
        catalogVersion: "2026.08.10-001",
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(3600),
        keyID: "k1",
        signature: "sig",
        tools: [
            Tool(id: "git", slug: "git", name: "Git", category: .gitCollaboration)
        ]
    )

    private func sampleJSON(_ snap: CatalogSnapshot? = nil) throws -> Data {
        let s = snap ?? sampleSnapshot
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(s)
    }

    private func makeLoader(
        httpResult: Result<Data, Error>,
        cache: any CatalogCacheStoring
    ) -> RemoteCatalogLoader {
        let client = MockHTTPClient(result: httpResult)
        return RemoteCatalogLoader(
            url: URL(string: "https://example.com/catalog.json")!,
            httpClient: client,
            cache: cache
        )
    }

    private func tempCache() -> FileSystemCatalogCache {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codingtools-test-\(UUID().uuidString)", isDirectory: true)
        return FileSystemCatalogCache(directory: dir)
    }

    func testLoadSuccess() async throws {
        let cache = tempCache()
        let loader = makeLoader(httpResult: .success(try sampleJSON()), cache: cache)
        let snap = try await loader.loadCatalog()
        XCTAssertEqual(snap.catalogVersion, "2026.08.10-001")
        XCTAssertEqual(snap.tools.count, 1)
    }

    func testLoadNetworkFailureThrowsWhenNoCache() async {
        let cache = tempCache()
        let loader = makeLoader(httpResult: .failure(CatalogError.network("offline")), cache: cache)
        do {
            _ = try await loader.loadCatalog()
            XCTFail("Should have thrown")
        } catch CatalogError.network {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testLoadNetworkFailureFallbackToCache() async throws {
        // 1. 先成功加载，写入缓存
        let cache = tempCache()
        let first = makeLoader(httpResult: .success(try sampleJSON()), cache: cache)
        _ = try await first.loadCatalog()

        // 2. 第二次网络失败 → 应从缓存返回
        let second = makeLoader(httpResult: .failure(CatalogError.network("offline")), cache: cache)
        let snap = try await second.loadCatalog()
        XCTAssertEqual(snap.catalogVersion, "2026.08.10-001")
    }

    func testCachedMetadata() async throws {
        let cache = tempCache()
        let loader = makeLoader(httpResult: .success(try sampleJSON()), cache: cache)
        _ = try await loader.loadCatalog()
        let meta = try await loader.cachedCatalogMetadata()
        XCTAssertNotNil(meta)
        XCTAssertEqual(meta?.catalogVersion, "2026.08.10-001")
        XCTAssertGreaterThan(meta?.bytes ?? 0, 0)
    }

    func testSchemaMismatch() async throws {
        let bad = CatalogSnapshot(
            schemaVersion: "2.5.0",  // 不同 schema version
            catalogVersion: "x",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "k1",
            signature: "sig",
            tools: []
        )
        let cache = tempCache()
        let loader = makeLoader(httpResult: .success(try sampleJSON(bad)), cache: cache)
        do {
            _ = try await loader.loadCatalog()
            XCTFail("Should throw schemaMismatch")
        } catch CatalogError.schemaMismatch(let expected, let got) {
            XCTAssertEqual(expected, "1.0.0")
            XCTAssertEqual(got, "2.5.0")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testInvalidJSONThrows() async {
        let cache = tempCache()
        let loader = makeLoader(httpResult: .success(Data("not json".utf8)), cache: cache)
        do {
            _ = try await loader.loadCatalog()
            XCTFail("Should throw decoding error")
        } catch CatalogError.decoding {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testLoadCachedEmptyReturnsNil() async throws {
        let cache = tempCache()
        let loader = makeLoader(httpResult: .success(Data()), cache: cache)
        let snap = try await loader.loadCachedCatalog()
        XCTAssertNil(snap)
    }

    func testNonHTTPSURLRejected() async {
        let client = MockHTTPClient(result: .success(Data()))
        let loader = RemoteCatalogLoader(
            url: URL(string: "http://example.com/catalog.json")!,
            httpClient: client,
            cache: tempCache()
        )
        do {
            _ = try await loader.loadCatalog()
            XCTFail("Should throw invalidURL")
        } catch CatalogError.invalidURL {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - Mock HTTP client

struct MockHTTPClient: CatalogHTTPClient {
    let result: Result<Data, Error>
    func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        switch result {
        case .success(let d):
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (d, resp)
        case .failure(let e):
            throw e
        }
    }
}

struct FailingHTTPClient: CatalogHTTPClient {
    let statusCode: Int
    func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        let resp = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (Data(), resp)
    }
}
