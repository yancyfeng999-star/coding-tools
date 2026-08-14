import SwiftUI
import Localization
import Theme
import UI
import Domain
import Content

/// 教程 / 视频列表。
struct ContentView: View {
    @EnvironmentObject private var state: AppState

    @State private var typeFilter: ContentType? = nil

    var body: some View {
        NavigationStack {
            content
                .background(DesignTokens.Palette.appBackground)
                .navigationTitle("content.title")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Menu {
                            Button("catalog.filter.all") { typeFilter = nil }
                            Divider()
                            ForEach(ContentType.allCases, id: \.self) { type in
                                Button {
                                    typeFilter = type
                                } label: {
                                    Label {
                                        switch type {
                                        case .article: Text("content.type.article")
                                        case .video: Text("content.type.video")
                                        case .docs: Text("content.type.docs")
                                        case .rss: Text("content.type.rss")
                                        }
                                    } icon: {
                                        Image(systemName: icon(for: type))
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .refreshable {
                    await state.loadContentIfNeeded()
                }
        }
    }

    private var filteredItems: [ContentItem] {
        guard let type = typeFilter else { return state.contentItems }
        return state.contentItems.filter { $0.type == type }
    }

    @ViewBuilder
    private var content: some View {
        let items = filteredItems
        if items.isEmpty {
            ContentUnavailableView {
                Label("content.empty.title", systemImage: "book")
            } description: {
                Text("content.empty.description")
            }
        } else {
            List {
                ForEach(items) { item in
                    ContentRow(item: item)
                }
            }
        }
    }

    private func icon(for type: ContentType) -> String {
        switch type {
        case .article: return "doc.text"
        case .video: return "play.rectangle"
        case .docs: return "book.closed"
        case .rss: return "dot.radiowaves.left.and.right"
        }
    }
}

private struct ContentRow: View {
    let item: ContentItem

    var body: some View {
        Button {
            if item.sourceURL.scheme == "https" {
                NSWorkspace.shared.open(item.sourceURL)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(badgeColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: badgeIcon)
                        .foregroundStyle(badgeColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .tokenFont(.itemTitle)
                    if let author = item.author {
                        Text(author)
                            .tokenFont(.tinyMetadata)
                            .foregroundStyle(DesignTokens.Palette.secondaryText)
                    }
                    if let host = item.sourceURL.host {
                        HStack(spacing: DesignTokens.Space.space1) {
                            Image(systemName: "arrow.up.right.square")
                            Text(host)
                                .tokenFont(.tinyMetadata)
                        }
                        .foregroundStyle(DesignTokens.Palette.tertiaryText)
                        .accessibilityLabel(Text("content.externalLink"))
                    }
                    HStack(spacing: 6) {
                        typeBadge
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeColor.opacity(0.15), in: Capsule(style: .continuous))
                            .foregroundStyle(badgeColor)
                        if !item.tags.isEmpty {
                            Text(item.tags.prefix(3).joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var badgeColor: Color {
        switch item.type {
        case .article: return DesignTokens.Palette.accent
        case .video: return DesignTokens.Palette.danger
        case .docs: return DesignTokens.Palette.success
        case .rss: return DesignTokens.Palette.warning
        }
    }

    private var badgeIcon: String {
        switch item.type {
        case .article: return "doc.text"
        case .video: return "play.rectangle.fill"
        case .docs: return "book.closed.fill"
        case .rss: return "dot.radiowaves.left.and.right"
        }
    }

    @ViewBuilder
    private var typeBadge: some View {
        switch item.type {
        case .article: Text("content.type.article")
        case .video: Text("content.type.video")
        case .docs: Text("content.type.docs")
        case .rss: Text("content.type.rss")
        }
    }
}
