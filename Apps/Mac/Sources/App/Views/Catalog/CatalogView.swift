import SwiftUI
import Localization
import Theme
import UI
import Domain

/// 工具目录：分类侧栏 + 搜索 + 工具网格 + 收藏。
struct CatalogView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedCategory: ToolCategory? = nil
    @State private var showingFavoritesOnly = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationTitle("catalog.title")
        .searchable(text: $appModel.searchText, prompt: "catalog.search.placeholder")
        .sheet(item: $state.selectedTool) { tool in
            ToolDetailView(tool: tool)
        }
    }

    private var sidebar: some View {
        List {
            Section {
                Button {
                    selectedCategory = nil
                    showingFavoritesOnly = false
                } label: {
                    Label {
                        Text("catalog.filter.all")
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)

                Button {
                    selectedCategory = nil
                    showingFavoritesOnly = true
                } label: {
                    Label {
                        Text("tool.favorite")
                    } icon: {
                        Image(systemName: showingFavoritesOnly ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }

            Section {
                ForEach(ToolCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                        showingFavoritesOnly = false
                    } label: {
                        HStack {
                            Image(systemName: icon(for: category))
                                .frame(width: 18)
                                .foregroundStyle(color(for: category))
                            CategoryLabel(category: category)
                            Spacer()
                            Text("\(state.tools.filter { $0.category == category }.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }

    private var detail: some View {
        let filtered = filteredTools()
        return Group {
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label("catalog.empty.title", systemImage: "magnifyingglass")
                } description: {
                    Text("catalog.empty.description")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)
                    ], spacing: 14) {
                        ForEach(filtered) { tool in
                            ToolCard(tool: tool)
                                .onTapGesture {
                                    state.selectedTool = tool
                                }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private func filteredTools() -> [Tool] {
        var tools = state.tools
        if let cat = selectedCategory {
            tools = tools.filter { $0.category == cat }
        }
        if showingFavoritesOnly {
            tools = tools.filter { state.favorites.contains($0.id) }
        }
        if !appModel.searchText.isEmpty {
            let q = appModel.searchText.lowercased()
            tools = tools.filter { tool in
                tool.name.lowercased().contains(q) ||
                tool.id.lowercased().contains(q) ||
                tool.category.rawValue.lowercased().contains(q)
            }
        }
        return tools
    }
}

private struct ToolCard: View {
    let tool: Tool
    @EnvironmentObject private var state: AppState
    @State private var isHovering = false

    private var probe: InstallationProbe? { state.probe(for: tool.id) }
    private var health: HealthStatus { probe?.healthStatus ?? .notInstalled }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 头部：icon + name + hover-reveal action tray
            HStack(alignment: .top) {
                ToolIconView(toolID: tool.id, category: tool.category, size: 40)
                Spacer()
                ToolCardActionTray(isHovering: isHovering) {
                    Button {
                        state.toggleFavorite(tool.id)
                    } label: {
                        Image(systemName: state.isFavorite(tool.id) ? "star.fill" : "star")
                            .foregroundStyle(state.isFavorite(tool.id) ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("tool.favorite")
                }
            }
            Text(tool.name)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(tool.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                Spacer()
                RiskBadge(level: tool.riskLevel)
            }
            // 状态行：已安装 vX.Y.Z / 未安装 / 已过期 / 正在安装
            statusRow
            // compound footer（按 kind 分化）
            compoundFooter
        }
        .toolCardChrome(status: health, isHovering: isHovering)
        .scaleEffect(isHovering ? 1.015 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            state.selectedTool = tool
        }
    }

    // MARK: - 状态行

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 6) {
            if state.installingTool?.id == tool.id {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                Text("catalog.card.installing")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Spacer()
            } else {
                statusBadge
                Spacer()
            }
        }
    }

    /// 状态徽章：HealthBadge + 已安装版本号
    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            HealthBadge(status: health)
            if let v = probe?.installedVersion, !v.isEmpty {
                Text("v\(v)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Compound footer

    @ViewBuilder
    private var compoundFooter: some View {
        if state.installingTool?.id == tool.id {
            HStack {
                Spacer()
                Text("catalog.card.installing")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Spacer()
            }
            .padding(.vertical, 6)
        } else {
            HStack(spacing: 6) {
                Button {
                    state.installingTool = tool
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: buttonIcon)
                        Text(buttonTitle)
                    }
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(buttonTint)

                // 详情按钮（hover-reveal）
                if isHovering {
                    Button {
                        state.selectedTool = tool
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("tool.detail")
                }
            }
        }
    }

    private var buttonIcon: String {
        switch health {
        case .installed:    return "arrow.clockwise"
        case .outdated:     return "arrow.up.circle.fill"
        case .broken:       return "wrench.adjustable"
        case .notInstalled: return "arrow.down.to.line.compact"
        }
    }

    private var buttonTitle: LocalizedStringKey {
        switch health {
        case .installed:    return "catalog.card.reinstall"
        case .outdated:     return "catalog.card.update"
        case .broken:       return "catalog.card.repair"
        case .notInstalled: return "catalog.card.install"
        }
    }

    private var buttonTint: Color {
        switch health {
        case .installed:    return .secondary
        case .outdated:     return .orange
        case .broken:       return .red
        case .notInstalled: return .blue
        }
    }
}

func icon(for category: ToolCategory) -> String {
    switch category {
    case .editor: return "chevron.left.slash.chevron.right"
    case .terminal: return "terminal.fill"
    case .gitCollaboration: return "arrow.triangle.branch"
    case .node: return "n.circle"
    case .python: return "chevron.left.forwardslash.chevron.right"
    case .go: return "hare.fill"
    case .rust: return "gearshape.2.fill"
    case .java: return "cup.and.saucer.fill"
    case .database: return "cylinder.split.1x2"
    case .apiDebug: return "antenna.radiowaves.left.and.right"
    case .docker: return "cube.box.fill"
    case .aiCoding: return "sparkles"
    case .frontend: return "paintpalette.fill"
    case .backend: return "server.rack"
    case .devops: return "gearshape.2.fill"
    case .cliUtility: return "terminal.fill"
    case .languageRuntime: return "gearshape.fill"
    }
}

func color(for category: ToolCategory) -> Color {
    switch category {
    case .editor: return .indigo
    case .terminal: return .gray
    case .gitCollaboration: return .orange
    case .node: return .green
    case .python: return .blue
    case .go: return .cyan
    case .rust: return .brown
    case .java: return .red
    case .database: return .teal
    case .apiDebug: return .purple
    case .docker: return .blue
    case .aiCoding: return .pink
    case .frontend: return .pink
    case .backend: return .mint
    case .devops: return .gray
    case .cliUtility: return .secondary
    case .languageRuntime: return .indigo
    }
}

/// 共享的分类标签。**走 `LocalizedStringKey` 直接字面量**，避免
/// `Text("category.\(x)")` 这种字符串插值导致 SwiftUI 不做本地化查找。
struct CategoryLabel: View {
    let category: ToolCategory

    var body: some View {
        switch category {
        case .editor: Text("category.editor")
        case .terminal: Text("category.terminal")
        case .gitCollaboration: Text("category.git")
        case .node: Text("category.node")
        case .python: Text("category.python")
        case .go: Text("category.go")
        case .rust: Text("category.rust")
        case .java: Text("category.java")
        case .database: Text("category.database")
        case .apiDebug: Text("category.apiDebug")
        case .docker: Text("category.docker")
        case .aiCoding: Text("category.aiCoding")
        case .frontend: Text("category.frontend")
        case .backend: Text("category.backend")
        case .devops: Text("category.devops")
        case .cliUtility: Text("category.cliUtility")
        case .languageRuntime: Text("category.languageRuntime")
        }
    }
}
