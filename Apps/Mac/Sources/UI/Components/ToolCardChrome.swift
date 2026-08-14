import SwiftUI
import Domain
import Theme

// MARK: - ToolCardChrome
//
// 克制表面：内容底、1px 语义边框、悬停仅改边框/浅底。无渐变、无重阴影、无缩放。

public struct ToolCardChrome: ViewModifier {
    public let status: HealthStatus
    public let isHovering: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        let increaseContrast = contrast == .increased
        content
            .padding(DesignTokens.Space.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isHovering ? DesignTokens.Palette.hoverSurface : DesignTokens.Palette.contentBackground,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .stroke(
                        DesignTokens.Palette.border(increaseContrast: increaseContrast || isHovering),
                        lineWidth: DesignTokens.Palette.borderWidth(increaseContrast: increaseContrast)
                    )
            )
            .animation(DesignTokens.animation(reduceMotion: reduceMotion), value: isHovering)
    }
}

public extension View {
    func toolCardChrome(status: HealthStatus, isHovering: Bool) -> some View {
        modifier(ToolCardChrome(status: status, isHovering: isHovering))
    }
}

public struct ToolCardActionTray<Content: View>: View {
    public let isHovering: Bool
    @ViewBuilder public let content: () -> Content

    public init(isHovering: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isHovering = isHovering
        self.content = content
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Space.space2) {
            content()
        }
        .opacity(1)
        .onAppear { _ = isHovering }
    }
}
