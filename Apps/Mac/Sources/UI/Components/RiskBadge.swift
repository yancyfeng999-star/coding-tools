import SwiftUI
import Domain
import Theme

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
        .padding(.horizontal, DesignTokens.Space.space2)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule(style: .continuous))
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(labelKey))
    }

    private var color: Color {
        switch level {
        case .low: return DesignTokens.Palette.success
        case .medium: return DesignTokens.Palette.warning
        case .high: return DesignTokens.Palette.danger
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
