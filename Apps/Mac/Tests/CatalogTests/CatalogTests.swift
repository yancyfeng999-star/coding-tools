import XCTest
@testable import Catalog
@testable import Domain

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
}
