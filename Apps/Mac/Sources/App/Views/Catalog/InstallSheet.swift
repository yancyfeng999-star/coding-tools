import SwiftUI
import Localization
import Theme
import UI
import Domain

/// 安装确认 / 运行。必须拿到真实可信 option，不得合成默认安装命令。
struct InstallSheet: View {
    let tool: Tool
    let installOption: InstallOption
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var confirmCloseRunning = false
    @State private var logExpanded = false

    init(tool: Tool, installOption: InstallOption) {
        self.tool = tool
        self.installOption = installOption
    }

    private var presentation: ToolPresentation { state.presentation(for: tool) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if state.installState == .idle {
                preview
            } else {
                running
            }
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 400)
        .confirmationDialog(
            "install.close.running.title",
            isPresented: $confirmCloseRunning,
            titleVisibility: .visible
        ) {
            Button("install.close.running.confirm", role: .destructive) {
                state.closeInstall()
                dismiss()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("install.close.running.message")
        }
        .onExitCommand {
            requestClose()
        }
    }

    private var header: some View {
        HStack {
            ToolIconView(toolID: tool.id, category: tool.category, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("install.sheet.title \(tool.name)"))
                    .tokenFont(.sectionTitle)
                Text(sourceKey)
                    .tokenFont(.tinyMetadata)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
            }
            Spacer()
            RiskBadge(level: installOption.riskLevel)
            Button(action: requestClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
            }
            .buttonStyle(.borderless)
            .help("common.close")
            .accessibilityLabel(Text("common.close"))
        }
        .padding(DesignTokens.Space.space4)
    }

    private var sourceKey: LocalizedStringKey {
        switch installOption.type {
        case .homebrewFormula: return "install.source homebrew-formula"
        case .homebrewCask:    return "install.source homebrew-cask"
        case .miseTool:        return "install.source mise-tool"
        case .officialArtifact: return "install.source official-artifact"
        case .npmGlobal:       return "install.source npm-global"
        }
    }

    @ViewBuilder
    private var preview: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space4) {
            Text("install.preview.title")
                .tokenFont(.sectionTitle)

            VStack(alignment: .leading, spacing: DesignTokens.Space.space2) {
                row(LocalizedStringKey("install.preview.tool"), value: tool.name)
                row(LocalizedStringKey("tool.local.version"), value: localVersionText)
                row(LocalizedStringKey("tool.latest.version"), value: latestVersionText)
                row(LocalizedStringKey("install.preview.source"), value: sourceDescription)
                row(LocalizedStringKey("install.preview.privilege"), value: privilegeDescription)
                row(LocalizedStringKey("install.preview.command"), value: commandPreview)
                row(LocalizedStringKey("install.preview.effect"), value: effectDescription)
            }
            .padding(DesignTokens.Space.space3)
            .background(
                DesignTokens.Palette.contentBackground,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
            )

            HStack {
                Spacer()
                Button("install.cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("install.confirm") {
                    state.startInstall(tool, option: installOption)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(InstallConfirmation.resolvedOption(tool: tool, preferred: installOption) == nil)
            }
        }
        .padding(DesignTokens.Space.space4)
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

    private var sourceDescription: String {
        switch installOption.type {
        case .homebrewFormula: return "Homebrew Formula"
        case .homebrewCask:    return "Homebrew Cask"
        case .miseTool:        return "Mise"
        case .officialArtifact: return "Official Artifact"
        case .npmGlobal:       return "npm"
        }
    }

    private var privilegeDescription: String {
        String(localized: "install.privilege.currentUser")
    }

    private var commandPreview: String {
        switch installOption.type {
        case .homebrewFormula:
            return "brew install \(installOption.packageName ?? tool.id)"
        case .homebrewCask:
            return "brew install --cask \(installOption.packageName ?? tool.id)"
        case .miseTool:
            let v = installOption.version.map { "@\($0)" } ?? "@latest"
            return "mise use \(installOption.toolName ?? tool.id)\(v)"
        case .officialArtifact:
            let host = installOption.url?.host ?? String(localized: "common.notProvided")
            return "download \(host)"
        case .npmGlobal:
            let pkg = installOption.packageName ?? tool.id
            if let v = installOption.versionRule, !v.isEmpty {
                return "npm install -g \(pkg)@\(v)"
            }
            return "npm install -g \(pkg)"
        }
    }

    private var effectDescription: String {
        switch installOption.type {
        case .homebrewFormula: return String(localized: "install.effect.formula")
        case .homebrewCask:    return String(localized: "install.effect.cask")
        case .miseTool:        return String(localized: "install.effect.mise")
        case .officialArtifact: return String(localized: "install.effect.artifact")
        case .npmGlobal:       return String(localized: "install.effect.npm")
        }
    }

    @ViewBuilder
    private var running: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
            HStack {
                stateView
                Spacer()
                if state.installState == .running || state.installState == .cancelling {
                    Button("install.cancel") {
                        state.cancelInstall()
                    }
                } else {
                    Button("install.close") {
                        state.closeInstall()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }

            DisclosureGroup(isExpanded: $logExpanded) {
                ScrollView {
                    Text(state.installLog.isEmpty ? String(localized: "common.loading") : state.installLog)
                        .tokenFont(.code)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignTokens.Space.space3)
                        .textSelection(.enabled)
                }
                .background(
                    DesignTokens.Palette.hoverSurface,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                )
                .frame(maxHeight: .infinity)
            } label: {
                Text("install.log.toggle")
                    .tokenFont(.supporting)
            }
        }
        .padding(DesignTokens.Space.space4)
    }

    @ViewBuilder
    private var stateView: some View {
        switch state.installState {
        case .running:
            HStack(spacing: DesignTokens.Space.space2) {
                ProgressView().controlSize(.small)
                Text("install.running")
            }
        case .cancelling:
            HStack(spacing: DesignTokens.Space.space2) {
                ProgressView().controlSize(.small)
                Text("install.cancelling")
            }
        case .completed:
            HStack(spacing: DesignTokens.Space.space2) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.Palette.success)
                Text("install.success")
            }
        case .completedPendingConfirmation:
            HStack(spacing: DesignTokens.Space.space2) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(DesignTokens.Palette.warning)
                Text("tool.status.installPendingConfirm")
            }
        case .failed:
            HStack(spacing: DesignTokens.Space.space2) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(DesignTokens.Palette.danger)
                Text("install.failed")
            }
        case .cancelled:
            HStack(spacing: DesignTokens.Space.space2) {
                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
                Text("install.cancel")
            }
        case .idle:
            EmptyView()
        }
    }

    private func requestClose() {
        if state.installState == .running || state.installState == .cancelling {
            confirmCloseRunning = true
        } else {
            state.closeInstall()
            dismiss()
        }
    }

    private func row(_ label: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .tokenFont(.code)
                .textSelection(.enabled)
        }
    }
}
