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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ToolIconView(toolID: tool.id, category: tool.category, size: 44)
                Spacer()
                Button {
                    state.toggleFavorite(tool.id)
                } label: {
                    Image(systemName: state.isFavorite(tool.id) ? "star.fill" : "star")
                        .foregroundStyle(state.isFavorite(tool.id) ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }
            Text(tool.name)
                .font(.headline)
            CategoryLabel(category: tool.category)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                HealthBadge(status: .notInstalled)
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
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
