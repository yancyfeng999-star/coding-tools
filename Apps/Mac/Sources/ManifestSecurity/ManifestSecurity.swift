import Foundation
import Domain

// MARK: - Manifest Security
//
// 远程目录签名验证、过期检测、撤销列表。完整定义见 docs/SECURITY_MODEL.md。
// 阶段 2 由子代理 A 实现；阶段 7 由子代理 C 接入 Sparkle 的 EdDSA 流程。

public struct PublicKeyRegistry: Sendable {
    public let keys: [String: Data]  // keyID -> Ed25519 公钥

    public init(keys: [String: Data]) {
        self.keys = keys
    }

    public func publicKey(for keyID: String) -> Data? {
        keys[keyID]
    }
}

public protocol ManifestVerifying: Sendable {
    func verify(_ snapshot: CatalogSnapshot) throws
}

public enum ManifestSecurityError: Error, Sendable, Equatable {
    case unknownKey(keyID: String)
    case signatureInvalid
    case expired(at: Date)
    case revoked(toolID: String)
}

public struct Ed25519ManifestVerifier: ManifestVerifying {
    public let registry: PublicKeyRegistry

    public init(registry: PublicKeyRegistry) {
        self.registry = registry
    }

    public func verify(_ snapshot: CatalogSnapshot) throws {
        guard registry.publicKey(for: snapshot.keyID) != nil else {
            throw ManifestSecurityError.unknownKey(keyID: snapshot.keyID)
        }
        // 阶段 2 占位：实际 Ed25519 验签由子代理 A 实现
        // 阶段 2 占位：过期检测
        if snapshot.isExpired {
            throw ManifestSecurityError.expired(at: snapshot.expiresAt)
        }
    }
}
