import XCTest
@testable import ManifestSecurity
@testable import Catalog
@testable import Domain

final class ManifestSecurityTests: XCTestCase {
    func testUnknownKeyRejected() async {
        let registry = PublicKeyRegistry(keys: [:])
        let verifier = Ed25519ManifestVerifier(registry: registry)
        let snapshot = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "test",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "missing-key",
            signature: "sig",
            tools: []
        )
        do {
            try await verifier.verify(snapshot)
            XCTFail("Should have thrown")
        } catch ManifestSecurityError.unknownKey(let keyID) {
            XCTAssertEqual(keyID, "missing-key")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testExpiredSnapshotRejected() async {
        let registry = PublicKeyRegistry(keys: ["k1": Data()])
        let verifier = Ed25519ManifestVerifier(registry: registry)
        let snapshot = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "test",
            createdAt: Date().addingTimeInterval(-7200),
            expiresAt: Date().addingTimeInterval(-3600),
            keyID: "k1",
            signature: "sig",
            tools: []
        )
        do {
            try await verifier.verify(snapshot)
            XCTFail("Should have thrown")
        } catch ManifestSecurityError.expired {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}
