import Foundation
import Domain

public struct LatestVersionRecord: Equatable, Sendable {
    public let version: String
    public let source: VersionSource
    public let fetchedAt: Date

    public init(version: String, source: VersionSource, fetchedAt: Date) {
        self.version = version
        self.source = source
        self.fetchedAt = fetchedAt
    }
}

public enum LatestVersionFailure: Error, Equatable, Sendable {
    case unsupportedSource
    case invalidResponse
    case httpStatus(Int)
    case responseTooLarge
    case timedOut
    case networkUnavailable
}

public protocol LatestVersionProvider: Sendable {
    func latestVersion(for tool: Tool) async -> Result<LatestVersionRecord, LatestVersionFailure>
}

public protocol LatestVersionCacheInvalidating: Sendable {
    func invalidate(toolIDs: Set<String>) async
}

public final class RoutedLatestVersionProvider: LatestVersionProvider, @unchecked Sendable {
    private let registry: RegistryLatestVersionProvider

    public init(registry: RegistryLatestVersionProvider) {
        self.registry = registry
    }

    public func latestVersion(for tool: Tool) async -> Result<LatestVersionRecord, LatestVersionFailure> {
        var lastFailure: LatestVersionFailure = .unsupportedSource
        for source in VersionSourceResolver.sources(for: tool) {
            switch await registry.fetch(source: source) {
            case .success(let value):
                return .success(value)
            case .failure(let failure):
                lastFailure = failure
            }
        }
        return .failure(lastFailure)
    }
}

public actor CachedLatestVersionProvider: LatestVersionProvider, LatestVersionCacheInvalidating {
    private struct Entry {
        let record: LatestVersionRecord
        let storedAt: Date
    }

    private var cache: [String: Entry] = [:]
    private let inner: any LatestVersionProvider
    private let ttl: TimeInterval

    public init(inner: any LatestVersionProvider, ttl: TimeInterval = 600) {
        self.inner = inner
        self.ttl = ttl
    }

    public func latestVersion(for tool: Tool) async -> Result<LatestVersionRecord, LatestVersionFailure> {
        if let entry = cache[tool.id], Date().timeIntervalSince(entry.storedAt) < ttl {
            return .success(entry.record)
        }
        let result = await inner.latestVersion(for: tool)
        if case .success(let record) = result {
            cache[tool.id] = Entry(record: record, storedAt: Date())
        }
        return result
    }

    public func invalidate(toolIDs: Set<String>) {
        cache = cache.filter { !toolIDs.contains($0.key) }
    }
}
