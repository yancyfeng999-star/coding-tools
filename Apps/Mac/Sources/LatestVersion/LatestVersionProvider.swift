import Foundation
import ProcessExecution

// MARK: - LatestVersionProvider
//
// 阶段 1.3.0：拉取 brew / npm 的 latest version，跟 Detection 拿到的 installed
// version 比较，给用户显示「v1.2.3 → v1.3.0」+ 一键升级。
//
// 约束：
// - 异步 + 超时（brew info 首次跑 5-10s）
// - cache TTL 1h（同 session 内不重复跑）
// - 失败 graceful skip（nil），UI 退回到无 latest 状态
// - 不读 secret，不写日志

public protocol LatestVersionProvider: Sendable {
    /// tool → installedVersion → latestVersion（String compare，nil = 拿不到）
    func latestVersion(toolID: String, installedVersion: String?) async -> String?
}

public final class CachedLatestVersionProvider: LatestVersionProvider, @unchecked Sendable {

    private let inner: LatestVersionProvider
    private let ttl: TimeInterval
    private struct Entry { let value: String?; let storedAt: Date }
    private var cache: [String: Entry] = [:]
    private let lock = NSLock()

    public init(inner: LatestVersionProvider, ttl: TimeInterval = 3600) {
        self.inner = inner
        self.ttl = ttl
    }

    public func latestVersion(toolID: String, installedVersion: String?) async -> String? {
        let key = "\(toolID)|\(installedVersion ?? "")"
        // Cache lookup：必须把 "entry 存在" 和 "value 非 nil" 分开，否则 nil 结果不
        // 会被缓存（每次都重新跑 inner）。
        let cacheHit: Bool = lock.withLock {
            guard let entry = cache[key] else { return false }
            return Date().timeIntervalSince(entry.storedAt) < ttl
        }
        if cacheHit {
            return lock.withLock { cache[key]?.value }
        }

        let result = await inner.latestVersion(toolID: toolID, installedVersion: installedVersion)
        lock.withLock {
            cache[key] = Entry(value: result, storedAt: Date())
        }
        return result
    }
}

// MARK: - CompositeLatestVersionProvider
//
// 多 provider 串行 fallback：第一个返回 non-nil 的胜出。
// 典型用法：brew 先试（formula/cask），不行 npm 试（npm-global 包）。

public final class CompositeLatestVersionProvider: LatestVersionProvider, @unchecked Sendable {
    private let providers: [LatestVersionProvider]

    public init(providers: [LatestVersionProvider]) {
        self.providers = providers
    }

    public func latestVersion(toolID: String, installedVersion: String?) async -> String? {
        for p in providers {
            if let v = await p.latestVersion(toolID: toolID, installedVersion: installedVersion) {
                return v
            }
        }
        return nil
    }
}
