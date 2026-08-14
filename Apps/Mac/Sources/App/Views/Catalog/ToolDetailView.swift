import SwiftUI
import Localization
import Theme
import UI
import Domain
import Launching
import Content

/// 工具详情：固定关闭、本地状态面板、统一映射的主操作。
struct ToolDetailView: View {
    let tool: Tool
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorSchemeContrast) private var contrast

    private var presentation: ToolPresentation { state.presentation(for: tool) }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.space6) {
                    identity
                    localStatusPanel
                    section(titleKey: "tool.section.about") {
                        Text(tool.description)
                            .tokenFont(.body)
                            .foregroundStyle(DesignTokens.Palette.secondaryText)
                            .textSelection(.enabled)
                    }
                    section(titleKey: "tool.section.install") {
                        VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
                            ForEach(Array(tool.installOptions.enumerated()), id: \.offset) { _, opt in
                                installOptionRow(opt: opt)
                            }
                            if tool.installOptions.isEmpty {
                                Text("install.no_options")
                                    .tokenFont(.supporting)
                                    .foregroundStyle(DesignTokens.Palette.secondaryText)
                            }
                        }
                    }
                    section(titleKey: "tool.section.tutorials") {
                        let items = state.contentFor(toolID: tool.id)
                        if items.isEmpty {
                            Text("content.empty.description")
                                .tokenFont(.supporting)
                                .foregroundStyle(DesignTokens.Palette.secondaryText)
                        } else {
                            VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
                                ForEach(items) { item in
                                    ContentLinkRow(item: item, toolCategory: tool.category)
                                }
                            }
                        }
                    }
                }
                .padding(DesignTokens.Space.space6)
            }
        }
        .background(DesignTokens.Palette.appBackground)
        .frame(minWidth: 540, minHeight: 540)
        .onExitCommand {
            dismiss()
        }
        .task {
            if state.probe(for: tool.id) == nil {
                await state.refreshProbe(toolID: tool.id)
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: DesignTokens.Space.space3) {
            ToolIconView(toolID: tool.id, category: tool.category, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .tokenFont(.sectionTitle)
                presentation.badge
            }
            Spacer()
            Button {
                state.toggleFavorite(tool.id)
            } label: {
                Image(systemName: state.isFavorite(tool.id) ? "star.fill" : "star")
            }
            .buttonStyle(.borderless)
            .help(LocalizedStringKey(state.isFavorite(tool.id) ? "tool.unfavorite" : "tool.favorite"))
            .accessibilityLabel(Text(state.isFavorite(tool.id) ? "tool.unfavorite" : "tool.favorite"))

            Button {
                performPrimary()
            } label: {
                HStack(spacing: DesignTokens.Space.space1) {
                    Image(systemName: presentation.primarySystemImage)
                    Text(LocalizedStringKey(presentation.primaryLabelKey))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!presentation.primaryEnabled)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel(Text(LocalizedStringKey(presentation.primaryLabelKey)))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.cancelAction)
            .help("common.close")
            .accessibilityLabel(Text("common.close"))
        }
        .padding(DesignTokens.Space.space4)
    }

    private var identity: some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.space4) {
            ToolIconView(toolID: tool.id, category: tool.category, size: 72)
            VStack(alignment: .leading, spacing: DesignTokens.Space.space2) {
                Text(tool.name)
                    .tokenFont(.pageTitle)
                HStack(spacing: DesignTokens.Space.space2) {
                    presentation.badge
                    RiskBadge(level: highestRiskLevel)
                    CategoryLabel(category: tool.category)
                        .tokenFont(.tinyMetadata)
                        .padding(.horizontal, DesignTokens.Space.space2)
                        .padding(.vertical, 3)
                        .background(DesignTokens.Palette.hoverSurface, in: Capsule(style: .continuous))
                }
                versionSummary
            }
            Spacer()
        }
    }

    private var versionSummary: some View {
        HStack(spacing: DesignTokens.Space.space3) {
            labeledValue("tool.local.version", text: localVersionText)
            labeledValue("tool.latest.version", text: latestVersionText)
        }
    }

    private var localStatusPanel: some View {
        section(titleKey: "tool.section.localStatus") {
            VStack(alignment: .leading, spacing: DesignTokens.Space.space2) {
                labeledValue("tool.field.status", textKey: presentation.statusKey)
                labeledValue("tool.local.version", text: localVersionText)
                labeledValue("tool.latest.version", text: latestVersionText)
                labeledValue("tool.field.path", text: pathText)
                labeledValue("tool.field.architecture", text: architectureText)
                labeledValue("tool.field.source", text: sourceText)
                labeledValue("tool.field.lastChecked", text: lastCheckedText)
                Button {
                    Task {
                        await state.refreshProbe(toolID: tool.id)
                        await state.refreshLatestVersions()
                    }
                } label: {
                    Label("tool.action.refresh", systemImage: "arrow.clockwise")
                }
                .accessibilityLabel(Text("tool.action.refresh"))
            }
            .padding(DesignTokens.Space.space4)
            .background(
                DesignTokens.Palette.contentBackground,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
                    .stroke(
                        DesignTokens.Palette.border(increaseContrast: contrast == .increased),
                        lineWidth: DesignTokens.Palette.borderWidth(increaseContrast: contrast == .increased)
                    )
            )
        }
    }

    private var localVersionText: String {
        switch presentation.localDisplay {
        case .known(let value): return value
        case .unreadable: return String(localized: "tool.local.unreadable")
        case .none: return "—"
        }
    }

    private var latestVersionText: String {
        switch presentation.latestDisplay {
        case .known(let value): return value
        case .notQueried: return String(localized: "tool.latest.notQueried")
        case .unavailable: return String(localized: "tool.latest.unavailable")
        }
    }

    private var pathText: String {
        guard let path = state.probe(for: tool.id)?.detectedPath, !path.isEmpty else { return "—" }
        return ToolPresentationMapper.midTruncatedPath(path)
    }

    private var architectureText: String {
        guard let arch = state.probe(for: tool.id)?.architecture else {
            return String(localized: "tool.architecture.unknown")
        }
        return arch.rawValue
    }

    private var sourceText: String {
        guard let option = InstallConfirmation.resolvedOption(tool: tool) ?? tool.installOptions.first else {
            return String(localized: "tool.source.unknown")
        }
        return option.type.rawValue
    }

    private var lastCheckedText: String {
        guard let date = state.probe(for: tool.id)?.lastCheckedAt else { return "—" }
        return date.formatted(.relative(presentation: .named))
    }

    private var highestRiskLevel: RiskLevel {
        let order: [RiskLevel: Int] = [.low: 0, .medium: 1, .high: 2]
        return tool.installOptions.map(\.riskLevel).max(by: { (order[$0] ?? 0) < (order[$1] ?? 0) }) ?? .low
    }

    @ViewBuilder
    private func section<Content: View>(titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
            Text(titleKey)
                .tokenFont(.sectionTitle)
            content()
        }
    }

    private func labeledValue(_ labelKey: LocalizedStringKey, text: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(labelKey)
                .tokenFont(.supporting)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
                .frame(width: 120, alignment: .leading)
            Text(text)
                .tokenFont(.code)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }

    private func labeledValue(_ labelKey: LocalizedStringKey, textKey: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(labelKey)
                .tokenFont(.supporting)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
                .frame(width: 120, alignment: .leading)
            Text(LocalizedStringKey(textKey))
                .tokenFont(.body)
            Spacer()
        }
    }

    private func installOptionRow(opt: InstallOption) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.space3) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(DesignTokens.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.Space.space2) {
                    Text(opt.type.rawValue)
                        .tokenFont(.compactCode)
                        .foregroundStyle(DesignTokens.Palette.secondaryText)
                    RiskBadge(level: opt.riskLevel)
                }
                Text(commandPreview(opt))
                    .tokenFont(.code)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(DesignTokens.Space.space3)
        .background(
            DesignTokens.Palette.hoverSurface,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
        )
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

