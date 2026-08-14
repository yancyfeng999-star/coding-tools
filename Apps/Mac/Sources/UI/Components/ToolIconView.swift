import SwiftUI
import Domain
import Theme

/// 通用工具图标：用 SF Symbol 暂代。真实 Logo 由 Catalog 阶段提供。
public struct ToolIconView: View {
    public let toolID: String?
    public let category: ToolCategory?
    public let size: CGFloat

    public init(toolID: String?, category: ToolCategory?, size: CGFloat = 48) {
        self.toolID = toolID
        self.category = category
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(backgroundColor)
                .frame(width: size, height: size)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var symbolName: String {
        switch toolID {
        case "git": return "arrow.triangle.branch"
        case "nodejs": return "n.circle.fill"
        case "python": return "chevron.left.forwardslash.chevron.right"
        case "go": return "hare.fill"
        case "rust": return "gearshape.2.fill"
        case "vscode": return "chevron.left.slash.chevron.right"
        case "docker-desktop": return "cube.box.fill"
        case "iterm2": return "terminal.fill"
        default:
            switch category {
            case .editor: return "chevron.left.slash.chevron.right"
            case .terminal: return "terminal.fill"
            case .gitCollaboration: return "arrow.triangle.branch"
            case .node, .python, .go, .rust, .java: return "chevron.left.forwardslash.chevron.right"
            case .database: return "cylinder.split.1x2"
            case .apiDebug: return "antenna.radiowaves.left.and.right"
            case .docker: return "cube.box.fill"
            case .aiCoding: return "sparkles"
            case .frontend: return "paintpalette.fill"
            case .backend: return "server.rack"
            case .devops: return "gearshape.2.fill"
            case .cliUtility: return "terminal.fill"
            case .languageRuntime: return "gearshape.fill"
            case nil: return "shippingbox.fill"
            }
        }
    }

    private var backgroundColor: Color {
        CategoryTint.color(toolID: toolID, category: category)
    }
}
