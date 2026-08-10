import SwiftUI
import Localization
import Theme
import UI
import Domain

/// 安装进度：实时输出（脱敏后）+ 取消。
struct InstallSheet: View {
    let tool: Tool
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

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
                Text(LocalizedStringKey("install.source homebrew-formula"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            RiskBadge(level: .low)
        }
        .padding(16)
    }

    @ViewBuilder
    private var preview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("install.preview.title")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                row("工具", value: tool.name)
                row("来源", value: "Homebrew Formula")
                row("权限", value: "当前用户权限")
                row("操作", value: "brew install \(tool.slug)")
                row("预计变化", value: "安装 CLI 到 /opt/homebrew")
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Spacer()
                Button("install.cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("install.confirm") {
                    state.startInstall(tool)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var running: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                stateView
                Spacer()
                if state.installState == .running {
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

    private func row(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
