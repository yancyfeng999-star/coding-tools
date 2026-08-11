import SwiftUI
import Domain

// MARK: - ToolCardChrome
//
// ToolCard 状态视觉规范：边框色 + 渐变 overlay + 内边距。
// 参考 cc-switch (farion1231/cc-switch) 的 ProviderCard 设计。
//
// 4 个状态对应 4 种 chrome：
//   .notInstalled  蓝（默认，未装）
//   .installed    灰（已装，up to date）
//   .outdated      橙（已装，有新版）
//   .broken        红（已装但 binary 坏）
//   .installing    蓝 + 转圈

public struct ToolCardChrome: ViewModifier {
    public let status: HealthStatus
    public let isHovering: Bool

    public func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: isHovering ? 1.5 : 1)
            )
            .overlay(alignment: .topLeading) {
                // 微弱渐变高亮
                LinearGradient(
                    colors: [chromeColor.opacity(isHovering ? 0.08 : 0.04), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(maxWidth: .infinity, maxHeight: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(isHovering ? 0.10 : 0.0),
                    radius: isHovering ? 8 : 0, y: 3)
    }

    private var borderColor: Color {
        if isHovering { return chromeColor.opacity(0.6) }
        return Color.primary.opacity(0.06)
    }

    private var chromeColor: Color {
        switch status {
        case .notInstalled: return .blue
        case .installed:    return .green
        case .outdated:     return .orange
        case .broken:       return .red
        }
    }
}

public extension View {
    func toolCardChrome(status: HealthStatus, isHovering: Bool) -> some View {
        modifier(ToolCardChrome(status: status, isHovering: isHovering))
    }
}

// MARK: - ActionTray
//
// 工具卡片右侧按钮组：默认 opacity 0，hover/focus-within 显示。
// 工具：Favorite + Install/Update/Reinstall + 详情箭头。

public struct ToolCardActionTray<Content: View>: View {
    public let isHovering: Bool
    @ViewBuilder public let content: () -> Content

    public init(isHovering: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isHovering = isHovering
        self.content = content
    }

    public var body: some View {
        HStack(spacing: 6) {
            content()
        }
        .opacity(isHovering ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}
