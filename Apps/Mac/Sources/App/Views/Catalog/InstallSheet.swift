import SwiftUI
import Localization
import Theme
import UI
import Domain

/// 安装进度：实时输出（脱敏后）+ 取消。
///
/// 阶段 11 修复（P0-G2-3 / G4-4）：不再写死 Homebrew + low + brew install <slug>。
/// 真实读取 tool.installOptions.first 并按 type 渲染：
/// - 来源 = `opt.type` 翻译（homebrew-formula / homebrew-cask / mise-tool / official-artifact / npm-global）
/// - 风险 = `opt.riskLevel`
/// - 操作 = 真实命令预览（brew install <packageName> / mise use <tool>@<version> 等）
struct InstallSheet: View {
    let tool: Tool
    let installOption: InstallOption
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    init(tool: Tool, installOption: InstallOption? = nil) {
        self.tool = tool
        self.installOption = installOption ?? tool.installOptions.first
            ?? InstallOption(type: .npmGlobal, riskLevel: .low)
    }

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
    }

    private var header: some View {
        HStack {
            ToolIconView(toolID: tool.id, category: tool.category, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("install.sheet.title \(tool.name)"))
                    .font(.headline)
                Text(sourceKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            RiskBadge(level: installOption.riskLevel)
        }
        .padding(16)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("install.preview.title")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                row(LocalizedStringKey("install.preview.tool"), value: tool.name)
                row(LocalizedStringKey("install.preview.source"), value: sourceDescription)
                row(LocalizedStringKey("install.preview.privilege"), value: privilegeDescription)
                row(LocalizedStringKey("install.preview.command"), value: commandPreview)
                row(LocalizedStringKey("install.preview.effect"), value: effectDescription)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Spacer()
                Button("install.cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("install.confirm") {
                    state.startInstall(tool, option: installOption)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
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
        // 当前阶段所有 adapter 都用当前用户权限；将来 brew/mise 需要 admin
        // 会自动检测 brew 路径再升级文案。
        "当前用户权限"
    }

    /// 真实命令预览（P0-G2-3 修复）：从 InstallOption 字段生成实际命令。
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
            let url = installOption.url?.absoluteString ?? "<missing url>"
            return "download \(url)"
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
        case .homebrewFormula: return "安装 CLI 到 /opt/homebrew/bin"
        case .homebrewCask:    return "安装 App 到 /Applications"
        case .miseTool:        return "通过 mise 切换 runtime"
        case .officialArtifact: return "下载并打开官方包"
        case .npmGlobal:       return "安装到 npm 全局目录"
        }
    }

    @ViewBuilder
    private var running: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            ScrollView {
                Text(state.installLog.isEmpty ? "common.loading" : state.installLog)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(maxHeight: .infinity)
        }
        .padding(16)
    }

    @ViewBuilder
    private var stateView: some View {
        switch state.installState {
        case .running:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("install.running")
            }
        case .cancelling:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("install.cancelling")
            }
        case .completed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("install.success")
            }
        case .failed:
            HStack(spacing: 6) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text("install.failed")
            }
        case .cancelled:
            HStack(spacing: 6) {
                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(.secondary)
                Text("install.cancel")
            }
        case .idle:
            EmptyView()
        }
    }

    private func row(_ label: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }
}