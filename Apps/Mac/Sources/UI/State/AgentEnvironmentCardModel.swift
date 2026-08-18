import Foundation
import Domain
import LatestVersion

public struct AgentEnvironmentCardModel: Equatable, Sendable {
    public let toolName: String
    public let healthStatus: HealthStatus
    public let localSummary: String
    public let latestSummary: String
    public let sourceLabel: String
    public let conflictCount: Int
    public let primaryAction: ToolPrimaryAction
    public let primaryLabelKey: String
    public let primaryEnabled: Bool
    public let accessibilitySummary: String

    public init(
        toolName: String,
        healthStatus: HealthStatus,
        localSummary: String,
        latestSummary: String,
        sourceLabel: String,
        conflictCount: Int,
        primaryAction: ToolPrimaryAction,
        primaryLabelKey: String,
        primaryEnabled: Bool,
        accessibilitySummary: String
    ) {
        self.toolName = toolName
        self.healthStatus = healthStatus
        self.localSummary = localSummary
        self.latestSummary = latestSummary
        self.sourceLabel = sourceLabel
        self.conflictCount = conflictCount
        self.primaryAction = primaryAction
        self.primaryLabelKey = primaryLabelKey
        self.primaryEnabled = primaryEnabled
        self.accessibilitySummary = accessibilitySummary
    }

    public static func make(
        tool: Tool,
        presentation: ToolPresentation,
        probeState: Loadable<InstallationProbe>?,
        latestState: Loadable<LatestVersionRecord>?,
        report: ToolInstallationReport?
    ) -> AgentEnvironmentCardModel {
        let localSummary = Self.localSummary(presentation: presentation, probeState: probeState)
        let latestSummary = Self.latestSummary(presentation: presentation, latestState: latestState)
        let source = report?.installations.first(where: \.isPreferred)?.source
            ?? report?.installations.first?.source
        let sourceLabel = source.map { "tool.installSource.\($0.rawValue)" } ?? "tool.installSource.unknown"
        let conflictCount = report?.isConflict == true ? max(report?.installations.count ?? 0, 2) : 0
        let summary = "\(tool.name). \(localSummary). \(latestSummary)"
        return AgentEnvironmentCardModel(
            toolName: tool.name,
            healthStatus: Self.health(from: presentation),
            localSummary: localSummary,
            latestSummary: latestSummary,
            sourceLabel: sourceLabel,
            conflictCount: conflictCount,
            primaryAction: presentation.primaryAction,
            primaryLabelKey: presentation.primaryLabelKey,
            primaryEnabled: presentation.primaryEnabled,
            accessibilitySummary: summary
        )
    }

    private static func health(from presentation: ToolPresentation) -> HealthStatus {
        switch presentation.status {
        case .installedCurrent, .localAhead: return .installed
        case .updateAvailable: return .outdated
        case .broken, .operationFailed: return .broken
        case .notInstalled, .sourceUnavailable: return .notInstalled
        default: return .notInstalled
        }
    }

    private static func localSummary(
        presentation: ToolPresentation,
        probeState: Loadable<InstallationProbe>?
    ) -> String {
        if case .loading = probeState { return "tool.probe.checking" }
        switch presentation.status {
        case .notInstalled, .sourceUnavailable:
            return "tool.status.notInstalled"
        case .broken:
            return "tool.probe.installedButBroken"
        case .localAhead(let local, _):
            return local
        case .installedCurrent(let local, _), .updateAvailable(let local, _):
            return local
        default:
            if case .known(let local) = presentation.localDisplay { return local }
            return "tool.status.unconfirmed"
        }
    }

    private static func latestSummary(
        presentation: ToolPresentation,
        latestState: Loadable<LatestVersionRecord>?
    ) -> String {
        if case .failed = latestState { return "tool.latest.networkUnavailable" }
        if case .loading = latestState { return "tool.probe.checking" }
        switch presentation.latestDisplay {
        case .known(let version):
            return version
        case .unavailable:
            return "tool.latest.networkUnavailable"
        case .notQueried:
            return "tool.probe.checking"
        }
    }
}
