import SwiftUI
import Localization
import Theme
import UI
import Domain
import AIConfigDiscovery
import Updates
import ProcessExecution

/// 首页：欢迎语 + 推荐 + 最近使用 + 可更新（接 Sparkle）。
struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.space6) {
                    header

                    if let snapshot = state.catalogSnapshot {
                        summaryStats(snapshot: snapshot)
                    }

                    discoveredConfigsSection

                    updatesSection
                    recentSection
                    recommendedSection
                }
                .padding(DesignTokens.Space.space6)
            }
            .background(DesignTokens.Palette.appBackground)
            .navigationTitle("home.title")
            .refreshable {
                await state.refreshCatalog()
                state.checkForUpdates()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space2) {
            Text("home.subtitle")
                .tokenFont(.supporting)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
        }
    }

    // MARK: - Discovered AI CLI configs

    @ViewBuilder
    private var discoveredConfigsSection: some View {
        let configs = Array(state.discoveredConfigs.prefix(6))
        if configs.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
                HStack {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(DesignTokens.Palette.accent)
                    Text("home.section.discoveredConfigs")
                        .tokenFont(.sectionTitle)
                    Spacer()
                    Text("(\(state.discoveredConfigs.count))")
                        .tokenFont(.tinyMetadata)
                        .foregroundStyle(DesignTokens.Palette.secondaryText)
                }
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 220, maximum: 320), spacing: DesignTokens.Space.space3)
                ], spacing: DesignTokens.Space.space3) {
                    ForEach(configs) { cfg in
                        DiscoveredConfigRow(config: cfg)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func summaryStats(snapshot: Domain.CatalogSnapshot) -> some View {
        HStack(spacing: DesignTokens.Space.space3) {
            // P0-G4-3 修复：title 改为 LocalizedStringKey 以走本地化查找
            StatCard(titleKey: "home.stats.tools", value: "\(snapshot.tools.count)", icon: "shippingbox.fill")
            StatCard(titleKey: "home.stats.favorites", value: "\(state.favorites.count)", icon: "star.fill")
            StatCard(titleKey: "home.stats.recent", value: "\(state.recent.count)", icon: "clock.fill")
        }
    }

    @ViewBuilder
    private func section(titleKey: LocalizedStringKey, items: [Tool], emptyKey: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
            HStack {
                Text(titleKey)
                    .tokenFont(.sectionTitle)
                Spacer()
                if !items.isEmpty {
                    Text("(\(items.count))")
                        .tokenFont(.tinyMetadata)
                        .foregroundStyle(DesignTokens.Palette.secondaryText)
                }
            }
            if items.isEmpty {
                Text(emptyKey)
                    .tokenFont(.supporting)
                    .foregroundStyle(DesignTokens.Palette.tertiaryText)
                    .padding(.vertical, DesignTokens.Space.space2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Space.space4) {
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

    // MARK: - Updates section (Sparkle-driven)

    @ViewBuilder
    private var updatesSection: some View {
        switch state.updateState {
        case .idle, .checking, .upToDate, .installed, .extracting:
            EmptyView()
        default:
            compactAppUpdate
        }
    }

    @ViewBuilder
    private var compactAppUpdate: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
            HStack {
                Text("home.section.appUpdates")
                    .tokenFont(.sectionTitle)
                Spacer()
                if case .downloading(let progress, _, _) = state.updateState {
                    Text("\(Int(progress * 100))%")
                        .tokenFont(.compactCode)
                        .foregroundStyle(DesignTokens.Palette.accent)
                }
            }
            switch state.updateState {
            case .available(let remote, let build, let size):
                UpdateAvailableCard(
                    remoteVersion: remote,
                    remoteBuild: build,
                    size: size,
                    isDownloading: false,
                    progress: 0,
                    onInstall: { state.checkForUpdates() }
                )
            case .downloading(let progress, _, _):
                UpdateAvailableCard(
                    remoteVersion: state.remoteVersionFromAvailable ?? "",
                    remoteBuild: 0,
                    size: 0,
                    isDownloading: true,
                    progress: progress,
                    onInstall: { state.cancelUpdate() }
                )
            case .readyToInstall(let remote):
                UpdateReadyCard(remoteVersion: remote) {
                    appModel.selectedTab = .settings
                }
            case .installing:
                UpdateProgressCard(
                    titleKey: "home.update.installing",
                    progress: 1.0,
                    tint: DesignTokens.Palette.accent,
                    icon: "arrow.down.circle.fill"
                )
            case .failed(let reason, _):
                UpdateFailedCard(reason: reason) {
                    state.checkForUpdates()
                }
            default:
                EmptyView()
            }
        }
    }

    private var recentSection: some View {
        section(titleKey: "home.section.recent",
                items: state.recentTools(),
                emptyKey: "home.empty.recent")
    }

    private var recommendedSection: some View {
        section(titleKey: "home.section.recommended",
                items: recommended,
                emptyKey: "home.empty.recommended")
    }

    private var recommended: [Tool] {
        // 占位：取 4 个
        Array(state.tools.prefix(4))
    }
}

private struct StatCard: View {
    let titleKey: LocalizedStringKey
    let value: String
    let icon: String

    init(titleKey: LocalizedStringKey, value: String, icon: String) {
        self.titleKey = titleKey
        self.value = value
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .tokenFont(.sectionTitle)
                .foregroundStyle(DesignTokens.Palette.accent)
                .frame(width: 32, height: 32)
                .background(DesignTokens.Palette.selectedSurface, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .tokenFont(.pageTitle)
                Text(titleKey)
                    .tokenFont(.tinyMetadata)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
            }
        }
        .padding(12)
        .background(DesignTokens.Palette.contentBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
                .stroke(DesignTokens.Palette.subtleBorder, lineWidth: 1)
        )
    }
}

private struct HomeToolCard: View {
    let tool: Tool
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
            HStack(alignment: .top) {
                ToolIconView(toolID: tool.id, category: tool.category, size: 40)
                Spacer()
                state.presentation(for: tool).badge
            }
            Text(tool.name)
                .tokenFont(.itemTitle)
            CategoryLabel(category: tool.category)
                .tokenFont(.tinyMetadata)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
        }
        .padding(DesignTokens.Space.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Palette.contentBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .stroke(DesignTokens.Palette.subtleBorder, lineWidth: 1)
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

// MARK: - Update cards (Sparkle-driven, used in Home "可更新" section)

struct UpdateAvailableCard: View {
    let remoteVersion: String
    let remoteBuild: Int
    let size: Int64
    let isDownloading: Bool
    let progress: Double
    let onInstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: isDownloading ? "arrow.down.circle" : "arrow.down.circle.fill")
                    .tokenFont(.pageTitle)
                    .foregroundStyle(DesignTokens.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isDownloading
                         ? "home.update.downloading \(Int(progress * 100))"
                         : "home.update.available \(remoteVersion)")
                        .tokenFont(.sectionTitle)
                    if !isDownloading, remoteBuild > 0 {
                        Text("v\(remoteVersion) (\(remoteBuild))")
                            .tokenFont(.compactCode)
                            .foregroundStyle(DesignTokens.Palette.secondaryText)
                    }
                    if !isDownloading, size > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .tokenFont(.compactCode)
                            .foregroundStyle(DesignTokens.Palette.secondaryText)
                    }
                }
                Spacer()
                if !isDownloading {
                    Button("home.update.installNow", action: onInstall)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            if isDownloading {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(DesignTokens.Palette.accent)
            }
        }
        .padding(DesignTokens.Space.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Palette.selectedSurface, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
                .stroke(DesignTokens.Palette.subtleBorder, lineWidth: 1)
        )
    }
}

