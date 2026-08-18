import SwiftUI
import Domain
import Theme

/// 健康状态徽标：图标 + 文案，不只靠颜色。
public struct HealthBadge: View {
    public let status: HealthStatus

    public init(status: HealthStatus) {
        self.status = status
    }

    public var body: some View {
        PresentationStatusBadge(statusKey: labelKey, symbolName: symbolName, tone: tone)
    }

    private var symbolName: String {
        switch status {
        case .installed: return "checkmark.circle.fill"
        case .outdated: return "arrow.up.circle.fill"
        case .broken: return "xmark.octagon.fill"
        case .notInstalled: return "circle"
        }
    }

    private var tone: PresentationStatusBadge.Tone {
        switch status {
        case .installed: return .success
        case .outdated: return .warning
        case .broken: return .danger
        case .notInstalled: return .neutral
        }
    }

    private var labelKey: LocalizedStringKey {
        switch status {
        case .installed: return "home.status.installed"
        case .outdated: return "home.status.outdated"
        case .broken: return "home.status.broken"
        case .notInstalled: return "home.status.notInstalled"
        }
    }
}

public struct PresentationStatusBadge: View {
    public enum Tone { case success, warning, danger, neutral, accent }

    public let statusKey: LocalizedStringKey
    public let symbolName: String
    public let tone: Tone

    public init(statusKey: LocalizedStringKey, symbolName: String, tone: Tone) {
        self.statusKey = statusKey
        self.symbolName = symbolName
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Space.space1) {
            Image(systemName: symbolName)
                .font(.caption2)
            Text(statusKey)
                .tokenFont(.tinyMetadata)
        }
        .padding(.horizontal, DesignTokens.Space.space2)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: Capsule(style: .continuous))
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(statusKey))
    }

    private var color: Color {
        switch tone {
        case .success: return DesignTokens.Palette.success
        case .warning: return DesignTokens.Palette.warning
        case .danger: return DesignTokens.Palette.danger
        case .neutral: return DesignTokens.Palette.secondaryText
        case .accent: return DesignTokens.Palette.accent
        }
    }
}

public extension ToolPresentation {
    var badge: some View {
        PresentationStatusBadge(
            statusKey: LocalizedStringKey(statusKey),
            symbolName: badgeSymbol,
            tone: badgeTone
        )
    }

    var badgeSymbol: String {
        switch status {
        case .checking: return "clock"
        case .notInstalled: return "circle"
        case .installedCurrent: return "checkmark.circle.fill"
        case .updateAvailable: return "arrow.up.circle.fill"
        case .broken: return "wrench.adjustable"
        case .versionUnknown: return "questionmark.circle"
        case .sourceUnavailable: return "slash.circle"
        case .operationRunning: return "arrow.triangle.2.circlepath"
        case .operationFailed: return "exclamationmark.triangle.fill"
        case .completedPendingConfirmation: return "checkmark.circle"
        }
    }

    var badgeTone: PresentationStatusBadge.Tone {
        switch status {
        case .installedCurrent: return .success
        case .updateAvailable, .completedPendingConfirmation: return .warning
        case .broken, .operationFailed: return .danger
        case .notInstalled, .checking, .versionUnknown, .sourceUnavailable, .operationRunning: return .neutral
        }
    }

    var primarySystemImage: String {
        switch primaryAction {
        case .install: return "arrow.down.to.line.compact"
        case .open: return "play.fill"
        case .update: return "arrow.up.circle.fill"
        case .reinstall: return "arrow.clockwise"
        case .repair: return "wrench.adjustable"
        case .refresh: return "arrow.clockwise"
        case .retry: return "arrow.counterclockwise"
        case .unavailable, .none: return "slash.circle"
        }
    }

    public var accessibilitySummary: String {
        var parts = [
            String(localized: String.LocalizationValue(statusKey)),
            String(localized: String.LocalizationValue(primaryLabelKey)),
        ]
        switch localDisplay {
        case .known(let version): parts.append(version)
        case .unreadable: parts.append(String(localized: "tool.local.unreadable"))
        case .none: break
        }
        return parts.joined(separator: ", ")
    }
}
