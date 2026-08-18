import Foundation

public struct CrashRecoveryStatus: Equatable, Sendable {
    public let lastCrashAt: Date?
    public let unacknowledgedCount: Int
    public let directory: URL

    public init(lastCrashAt: Date?, unacknowledgedCount: Int, directory: URL) {
        self.lastCrashAt = lastCrashAt
        self.unacknowledgedCount = unacknowledgedCount
        self.directory = directory
    }

    public var needsPrompt: Bool { unacknowledgedCount > 0 }
}

public enum CrashRecovery {
    public static func status(directory: URL, acknowledgedAt: Date?) -> CrashRecoveryStatus {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let crashes = files.filter {
            $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("crash-")
        }
        let dates: [Date] = crashes.compactMap { url in
            if let parsed = parseTimestamp(from: url.lastPathComponent) {
                return parsed
            }
            return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }
        let last = dates.max()
        let unacknowledged = dates.filter { date in
            guard let acknowledgedAt else { return true }
            return date > acknowledgedAt
        }.count
        return CrashRecoveryStatus(
            lastCrashAt: last,
            unacknowledgedCount: unacknowledged,
            directory: directory
        )
    }

    public static func parseTimestamp(from filename: String) -> Date? {
        let stem = (filename as NSString).deletingPathExtension
        let parts = stem.split(separator: "-")
        guard parts.count >= 2, let ts = TimeInterval(parts[1]) else { return nil }
        return Date(timeIntervalSince1970: ts)
    }
}