struct UpdateReadyCard: View {
    let remoteVersion: String
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "arrow.up.circle.fill")
                .tokenFont(.pageTitle)
                .foregroundStyle(DesignTokens.Palette.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("home.update.readyToInstall \(remoteVersion)")
                    .tokenFont(.sectionTitle)
            }
            Spacer()
            Button("home.update.installNow", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(DesignTokens.Space.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Palette.contentBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
                .stroke(DesignTokens.Palette.subtleBorder, lineWidth: 1)
        )
    }
}

struct UpdateProgressCard: View {
    let titleKey: LocalizedStringKey
    let progress: Double
    let tint: Color
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .tokenFont(.pageTitle)
                .foregroundStyle(DesignTokens.Palette.accent)
            Text(titleKey)
                .tokenFont(.sectionTitle)
            Spacer()
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .controlSize(.small)
        }
        .padding(DesignTokens.Space.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous))
    }
}

struct UpdateFailedCard: View {
    let reason: String
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .tokenFont(.pageTitle)
                .foregroundStyle(DesignTokens.Palette.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("home.update.failed")
                    .tokenFont(.sectionTitle)
                Text(reason)
                    .tokenFont(.tinyMetadata)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button("home.update.retry", action: onRetry)
                .controlSize(.small)
        }
        .padding(DesignTokens.Space.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Palette.contentBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous))
    }
}

// MARK: - DiscoveredConfigRow
//
// 显示用户 home 里扫到的 AI CLI 配置文件：
// tool 名 · 路径截断 · model · "已收藏" toggle

private struct DiscoveredConfigRow: View {
    let config: AIConfig
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: toolIcon(for: config.toolID))
                .tokenFont(.sectionTitle)
                .foregroundStyle(DesignTokens.Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(toolDisplayName(config.toolID))
                    .tokenFont(.supporting)
                    .lineLimit(1)
                Text(redactedPath(config.configPath.path))
                    .tokenFont(.compactCode)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    if let model = config.model {
                        Text(model)
                            .tokenFont(.tinyMetadata)
                            .foregroundStyle(DesignTokens.Palette.tertiaryText)
                    }
                    if config.hasAPIKey {
                        Image(systemName: "key.fill")
                            .tokenFont(.tinyMetadata)
                            .foregroundStyle(DesignTokens.Palette.success)
                            .help("home.discovered.hasKey")
                    }
                }
            }
            Spacer()
            Button {
                state.adoptDiscoveredConfig(config)
            } label: {
                Image(systemName: state.favorites.contains(config.toolID) ? "star.fill" : "star")
                    .foregroundStyle(state.favorites.contains(config.toolID) ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            DesignTokens.Palette.hoverSurface,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
        )
    }

    private func redactedPath(_ path: String) -> String {
        OutputRedactor.redactPath(path, keepLastSegments: 2)
    }
}

private func toolIcon(for toolID: String) -> String {
    switch toolID {
    case "claude-code": return "sparkles"
    case "codex":      return "chevron.left.slash.chevron.right"
    case "gemini-cli":  return "sparkle"
    default:            return "terminal.fill"
    }
}

private func toolDisplayName(_ id: String) -> String {
    switch id {
    case "claude-code": return "Claude Code"
    case "codex":      return "Codex"
    case "gemini-cli":  return "Gemini CLI"
    case "opencode":    return "OpenCode"
    case "grok-build":  return "Grok Build"
    case "hermes":      return "Hermes"
    case "openclaw":    return "OpenClaw"
    default:            return id
    }
}
