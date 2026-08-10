import Foundation
import CryptoKit
import Domain

// MARK: - Manifest Security
//
// 远程目录签名验证、过期检测、撤销列表。完整定义见 docs/SECURITY_MODEL.md。
// 阶段 2 由子代理 A 实现；阶段 7 由子代理 C 接入 Sparkle 的 EdDSA 流程。
//
// 验签流程：
//   1. canonical JSON：去除 keyID + signature 字段，key 按字典序排序，无空白
//   2. base64 解码 signature → Ed25519 签名（64 字节）
//   3. 用 keyID 在 PublicKeyRegistry 查公钥
//   4. CryptoKit Curve25519.Signing.PublicKey.isValidSignature 校验
//   5. expiresAt > now
//   6. revokedItems 中不含目标 tool.id

public struct PublicKeyRegistry: Sendable {
    public let keys: [String: Data]  // keyID -> Ed25519 raw public key (32 bytes)

    public init(keys: [String: Data]) {
        self.keys = keys
    }

    public func publicKey(for keyID: String) -> Data? {
        keys[keyID]
    }

    public static let empty = PublicKeyRegistry(keys: [:])
}

public protocol ManifestVerifying: Sendable {
    func verify(_ snapshot: CatalogSnapshot) throws
    func verifyPayload(_ payload: Data, keyID: String, signatureBase64: String) throws
}

public enum ManifestSecurityError: Error, Sendable, Equatable {
    case unknownKey(keyID: String)
    case signatureInvalid
    case signatureMalformed
    case expired(at: Date)
    case revoked(toolID: String)
    case canonicalizationFailed
    case publicKeyMalformed(keyID: String)
}

public struct Ed25519ManifestVerifier: ManifestVerifying {
    public let registry: PublicKeyRegistry

    public init(registry: PublicKeyRegistry) {
        self.registry = registry
    }

    public func verify(_ snapshot: CatalogSnapshot) throws {
        // 1. expiry
        if snapshot.isExpired {
            throw ManifestSecurityError.expired(at: snapshot.expiresAt)
        }

        // 2. canonical JSON
        let payload = try ManifestCanonicalizer.canonicalize(snapshot)

        // 3. signature
        try verifyPayload(payload, keyID: snapshot.keyID, signatureBase64: snapshot.signature)
    }

    public func verifyPayload(_ payload: Data, keyID: String, signatureBase64: String) throws {
        guard let keyData = registry.publicKey(for: keyID) else {
            throw ManifestSecurityError.unknownKey(keyID: keyID)
        }
        guard !signatureBase64.isEmpty else {
            throw ManifestSecurityError.signatureInvalid
        }
        guard let sigData = Data(base64Encoded: signatureBase64) else {
            throw ManifestSecurityError.signatureMalformed
        }
        guard let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            throw ManifestSecurityError.publicKeyMalformed(keyID: keyID)
        }
        // Ed25519 signatures in CryptoKit take raw 64-byte `Data` directly.
        guard sigData.count == 64 else {
            throw ManifestSecurityError.signatureMalformed
        }
        guard publicKey.isValidSignature(sigData, for: payload) else {
            throw ManifestSecurityError.signatureInvalid
        }
    }
}

// MARK: - PublicKeyLoader
//
// 从 bundle 加载公钥文件（`<keyID>.pub`，32 字节 raw）。
// Bundle.module 优先；测试环境会注入自定义 loader。

public protocol PublicKeyLoading: Sendable {
    func loadRegistry() throws -> PublicKeyRegistry
}

/// Marker class used to locate this module's framework bundle.
private final class _ManifestSecurityBundleToken {}

public struct BundlePublicKeyLoader: PublicKeyLoading {
    public let bundle: Bundle
    public let subdirectory: String

    public init(bundle: Bundle? = nil, subdirectory: String = "PublicKeys") {
        // Default: locate the bundle containing this module (works for both
        // SPM-style `.module` access and Tuist-generated framework bundles).
        self.bundle = bundle ?? Bundle(for: _ManifestSecurityBundleToken.self)
        self.subdirectory = subdirectory
    }

    public func loadRegistry() throws -> PublicKeyRegistry {
        guard let resourceURL = bundle.resourceURL else {
            return .empty
        }
        let dir = resourceURL.appendingPathComponent(subdirectory, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return .empty
        }
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        var keys: [String: Data] = [:]
        for file in files where file.pathExtension == "pub" {
            let keyID = file.deletingPathExtension().lastPathComponent
            if let data = try? Data(contentsOf: file), data.count == 32 {
                keys[keyID] = data
            }
        }
        return PublicKeyRegistry(keys: keys)
    }
}

/// 内置占位 dev 公钥（仅用于 v1.0.0 演示；生产用 Bundle loader）。
public enum InMemoryPublicKeys {
    /// 默认 dev key；raw 32 字节。空数组也行，仅允许 manifest 测试失败模式。
    public static let developmentRegistry = PublicKeyRegistry(keys: [:])
}
