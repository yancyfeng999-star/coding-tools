import SwiftUI
import Domain

/// 风险等级徽标。
public struct RiskBadge: View {
    public let level: RiskLevel

    public init(level: RiskLevel) {
        self.level = level
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text(labelKey)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule(style: .continuous))
        .foregroundStyle(color)
    }

    private var color: Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var labelKey: LocalizedStringKey {
        switch level {
        case .low: return "tool.risk.low"
        case .medium: return "tool.risk.medium"
        case .high: return "tool.risk.high"
        }
    }
}