struct InstallUnavailableView: View {
    let tool: Tool
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space4) {
            HStack {
                Text("install.unavailable.title")
                    .tokenFont(.sectionTitle)
                Spacer()
                Button {
                    state.closeInstall()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(Text("common.close"))
            }
            Text("install.unavailable.body \(tool.name)")
                .tokenFont(.body)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
            Spacer()
        }
        .padding(DesignTokens.Space.space5)
        .frame(minWidth: 420, minHeight: 180)
    }
}

private struct ContentLinkRow: View {
    let item: ContentItem
    let toolCategory: ToolCategory
    @EnvironmentObject private var state: AppState

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
            HStack(alignment: .top, spacing: DesignTokens.Space.space3) {
                Image(systemName: typeIcon)
                    .foregroundStyle(DesignTokens.Palette.accent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .tokenFont(.supporting)
                    HStack(spacing: DesignTokens.Space.space2) {
                        if let author = item.author {
                            Text(author)
                                .tokenFont(.tinyMetadata)
                                .foregroundStyle(DesignTokens.Palette.secondaryText)
                        }
                        if let host = item.sourceURL.host {
                            Text(host)
                                .tokenFont(.tinyMetadata)
                                .foregroundStyle(DesignTokens.Palette.tertiaryText)
                        }
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
                    .accessibilityLabel(Text("content.externalLink"))
            }
            .padding(DesignTokens.Space.space2)
            .background(
                DesignTokens.Palette.hoverSurface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.badge, style: .continuous)
            )
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
}
