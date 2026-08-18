import SwiftUI
import AppKit
import Domain
import Theme
import UI

struct AgentEnvironmentCard: View {
    let tool: Tool
    @EnvironmentObject private var state: AppState

    private var model: AgentEnvironmentCardModel {
        state.agentEnvironmentCardModel(for: tool.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
            header
            labeledRow("settings.agentEnvironment.local", value: localized(model.localSummary))
            labeledRow("settings.agentEnvironment.latest", value: localized(model.latestSummary))
            labeledRow("settings.agentEnvironment.source", value: localized(model.sourceLabel))
            if model.conflictCount > 1 {
                HStack(spacing: 4) {
                    Text("tool.conflict.multiple")
                    Text("(\(model.conflictCount))")
                }
                .tokenFont(.metadata)
                .foregroundStyle(DesignTokens.Palette.warning)
            }
            actionRow
        }
        .toolCardChrome(status: model.healthStatus, isHovering: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tool.name)
        .accessibilityValue(model.accessibilitySummary)
    }

    private var header: some View {
        HStack {
            Text(tool.name)
                .tokenFont(.sectionTitle)
            Spacer()
            HealthBadge(status: model.healthStatus)
        }
    }

    private func labeledRow(_ key: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(key)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
            Spacer()
            Text(value)
                .textSelection(.enabled)
        }
        .tokenFont(.metadata)
    }

    private var actionRow: some View {
        Button {
            perform(model.primaryAction)
        } label: {
            Text(LocalizedStringKey(model.primaryLabelKey))
        }
        .disabled(!model.primaryEnabled)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func perform(_ action: ToolPrimaryAction) {
        switch action {
        case .install, .update, .repair, .reinstall:
            state.startInstall(tool)
        case .open:
            state.launch(tool)
        case .refresh, .retry:
            Task { await state.refreshAgentEnvironment(force: true) }
        case .unavailable, .none:
            NSWorkspace.shared.open(tool.documentationURL ?? tool.homepageURL)
        }
    }

    private func localized(_ value: String) -> String {
        if value.contains(".") && !value.contains(" ") {
            return String(localized: String.LocalizationValue(value))
        }
        return value
    }
}
