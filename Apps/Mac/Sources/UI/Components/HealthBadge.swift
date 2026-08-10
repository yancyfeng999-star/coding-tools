import SwiftUI
import Domain

/// 健康状态徽标。
public struct HealthBadge: View {
    public let status: HealthStatus

    public init(status: HealthStatus) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.caption2)
            Text(labelKey)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule(style: .continuous))
        .foregroundStyle(color)
    }

    private var symbolName: String {
        switch status {
        case .installed: return "checkmark.circle.fill"
        case .outdated: return "arrow.up.circle.fill"
        case .broken: return "xmark.octagon.fill"
        case .notInstalled: return "circle"
        }
    }

    private var color: Color {
        switch status {
        case .installed: return .green
        case .outdated: return .orange
        case .broken: return .red
        case .notInstalled: return .secondary
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
