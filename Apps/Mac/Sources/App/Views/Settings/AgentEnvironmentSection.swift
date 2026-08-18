import SwiftUI
import Domain
import Theme
import UI

struct AgentEnvironmentSection: View {
    @EnvironmentObject private var state: AppState
    @State private var showsConflicts = false
    @State private var showsBulkUpdate = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space4) {
            headerActions
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                ForEach(state.agentTools) { AgentEnvironmentCard(tool: $0) }
            }
        }
        .sheet(isPresented: $showsConflicts) {
            InstallationConflictSheet()
                .environmentObject(state)
        }
        .sheet(isPresented: $showsBulkUpdate) {
            BulkAgentUpdateSheet()
                .environmentObject(state)
        }
    }

    private var plannedCount: Int {
        state.plannedBulkAgentUpdates().count
    }

    private var headerActions: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space2) {
            Text("settings.agentEnvironment.title")
                .tokenFont(.sectionTitle)
            Text("settings.agentEnvironment.subtitle")
                .tokenFont(.metadata)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
            HStack(spacing: DesignTokens.Space.space2) {
                Button("settings.agentEnvironment.diagnose") {
                    Task {
                        await state.diagnoseAgentInstallations()
                        showsConflicts = true
                    }
                }
                Button("settings.agentEnvironment.refresh") {
                    Task { await state.refreshAgentEnvironment(force: true) }
                }
                Button {
                    showsBulkUpdate = true
                } label: {
                    Text("settings.agentEnvironment.bulkUpdate") + Text(" (\(plannedCount))")
                }
                .disabled(plannedCount == 0)
            }
        }
    }
}
