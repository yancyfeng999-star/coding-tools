import SwiftUI
import Domain
import Theme

/// Category hue for small icons only. Uses design tokens, not ad-hoc `.blue` / `.orange`.
public enum CategoryTint {
    public static func color(for category: ToolCategory) -> Color {
        switch category {
        case .editor, .languageRuntime:
            return DesignTokens.Palette.accent
        case .terminal, .devops, .cliUtility:
            return DesignTokens.Palette.secondaryText
        case .gitCollaboration:
            return DesignTokens.Palette.warning
        case .node, .backend:
            return DesignTokens.Palette.success
        case .python, .go, .docker, .database, .apiDebug:
            return DesignTokens.Palette.accent
        case .rust:
            return DesignTokens.Palette.secondaryText
        case .java:
            return DesignTokens.Palette.danger
        case .aiCoding, .frontend:
            return DesignTokens.Palette.warning
        }
    }

    public static func color(toolID: String?, category: ToolCategory?) -> Color {
        if let category {
            return color(for: category)
        }
        switch toolID {
        case "git": return color(for: .gitCollaboration)
        case "nodejs": return color(for: .node)
        case "python": return color(for: .python)
        case "go": return color(for: .go)
        case "rust": return color(for: .rust)
        case "docker-desktop": return color(for: .docker)
        case "iterm2": return color(for: .terminal)
        default: return DesignTokens.Palette.secondaryText
        }
    }
}
