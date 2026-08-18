import Foundation
import Domain

// MARK: - Shared tool presentation
//
// Domain facts map once. Cards, detail, install sheet, and menu bar only render
// the result. Views must not re-implement “is outdated / is installed”.

public enum LatestVersionFact: Equatable, Sendable {
    case notQueried
    case unavailable
    case known(String)
}

public enum ToolProbeOutcome: Equatable, Sendable {
    case missing
    case checking
    case failed
    case result(InstallationProbe)
}

public enum ToolOperationFact: Equatable, Sendable {
    case idle
    case running
    case failed
    case completedPendingConfirmation
}

public enum ToolPresentationStatus: Equatable, Sendable {
    case checking
    case notInstalled(latestVersion: String?)
    case installedCurrent(localVersion: String, latestVersion: String?)
    case updateAvailable(localVersion: String, latestVersion: String)
    case localAhead(localVersion: String, latestVersion: String)
    case broken(localVersion: String?, reason: String?)
    case versionUnknown(path: String?)
    case sourceUnavailable(reason: String)
    case operationRunning
    case operationFailed
    case completedPendingConfirmation
}

public enum ToolPrimaryAction: Equatable, Sendable {
    case install
    case open
    case update(targetVersion: String)
    case reinstall
    case repair
    case refresh
    case retry
    case unavailable
    case none
}

public enum ToolSecondaryAction: Equatable, Sendable {
    case viewInstallOptions
    case openHomepage
    case reinstall
    case refresh
    case openLocalPath
    case openDiagnostics
    case copyError
    case reportIssue
    case cancel
}

public enum LatestVersionDisplay: Equatable, Sendable {
    case known(String)
    case notQueried
    case unavailable
}

public enum LocalVersionDisplay: Equatable, Sendable {
    case known(String)
    case unreadable
    case none
}

public struct ToolPresentation: Equatable, Sendable {
    public let status: ToolPresentationStatus
    public let primaryAction: ToolPrimaryAction
    public let primaryEnabled: Bool
    public let secondaryActions: [ToolSecondaryAction]
    public let statusKey: String
    public let primaryLabelKey: String
    public let latestDisplay: LatestVersionDisplay
    public let localDisplay: LocalVersionDisplay

    public var showsUpdateAction: Bool {
        if case .update = primaryAction { return true }
        return false
    }

    public var isConfirmedCurrent: Bool {
        if case .installedCurrent(_, let latest?) = status, !latest.isEmpty {
            return true
        }
        return false
    }
}

public enum TrustedInstallOption {
    public static func isTrusted(_ option: InstallOption) -> Bool {
        do {
            let descriptor = try option.toInstallAction()
            switch descriptor {
            case .npm(let packageName, _, _):
                return packageName.map { !$0.isEmpty } ?? false
            default:
                return true
            }
        } catch {
            return false
        }
    }

    public static func first(in options: [InstallOption]) -> InstallOption? {
        options.first(where: isTrusted)
    }

    public static func canQueryLatest(_ options: [InstallOption]) -> Bool {
        options.contains { option in
            switch option.type {
            case .homebrewFormula, .homebrewCask, .npmGlobal:
                return option.packageName.map { !$0.isEmpty } ?? false
            default:
                return false
            }
        }
    }
}

public enum InstallConfirmation {
    /// Returns a signed, trusted option or nil. Never invents `npm-global` + `.low`.
    public static func resolvedOption(tool: Tool, preferred: InstallOption? = nil) -> InstallOption? {
        let candidate = preferred ?? TrustedInstallOption.first(in: tool.installOptions)
        guard let candidate, TrustedInstallOption.isTrusted(candidate) else { return nil }
        return candidate
    }
}

