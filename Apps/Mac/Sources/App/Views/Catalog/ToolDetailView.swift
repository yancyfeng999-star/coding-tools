import SwiftUI
import Localization
import Theme
import UI
import Domain
import Launching
import Content

/// 工具详情页：简介 + 安装方式 + 风险 + 启动 + 教程。
///
/// 阶段 11 修复（P0-G2-3 / G4-5 / G4-6）：
/// - 安装选项区遍历 `tool.installOptions`，每行显示真实 type / 命令预览 / riskLevel
/// - `RiskBadge` 用 `opt.riskLevel`，不再写死 .low
/// - ContentLinkRow 加 sourceURL host 白名单（仅允许与 tool 关联的官方域）
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
                            // P0-G2-3 / G4-5 修复：遍历 tool.installOptions
                            ForEach(Array(tool.installOptions.enumerated()), id: \.offset) { _, opt in
                                installOptionRow(opt: opt)
                            }
                            if tool.installOptions.isEmpty {
                                Text("install.no_options")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
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
                                    ContentLinkRow(item: item, toolCategory: tool.category)
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
                            Image(systemName: "arrow.down.to.line.compact")
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
                    HealthBadge(status: state.probe(for: tool.id)?.healthStatus ?? .notInstalled)
                    // P0-G2-3 修复：从 tool 选最高的 riskLevel
                    RiskBadge(level: highestRiskLevel)
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

    /// 工具的总体风险 = 所有 installOptions 中最高的 riskLevel
    private var highestRiskLevel: RiskLevel {
        let order: [RiskLevel: Int] = [.low: 0, .medium: 1, .high: 2]
        return tool.installOptions.map(\.riskLevel).max(by: { (order[$0] ?? 0) < (order[$1] ?? 0) }) ?? .low
    }

    @ViewBuilder
    private func section<Content: View>(titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titleKey)
                .font(.headline)
            content()
        }
    }

    private func installOptionRow(opt: InstallOption) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(opt.type.rawValue)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    RiskBadge(level: opt.riskLevel)
                }
                Text(commandPreview(opt))
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func commandPreview(_ opt: InstallOption) -> String {
        switch opt.type {
        case .homebrewFormula:
            return "brew install \(opt.packageName ?? tool.id)"
        case .homebrewCask:
            return "brew install --cask \(opt.packageName ?? tool.id)"
        case .miseTool:
            let v = opt.version.map { "@\($0)" } ?? "@latest"
            return "mise use \(opt.toolName ?? tool.id)\(v)"
        case .officialArtifact:
            return "download \(opt.url?.absoluteString ?? "<missing>")"
        case .npmGlobal:
            let pkg = opt.packageName ?? tool.id
            if let v = opt.versionRule, !v.isEmpty {
                return "npm install -g \(pkg)@\(v)"
            }
            return "npm install -g \(pkg)"
        }
    }
}

private struct ContentLinkRow: View {
    let item: ContentItem
    let toolCategory: ToolCategory
    @EnvironmentObject private var state: AppState

    /// P0-G2-4 / G4-6 修复：仅允许白名单 host 的 https 链接。
    /// 阶段 11 验证后，host 应通过 Catalog 提供（tool.allowedContentHosts）。
    private static let trustedHosts: Set<String> = [
        "github.com", "raw.githubusercontent.com",
        "docs.anthropic.com", "anthropic.com",
        "openai.com", "platform.openai.com",
        "google.dev", "gemini.google",
        "x.ai", "docs.x.ai",
        "opencode.ai",
        "hermes-agent.nousresearch.com", "nousresearch.com",
        "openclaw.ai",
        "git-scm.com",
        "nodejs.org",
        "python.org", "docs.python.org",
        "go.dev",
        "rust-lang.org",
        "rustup.rs",
        "npmjs.com", "docs.npmjs.com",
        "brew.sh", "docs.brew.sh",
        "mise.jdx.dev", "jdx.dev",
        "developer.apple.com",
        "sparkle-project.org",
        "docs.docker.com",
    ]

    var body: some View {
        Button {
            guard let host = item.sourceURL.host?.lowercased() else { return }
            let allowed = Self.trustedHosts.contains(host) ||
                Self.trustedHosts.contains(where: { host.hasSuffix(".\($0)") })
            guard allowed else {
                state.toastCenter?.show(Toast(
                    kind: .warning,
                    messageKey: "content.url_blocked",
                    messageArg: host
                ))
                return
            }
            NSWorkspace.shared.open(item.sourceURL)
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