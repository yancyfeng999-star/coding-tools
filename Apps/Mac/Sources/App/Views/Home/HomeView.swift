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
                VStack(alignment: .leading, spacing: 28) {
                    header

                    if let snapshot = state.catalogSnapshot {
                        summaryStats(snapshot: snapshot)
                    }

                    discoveredConfigsSection

                    updatesSection
                    recentSection
                    recommendedSection
                }
                .padding(24)
            }
            .navigationTitle("home.title")
            .refreshable {
                await state.refreshCatalog()
                state.checkForUpdates()
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

    // MARK: - Discovered AI CLI configs

    @ViewBuilder
    private var discoveredConfigsSection: some View {
        let configs = Array(state.discoveredConfigs.prefix(6))
        if configs.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(.purple)
                    Text("home.section.discoveredConfigs")
                        .font(.headline)
                    Spacer()
                    Text("(\(state.discoveredConfigs.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 10)
                ], spacing: 10) {
                    ForEach(configs) { cfg in
                        DiscoveredConfigRow(config: cfg)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func summaryStats(snapshot: Domain.CatalogSnapshot) -> some View {
        HStack(spacing: 12) {
            // P0-G4-3 修复：title 改为 LocalizedStringKey 以走本地化查找
            StatCard(titleKey: "home.stats.tools", value: "\(snapshot.tools.count)", icon: "shippingbox.fill", color: .blue)
            StatCard(titleKey: "home.stats.favorites", value: "\(state.favorites.count)", icon: "star.fill", color: .yellow)
            StatCard(titleKey: "home.stats.recent", value: "\(state.recent.count)", icon: "clock.fill", color: .green)
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

    // MARK: - Updates section (Sparkle-driven)

    @ViewBuilder
    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("home.section.updates")
                    .font(.headline)
                Spacer()
                if case .downloading(let progress, _, _) = state.updateState {
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.blue)
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
                    tint: .blue,
                    icon: "arrow.down.circle.fill"
                )
            case .failed(let reason, _):
                UpdateFailedCard(reason: reason) {
                    state.checkForUpdates()
                }
            case .upToDate, .installed:
                Text("home.update.upToDate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .idle, .checking, .extracting:
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
    let color: Color

    init(titleKey: LocalizedStringKey, value: String, icon: String, color: Color) {
        self.titleKey = titleKey
        self.value = value
        self.icon = icon
        self.color = color
    }

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
                Text(titleKey)
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
                // P0-G4-2 修复：用 state.probe 真实状态
                HealthBadge(status: state.probe(for: tool.id)?.healthStatus ?? .notInstalled)
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
                    .font(.title)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isDownloading
                         ? "home.update.downloading \(Int(progress * 100))"
                         : "home.update.available \(remoteVersion)")
                        .font(.headline)
                    if !isDownloading, remoteBuild > 0 {
                        Text("v\(remoteVersion) (\(remoteBuild))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if !isDownloading, size > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
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
                    .tint(.blue)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }
}

struct UpdateReadyCard: View {
    let remoteVersion: String
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("home.update.readyToInstall \(remoteVersion)")
                    .font(.headline)
            }
            Spacer()
            Button("home.update.installNow", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
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
                .font(.title)
                .foregroundStyle(tint)
            Text(titleKey)
                .font(.headline)
            Spacer()
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct UpdateFailedCard: View {
    let reason: String
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text("home.update.failed")
                    .font(.headline)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("home.update.retry", action: onRetry)
                .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .font(.title3)
                .foregroundStyle(.purple)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(toolDisplayName(config.toolID))
                    .font(.subheadline)
                    .lineLimit(1)
                // P0-G3-3 修复：路径脱敏为 /Users/***/last2
                Text(redactedPath(config.configPath.path))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    if let model = config.model {
                        Text(model)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if config.hasAPIKey {
                        Image(systemName: "key.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
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
            Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
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