public enum ToolPresentationMapper {
    public static func map(
        options: [InstallOption],
        probe: ToolProbeOutcome,
        latest: LatestVersionFact,
        operation: ToolOperationFact
    ) -> ToolPresentation {
        let latestDisplay = display(for: latest)
        if operation == .running {
            return presentation(
                status: .operationRunning,
                primary: .none,
                enabled: false,
                secondary: [.cancel],
                statusKey: "tool.status.running",
                primaryKey: "tool.action.running",
                latest: latestDisplay,
                local: localDisplay(probe)
            )
        }
        if operation == .failed {
            return presentation(
                status: .operationFailed,
                primary: .retry,
                enabled: true,
                secondary: [.copyError, .reportIssue],
                statusKey: "tool.status.operationFailed",
                primaryKey: "tool.action.retry",
                latest: latestDisplay,
                local: localDisplay(probe)
            )
        }
        if operation == .completedPendingConfirmation {
            return presentation(
                status: .completedPendingConfirmation,
                primary: .refresh,
                enabled: true,
                secondary: [.copyError, .reportIssue],
                statusKey: "tool.status.installPendingConfirm",
                primaryKey: "tool.action.refresh",
                latest: latestDisplay,
                local: localDisplay(probe)
            )
        }

        switch probe {
        case .checking:
            return presentation(
                status: .checking,
                primary: .none,
                enabled: false,
                secondary: [],
                statusKey: "tool.status.checking",
                primaryKey: "tool.action.checking",
                latest: latestDisplay,
                local: .none
            )
        case .failed:
            return presentation(
                status: .versionUnknown(path: nil),
                primary: .refresh,
                enabled: true,
                secondary: [.openLocalPath, .reinstall],
                statusKey: "tool.status.probeFailed",
                primaryKey: "tool.action.refresh",
                latest: latestDisplay,
                local: .unreadable
            )
        case .missing:
            return presentation(
                status: .versionUnknown(path: nil),
                primary: .refresh,
                enabled: true,
                secondary: [.openHomepage],
                statusKey: "tool.status.unconfirmed",
                primaryKey: "tool.action.refresh",
                latest: latestDisplay,
                local: .unreadable
            )
        case .result(let result):
            return mapInstalled(
                options: options,
                probe: result,
                latest: latest,
                latestDisplay: latestDisplay
            )
        }
    }

