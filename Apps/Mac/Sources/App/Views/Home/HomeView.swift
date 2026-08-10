import SwiftUI
import Localization
import Theme
import UI
import Domain

/// 首页：欢迎语 + 推荐 + 最近使用 + 可更新。
struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    if let snapshot = state.catalogSnapshot {
                        summaryStats(snapshot: snapshot)
                    }

                    section(titleKey: "home.section.recent",
                            items: state.recentTools(),
                            emptyKey: "home.empty.recent")

                    section(titleKey: "home.section.recommended",
                            items: recommended,
                            emptyKey: "home.empty.recommended")

                    section(titleKey: "home.section.updates",
                            items: state.tools.prefix(2).map { $0 },  // 占位
                            emptyKey: "home.empty.updates")
                }
                .padding(24)
            }
            .navigationTitle("home.title")
            .refreshable {
                await state.refreshCatalog()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("home.subtitle")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func summaryStats(snapshot: Domain.CatalogSnapshot) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "工具", value: "\(snapshot.tools.count)", icon: "shippingbox.fill", color: .blue)
            StatCard(title: "已收藏", value: "\(state.favorites.count)", icon: "star.fill", color: .yellow)
            StatCard(title: "最近", value: "\(state.recent.count)", icon: "clock.fill", color: .green)
        }
    }

    @ViewBuilder
    private func section(titleKey: LocalizedStringKey, items: [Tool], emptyKey: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(titleKey)
                    .font(.headline)
                Spacer()
                if !items.isEmpty {
                    Text("(\(items.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if items.isEmpty {
                Text(emptyKey)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { tool in
                            HomeToolCard(tool: tool)
                                .frame(width: 220)
                                .onTapGesture {
                                    state.selectedTool = tool
                                    appModel.selectedTab = .catalog
                                }
                        }
                    }
                }
            }
        }
    }

    private var recommended: [Tool] {
        // 占位：取 4 个
        Array(state.tools.prefix(4))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct HomeToolCard: View {
    let tool: Tool
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ToolIconView(toolID: tool.id, category: tool.category, size: 40)
                Spacer()
                HealthBadge(status: .notInstalled)
            }
            Text(tool.name)
                .font(.headline)
            CategoryLabel(category: tool.category)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

func categoryKey(_ category: ToolCategory) -> String {
    switch category {
    case .editor: return "editor"
    case .terminal: return "terminal"
    case .gitCollaboration: return "git"
    case .node: return "node"
    case .python: return "python"
    case .go: return "go"
    case .rust: return "rust"
    case .java: return "java"
    case .database: return "database"
    case .apiDebug: return "apiDebug"
    case .docker: return "docker"
    case .aiCoding: return "aiCoding"
    case .frontend: return "frontend"
    case .backend: return "backend"
    case .devops: return "devops"
    case .cliUtility: return "cliUtility"
    case .languageRuntime: return "languageRuntime"
    }
}
