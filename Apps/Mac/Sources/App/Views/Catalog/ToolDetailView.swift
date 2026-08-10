import SwiftUI
import Localization
import Theme
import UI
import Domain
import Launching
import Content

/// 工具详情页：简介 + 安装方式 + 风险 + 启动 + 教程。
struct ToolDetailView: View {
    let tool: Tool
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    section(titleKey: "tool.section.about") {
                        Text("工具：\(tool.name) · ID：\(tool.id)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    section(titleKey: "tool.section.install") {
                        VStack(alignment: .leading, spacing: 10) {
                            // 占位：阶段 3 接入后由 InstallAdapter.plan() 提供
                            installOptionRow(type: "homebrew-formula", description: "brew install \(tool.slug)")
                            installOptionRow(type: "mise-tool", description: "mise use \(tool.slug)@latest")
                        }
                    }

                    section(titleKey: "tool.section.tutorials") {
                        let items = state.contentFor(toolID: tool.id)
                        if items.isEmpty {
                            Text("content.empty.description")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(items) { item in
                                    ContentLinkRow(item: item)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .frame(minWidth: 540, minHeight: 540)
            .navigationTitle(tool.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                // 收藏 + 安装合并到 ToolbarItemGroup，避免窗口太窄时被裁掉。
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        state.toggleFavorite(tool.id)
                    } label: {
                        Image(systemName: state.isFavorite(tool.id) ? "star.fill" : "star")
                    }
                    .help(LocalizedStringKey(state.isFavorite(tool.id) ? "tool.unfavorite" : "tool.favorite"))

                    Button {
                        state.installingTool = tool
                    } label: {
                        // 用 Image + Text 而非 Label，缩短 toolbar 宽度
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("tool.install")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("i", modifiers: [.command])
                }
            }
        }
        .sheet(item: $state.installingTool) { installing in
            InstallSheet(tool: installing)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ToolIconView(toolID: tool.id, category: tool.category, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                Text(tool.name)
                    .font(.title.bold())
                HStack(spacing: 8) {
                    HealthBadge(status: .notInstalled)
                    RiskBadge(level: .low)
                    Text("category.\(categoryKey(tool.category))")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15), in: Capsule(style: .continuous))
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func section<Content: View>(titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titleKey)
                .font(.headline)
            content()
        }
    }

    private func installOptionRow(type: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(type)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(description)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ContentLinkRow: View {
    let item: ContentItem

    var body: some View {
        Button {
            // 只允许 https 链接；阶段 3 接入 MacLauncher.launch(.url) 后替换。
            if item.sourceURL.scheme == "https" {
                NSWorkspace.shared.open(item.sourceURL)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: typeIcon)
                    .foregroundStyle(typeColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                    if let author = item.author {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var typeIcon: String {
        switch item.type {
        case .article: return "doc.text"
        case .video: return "play.rectangle"
        case .docs: return "book.closed"
        case .rss: return "dot.radiowaves.left.and.right"
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .article: return .blue
        case .video: return .red
        case .docs: return .green
        case .rss: return .orange
        }
    }
}