    public static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = numericParts(lhs)
        let right = numericParts(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    public static func midTruncatedPath(_ path: String, maxLength: Int = 48) -> String {
        guard path.count > maxLength, maxLength > 3 else { return path }
        let keep = maxLength - 1
        let head = keep / 2
        let tail = keep - head
        return String(path.prefix(head)) + "…" + String(path.suffix(tail))
    }

    // MARK: - Internals

    private static func mapInstalled(
        options: [InstallOption],
        probe: InstallationProbe,
        latest: LatestVersionFact,
        latestDisplay: LatestVersionDisplay
    ) -> ToolPresentation {
        let trusted = TrustedInstallOption.first(in: options)
        switch probe.healthStatus {
        case .broken:
            return presentation(
                status: .broken(localVersion: probe.installedVersion, reason: nil),
                primary: .repair,
                enabled: trusted != nil,
                secondary: [.refresh, .openDiagnostics],
                statusKey: "tool.status.broken",
                primaryKey: trusted == nil ? "tool.action.unavailable" : "tool.action.repair",
                latest: latestDisplay,
                local: probe.installedVersion.map { .known($0) } ?? .unreadable
            )
        case .notInstalled:
            if trusted == nil {
                return presentation(
                    status: .sourceUnavailable(reason: "missing-trusted-option"),
                    primary: .unavailable,
                    enabled: false,
                    secondary: [.openHomepage, .reportIssue],
                    statusKey: "tool.status.sourceUnavailable",
                    primaryKey: "tool.action.unavailable",
                    latest: latestDisplay,
                    local: .none
                )
            }
            let latestVersion: String?
            if case .known(let value) = latest { latestVersion = value } else { latestVersion = nil }
            return presentation(
                status: .notInstalled(latestVersion: latestVersion),
                primary: .install,
                enabled: true,
                secondary: [.viewInstallOptions, .openHomepage],
                statusKey: "tool.status.notInstalled",
                primaryKey: "tool.action.install",
                latest: latestDisplay,
                local: .none
            )
        case .installed, .outdated:
            let local = probe.installedVersion
            guard let local, !local.isEmpty else {
                return presentation(
                    status: .versionUnknown(path: probe.detectedPath),
                    primary: .refresh,
                    enabled: true,
                    secondary: [.openLocalPath, .reinstall],
                    statusKey: "tool.status.unconfirmed",
                    primaryKey: "tool.action.refresh",
                    latest: latestDisplay,
                    local: .unreadable
                )
            }
            switch latest {
            case .known(let remote):
                switch compareVersions(local, remote) {
                case .orderedAscending:
                    return presentation(
                        status: .updateAvailable(localVersion: local, latestVersion: remote),
                        primary: .update(targetVersion: remote),
                        enabled: trusted != nil,
                        secondary: [.openHomepage, .viewInstallOptions],
                        statusKey: "tool.status.updateAvailable",
                        primaryKey: "tool.action.update",
                        latest: .known(remote),
                        local: .known(local)
                    )
                case .orderedDescending:
                    return presentation(
                        status: .localAhead(localVersion: local, latestVersion: remote),
                        primary: .open,
                        enabled: true,
                        secondary: [.refresh, .openDiagnostics],
                        statusKey: "tool.status.localAhead",
                        primaryKey: "tool.action.open",
                        latest: .known(remote),
                        local: .known(local)
                    )
                case .orderedSame:
                    return presentation(
                        status: .installedCurrent(localVersion: local, latestVersion: remote),
                        primary: .open,
                        enabled: true,
                        secondary: [.reinstall, .refresh],
                        statusKey: "tool.status.installed",
                        primaryKey: "tool.action.open",
                        latest: .known(remote),
                        local: .known(local)
                    )
                }
            case .notQueried:
                return presentation(
                    status: .versionUnknown(path: probe.detectedPath),
                    primary: .refresh,
                    enabled: true,
                    secondary: [.openLocalPath, .reinstall],
                    statusKey: "tool.status.unconfirmed",
                    primaryKey: "tool.action.refresh",
                    latest: .notQueried,
                    local: .known(local)
                )
            case .unavailable:
                return presentation(
                    status: .installedCurrent(localVersion: local, latestVersion: nil),
                    primary: .open,
                    enabled: true,
                    secondary: [.refresh, .openDiagnostics],
                    statusKey: "tool.latest.networkUnavailable",
                    primaryKey: "tool.action.open",
                    latest: .unavailable,
                    local: .known(local)
                )
            }
        }
    }

    private static func presentation(
        status: ToolPresentationStatus,
        primary: ToolPrimaryAction,
        enabled: Bool,
        secondary: [ToolSecondaryAction],
        statusKey: String,
        primaryKey: String,
        latest: LatestVersionDisplay,
        local: LocalVersionDisplay
    ) -> ToolPresentation {
        ToolPresentation(
            status: status,
            primaryAction: primary,
            primaryEnabled: enabled,
            secondaryActions: secondary,
            statusKey: statusKey,
            primaryLabelKey: primaryKey,
            latestDisplay: latest,
            localDisplay: local
        )
    }

    private static func display(for latest: LatestVersionFact) -> LatestVersionDisplay {
        switch latest {
        case .known(let value): return .known(value)
        case .notQueried: return .notQueried
        case .unavailable: return .unavailable
        }
    }

    private static func localDisplay(_ probe: ToolProbeOutcome) -> LocalVersionDisplay {
        if case .result(let result) = probe {
            if let version = result.installedVersion, !version.isEmpty {
                return .known(version)
            }
            if result.healthStatus == .notInstalled { return .none }
            return .unreadable
        }
        return .unreadable
    }

    private static func numericParts(_ raw: String) -> [Int] {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        return trimmed.split(separator: ".").map { segment in
            Int(segment.prefix(while: { $0.isNumber })) ?? 0
        }
    }
}
