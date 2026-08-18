import SwiftUI
import Theme
import UI

struct BulkAgentUpdateSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var started = false

    private var items: [BulkToolUpdateItem] {
        state.plannedBulkAgentUpdates()
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.tool.name)
                        Text("\(item.localVersion) → \(item.targetVersion)")
                            .tokenFont(.caption)
                            .foregroundStyle(DesignTokens.Palette.secondaryText)
                        if let itemState = state.bulkUpdateState.itemStates[item.id] {
                            Text(label(for: itemState))
                                .tokenFont(.caption)
                        }
                    }
                }
            }
            .navigationTitle("settings.agentEnvironment.bulkTitle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("settings.agentEnvironment.close", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("tool.bulkUpdate.confirm") {
                        started = true
                        Task { await state.runBulkAgentUpdate(items: items) }
                    }
                    .disabled(started || items.isEmpty)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    private func label(for itemState: BulkToolUpdateItemState) -> LocalizedStringKey {
        switch itemState {
        case .pending: return "tool.bulkUpdate.pending"
        case .running: return "tool.bulkUpdate.running"
        case .completed: return "tool.bulkUpdate.completed"
        case .failed: return "tool.bulkUpdate.failed"
        case .skipped: return "tool.bulkUpdate.skipped"
        }
    }
}
