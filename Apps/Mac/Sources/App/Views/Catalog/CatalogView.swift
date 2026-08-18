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
        .task {
            let ids = Set(state.tools.compactMap { tool -> String? in
                guard !AppState.agentToolIDs.contains(tool.id) else { return nil }
                guard state.probes[tool.id] == nil else { return nil }
                return tool.id
            })
            if !ids.isEmpty {
                await state.refreshProbes(toolIDs: ids)
            }
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
                        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: DesignTokens.Space.space4)
                    ], spacing: DesignTokens.Space.space4) {
                        ForEach(filtered) { tool in
                            ToolCard(tool: tool)
                                .onTapGesture {
                                    state.selectedTool = tool
                                }
                        }
                    }
                    .padding(DesignTokens.Space.space5)
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

    private var presentation: ToolPresentation { state.presentation(for: tool) }
    private var health: HealthStatus { state.probe(for: tool.id)?.healthStatus ?? .notInstalled }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
            HStack(alignment: .top) {
                ToolIconView(toolID: tool.id, category: tool.category, size: 40)
                Spacer()
                Button {
                    state.toggleFavorite(tool.id)
                } label: {
                    Image(systemName: state.isFavorite(tool.id) ? "star.fill" : "star")
                        .foregroundStyle(state.isFavorite(tool.id) ? DesignTokens.Palette.warning : DesignTokens.Palette.secondaryText)
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey(state.isFavorite(tool.id) ? "tool.unfavorite" : "tool.favorite"))
                .accessibilityLabel(Text(state.isFavorite(tool.id) ? "tool.unfavorite" : "tool.favorite"))
            }
            Text(tool.name)
                .tokenFont(.itemTitle)
                .foregroundStyle(DesignTokens.Palette.primaryText)
                .lineLimit(1)
            HStack(spacing: DesignTokens.Space.space2) {
                Text(tool.id)
                    .tokenFont(.compactCode)
                    .foregroundStyle(DesignTokens.Palette.tertiaryText)
                Spacer()
                CategoryLabel(category: tool.category)
                    .tokenFont(.tinyMetadata)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
            }
            statusRow
            primaryRow
        }
        .toolCardChrome(status: health, isHovering: isHovering)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(tool.name))
        .accessibilityValue(Text(presentation.accessibilitySummary))
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: DesignTokens.Space.space2) {
            presentation.badge
            versionCaption
            Spacer()
        }
    }

    @ViewBuilder
    private var versionCaption: some View {
        switch presentation.localDisplay {
        case .known(let local):
            Text("v\(local)")
                .tokenFont(.compactCode)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
                .monospacedDigit()
        case .unreadable:
            Text("tool.local.unreadable")
                .tokenFont(.tinyMetadata)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
        case .none:
            EmptyView()
        }
        switch presentation.latestDisplay {
        case .known(let latest):
            if presentation.showsUpdateAction {
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Palette.tertiaryText)
                    .accessibilityHidden(true)
                Text("v\(latest)")
                    .tokenFont(.compactCode)
                    .foregroundStyle(DesignTokens.Palette.warning)
                    .monospacedDigit()
            }
        case .notQueried, .unavailable:
            EmptyView()
        }
    }

    @ViewBuilder
    private var primaryRow: some View {
        HStack(spacing: DesignTokens.Space.space2) {
            Button {
                performPrimary()
            } label: {
                HStack(spacing: DesignTokens.Space.space1) {
                    Image(systemName: presentation.primarySystemImage)
                    Text(primaryTitle)
                }
                .tokenFont(.metadata)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Space.space2)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!presentation.primaryEnabled)
            .accessibilityLabel(Text(LocalizedStringKey(presentation.primaryLabelKey)))

            Button {
                state.selectedTool = tool
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.bordered)
            .help("tool.detail")
            .accessibilityLabel(Text("tool.detail"))
        }
    }

    private var primaryTitle: LocalizedStringKey {
        switch presentation.primaryAction {
        case .update(let version):
            return "catalog.card.updateTo \(version)"
        default:
            return LocalizedStringKey(presentation.primaryLabelKey)
        }
    }

    private func performPrimary() {
        switch presentation.primaryAction {
        case .install, .update, .repair, .reinstall, .retry:
            guard InstallConfirmation.resolvedOption(tool: tool) != nil else { return }
            state.installingTool = tool
        case .refresh:
            Task { await state.refreshProbe(toolID: tool.id) }
        case .open:
            state.launch(tool)
        case .unavailable, .none:
            break
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
    CategoryTint.color(for: category)
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
