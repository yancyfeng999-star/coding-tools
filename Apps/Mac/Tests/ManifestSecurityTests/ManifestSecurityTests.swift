import XCTest
import Foundation
import CryptoKit
@testable import ManifestSecurity
@testable import Catalog
@testable import Domain

final class ManifestSecurityTests: XCTestCase {

    // MARK: - Helpers

    private func freshKey() -> Curve25519.Signing.PrivateKey {
        Curve25519.Signing.PrivateKey()
    }

    private func registryForKey(_ key: Curve25519.Signing.PrivateKey, id: String = "k1") -> PublicKeyRegistry {
        PublicKeyRegistry(keys: [id: key.publicKey.rawRepresentation])
    }

    private func signedSnapshot(
        key: Curve25519.Signing.PrivateKey,
        keyID: String = "k1",
        expiresAt: Date? = nil,
        tools: [Tool] = [],
        revokedItems: [String] = []
    ) throws -> CatalogSnapshot {
        let snap = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "test",
            createdAt: Date(),
            expiresAt: expiresAt ?? Date().addingTimeInterval(3600),
            keyID: keyID,
            signature: "",
            tools: tools,
            revokedItems: revokedItems
        )
        // 算 canonical + 签名
        let payload = try ManifestCanonicalizer.canonicalize(snap)
        let sig = try key.signature(for: payload)
        let base64 = sig.base64EncodedString()
        return CatalogSnapshot(
            schemaVersion: snap.schemaVersion,
            catalogVersion: snap.catalogVersion,
            createdAt: snap.createdAt,
            expiresAt: snap.expiresAt,
            keyID: snap.keyID,
            signature: base64,
            tools: snap.tools,
            revokedItems: snap.revokedItems
        )
    }

    // MARK: - Tests

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

    func testExpiredSnapshotRejected() async throws {
        let key = freshKey()
        let registry = registryForKey(key)
        let verifier = Ed25519ManifestVerifier(registry: registry)
        let snap = try signedSnapshot(
            key: key,
            expiresAt: Date().addingTimeInterval(-3600)  // 已过期
        )
        do {
            try await verifier.verify(snap)
            XCTFail("Should have thrown")
        } catch ManifestSecurityError.expired {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testValidSignaturePasses() async throws {
        let key = freshKey()
        let verifier = Ed25519ManifestVerifier(registry: registryForKey(key))
        let snap = try signedSnapshot(key: key)
        try await verifier.verify(snap)
    }

    func testTamperedSignatureFails() async throws {
        let key = freshKey()
        let verifier = Ed25519ManifestVerifier(registry: registryForKey(key))
        var snap = try signedSnapshot(key: key)
        // 篡改 signature（用合法 base64 但内容是随机）
        let bogus = Data((0..<64).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
        snap = CatalogSnapshot(
            schemaVersion: snap.schemaVersion,
            catalogVersion: snap.catalogVersion,
            createdAt: snap.createdAt,
            expiresAt: snap.expiresAt,
            keyID: snap.keyID,
            signature: bogus,
            tools: snap.tools,
            revokedItems: snap.revokedItems
        )
        do {
            try await verifier.verify(snap)
            XCTFail("Should throw signatureInvalid")
        } catch ManifestSecurityError.signatureInvalid {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testSignatureBase64Malformed() async {
        let key = freshKey()
        let verifier = Ed25519ManifestVerifier(registry: registryForKey(key))
        let snap = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "x",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "k1",
            signature: "!!!not-base64!!!",
            tools: []
        )
        do {
            try await verifier.verify(snap)
            XCTFail("Should throw")
        } catch ManifestSecurityError.signatureMalformed {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testEmptySignatureFails() async {
        let key = freshKey()
        let verifier = Ed25519ManifestVerifier(registry: registryForKey(key))
        let snap = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "x",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "k1",
            signature: "",
            tools: []
        )
        do {
            try await verifier.verify(snap)
            XCTFail("Should throw signatureInvalid")
        } catch ManifestSecurityError.signatureInvalid {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testWrongKeyIDFails() async throws {
        let keyA = freshKey()
        let keyB = freshKey()
        let verifier = Ed25519ManifestVerifier(registry: registryForKey(keyA, id: "kA"))
        // 用 keyB 签，但 keyID 写 kA
        let snap = try signedSnapshot(key: keyB, keyID: "kA")
        do {
            try await verifier.verify(snap)
            XCTFail("Should throw")
        } catch {
            // 用 kA 的公钥验证 kB 的签名 → signatureInvalid
            XCTAssertTrue(error is ManifestSecurityError)
        }
    }

    func testRevokedToolIsMarked() {
        let snap = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "x",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            keyID: "k1",
            signature: "sig",
            tools: [],
            revokedItems: ["evil"]
        )
        XCTAssertTrue(snap.isRevoked(toolID: "evil"))
        XCTAssertFalse(snap.isRevoked(toolID: "good"))
    }

    func testCanonicalizeIsDeterministic() throws {
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
        let snap = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "determ-1",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            expiresAt: Date(timeIntervalSince1970: 1800000000),
            keyID: "k1",
            signature: "sig",
            tools: [tool]
        )
        let a = try ManifestCanonicalizer.canonicalize(snap)
        let b = try ManifestCanonicalizer.canonicalize(snap)
        XCTAssertEqual(a, b)
    }

    func testCanonicalizeSortedKeys() throws {
        let snap = CatalogSnapshot(
            schemaVersion: "1.0.0",
            catalogVersion: "z",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            expiresAt: Date(timeIntervalSince1970: 1800000000),
            keyID: "k1",
            signature: "sig",
            tools: []
        )
        let bytes = try ManifestCanonicalizer.canonicalize(snap)
        let s = String(data: bytes, encoding: .utf8) ?? ""
        // 顶层 key 必须按字典序：catalogVersion < createdAt < expiresAt < schemaVersion < tools
        XCTAssertTrue(s.contains("\"catalogVersion\":\"z\""), "Got: \(s)")
        XCTAssertTrue(s.contains("\"schemaVersion\":\"1.0.0\""))
        // 确认 tools 在最后
        let schemaIdx = s.range(of: "\"schemaVersion\"")?.lowerBound
        let toolsIdx = s.range(of: "\"tools\"")?.lowerBound
        XCTAssertNotNil(schemaIdx)
        XCTAssertNotNil(toolsIdx)
        if let s = schemaIdx, let t = toolsIdx {
            XCTAssertLessThan(s, t, "schemaVersion should come before tools")
        }
    }
}
