import Foundation

public enum ProbeFailureKind: String, Hashable, Sendable, Codable {
    case timedOut
    case launchFailed
    case nonZeroExit
    case versionUnparseable
}

public struct ProbeFailure: Hashable, Sendable, Codable {
    public let kind: ProbeFailureKind
    public let redactedMessage: String

    public init(kind: ProbeFailureKind, redactedMessage: String) {
        self.kind = kind
        self.redactedMessage = redactedMessage
    }
}

public enum DetectedInstallSource: String, Hashable, Sendable, Codable {
    case path
    case homebrew
    case npm
    case volta
    case nvm
    case fnm
    case mise
    case bun
    case nativeInstaller
    case appBundle
    case python
    case unknown
}

public struct DetectedToolInstallation: Hashable, Sendable, Codable, Identifiable {
    public let path: String
    public let canonicalPath: String
    public let version: String?
    public let source: DetectedInstallSource
    public let isPreferred: Bool
    public let failure: ProbeFailure?

    public var id: String { canonicalPath }

    public init(
        path: String,
        canonicalPath: String,
        version: String?,
        source: DetectedInstallSource,
        isPreferred: Bool,
        failure: ProbeFailure?
    ) {
        self.path = path
        self.canonicalPath = canonicalPath
        self.version = version
        self.source = source
        self.isPreferred = isPreferred
        self.failure = failure
    }
}

public struct ToolInstallationReport: Hashable, Sendable, Codable {
    public let toolID: String
    public let installations: [DetectedToolInstallation]
    public let isConflict: Bool

    public init(toolID: String, installations: [DetectedToolInstallation]) {
        var seen: [String: DetectedToolInstallation] = [:]
        var ordered: [DetectedToolInstallation] = []
        for item in installations {
            if seen[item.canonicalPath] == nil {
                seen[item.canonicalPath] = item
                ordered.append(item)
            }
        }
        self.toolID = toolID
        self.installations = ordered.sorted { lhs, rhs in
            if lhs.isPreferred != rhs.isPreferred { return lhs.isPreferred }
            return lhs.canonicalPath < rhs.canonicalPath
        }
        self.isConflict = Self.isConflict(among: ordered)
    }

    private static func isConflict(among items: [DetectedToolInstallation]) -> Bool {
        guard items.count > 1 else { return false }
        let versions = Set(items.map { $0.version ?? "" })
        let sources = Set(items.map(\.source))
        let runnable = Set(items.map { $0.failure == nil })
        return versions.count > 1 || sources.count > 1 || runnable.count > 1
    }
}
