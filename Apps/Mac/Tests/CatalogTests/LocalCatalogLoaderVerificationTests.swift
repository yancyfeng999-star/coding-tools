import XCTest
import Foundation
import CryptoKit
import Domain
@testable import Catalog
@testable import ManifestSecurity

// MARK: - P0-G1-1/2 修复：LocalCatalogLoader 签名验签测试

final class LocalCatalogLoaderVerificationTests: XCTestCase {

    /// 构造一个 signed catalog JSON 并写到 dir/<name>.json。
    /// 失败时返回 nil（不让 throw 影响测试可读性）。
    private func writeSignedTool(_ dir: URL, name: String, sig: String, keyID: String) -> URL? {
        let json: [String: Any] = [
            "schemaVersion": "1.0.0",
            "catalogVersion": "test-\(name)",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            "keyID": keyID,
            "signature": sig,
            "tools": [],
            "revokedItems": []
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return nil }
        let url = dir.appendingPathComponent("\(name).json")
        try? data.write(to: url)
        return url
    }

    private func makeVerifier(keys: [String: Curve25519.Signing.PrivateKey]) -> (Ed25519ManifestVerifier, String) {
        let key = keys["k1"]!
        let registry = PublicKeyRegistry(keys: ["k1": key.publicKey.rawRepresentation])
        return (Ed25519ManifestVerifier(registry: registry), "k1")
    }

    private func canonicalizeForSigning(raw: [String: Any]) -> Data {
        var intermediate: [String: Any] = [:]
        for (k, v) in raw where k != "keyID" && k != "signature" {
            intermediate[k] = v
        }
        return (try? TestCanonicalJSON.write(intermediate)) ?? Data()
    }

    func testValidSignaturePasses() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("catalog-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let key = Curve25519.Signing.PrivateKey()
        let (verifier, keyID) = makeVerifier(keys: ["k1": key])
        let raw: [String: Any] = [
            "schemaVersion": "1.0.0",
            "catalogVersion": "test-git",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            "keyID": keyID,
            "signature": "",
            "tools": [],
            "revokedItems": []
        ]
        let canon = canonicalizeForSigning(raw: raw)
        let sig: String
        do {
            sig = try key.signature(for: canon).base64EncodedString()
        } catch {
            return XCTFail("签名失败: \(error)")
        }
        guard writeSignedTool(tmp, name: "git", sig: sig, keyID: keyID) != nil else {
            return XCTFail("写入失败")
        }

        let loader = LocalCatalogLoader(bundle: .main, toolsDirectoryOverride: tmp, verifier: verifier, keyCount: 1)
        let snap = try await loader.loadCatalog()
        XCTAssertGreaterThanOrEqual(snap.tools.count, 0)
    }

    func testTamperedSignatureRejected() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("catalog-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let key = Curve25519.Signing.PrivateKey()
        let (verifier, keyID) = makeVerifier(keys: ["k1": key])
        guard writeSignedTool(tmp, name: "broken", sig: "AAAA", keyID: keyID) != nil else {
            XCTFail("写入失败"); return
        }

        let loader = LocalCatalogLoader(bundle: .main, toolsDirectoryOverride: tmp, verifier: verifier, keyCount: 1)
        do {
            _ = try await loader.loadCatalog()
            XCTFail("应该抛错")
        } catch let e as CatalogError {
            switch e {
            case .signatureInvalidDetailed(let file, _):
                XCTAssertEqual(file, "broken.json")
            default:
                XCTFail("expected signatureInvalidDetailed, got \(e)")
            }
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testUnknownKeyIDRejected() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("catalog-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let key = Curve25519.Signing.PrivateKey()
        let verifier = Ed25519ManifestVerifier(registry: PublicKeyRegistry(keys: [:]))
        guard writeSignedTool(tmp, name: "x", sig: "AAAA", keyID: "k1") != nil else {
            XCTFail("写入失败"); return
        }

        let loader = LocalCatalogLoader(bundle: .main, toolsDirectoryOverride: tmp, verifier: verifier, keyCount: 0)
        do {
            _ = try await loader.loadCatalog()
            XCTFail("应该抛错")
        } catch let e as CatalogError {
            switch e {
            case .signatureInvalidDetailed(_, let reason):
                XCTAssertTrue(reason.contains("unknownKey"))
            default:
                XCTFail("expected signatureInvalidDetailed, got \(e)")
            }
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - Test-only canonical JSON writer

enum TestCanonicalJSON {
    static func write(_ v: Any) throws -> Data {
        var out = ""
        try writeValue(v, into: &out)
        return Data(out.utf8)
    }
    static func writeValue(_ v: Any, into out: inout String) throws {
        if let d = v as? [String: Any] { try writeObject(d, into: &out) }
        else if let a = v as? [Any] { try writeArray(a, into: &out) }
        else if let s = v as? String { out += encodeString(s) }
        else if let b = v as? Bool { out += b ? "true" : "false" }
        else if v is NSNull { out += "null" }
        else if let n = v as? Int { out += String(n) }
        else if let n = v as? Double { out += String(n) }
        else { throw NSError(domain: "test", code: 2) }
    }
    static func writeObject(_ d: [String: Any], into out: inout String) throws {
        out += "{"
        for (i, k) in d.keys.sorted().enumerated() {
            if i > 0 { out += "," }
            out += encodeString(k) + ":"
            try writeValue(d[k] as Any, into: &out)
        }
        out += "}"
    }
    static func writeArray(_ a: [Any], into out: inout String) throws {
        out += "["
        for (i, item) in a.enumerated() {
            if i > 0 { out += "," }
            try writeValue(item, into: &out)
        }
        out += "]"
    }
    static func encodeString(_ s: String) -> String {
        var out = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if u.value < 0x20 { out += String(format: "\\u%04x", u.value) }
                else { out += String(u) }
            }
        }
        out += "\""
        return out
    }
}