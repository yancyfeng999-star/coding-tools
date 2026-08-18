import SwiftUI
import Domain
import ProcessExecution
import Theme
import UI

struct InstallationConflictSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(state.agentTools) { tool in
                    if let report = state.installationReports[tool.id], report.isConflict {
                        Section(tool.name) {
                            ForEach(report.installations) { installation in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(OutputRedactor.redactPath(installation.path))
                                        .tokenFont(.compactCode)
                                    Text(installation.version ?? "—")
                                    Text(LocalizedStringKey("tool.installSource.\(installation.source.rawValue)"))
                                    if installation.isPreferred {
                                        Text("tool.conflict.preferred")
                                            .foregroundStyle(DesignTokens.Palette.accent)
                                    }
                                    Text(installation.failure == nil ? "tool.conflict.runnable" : "tool.probe.installedButBroken")
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("settings.agentEnvironment.conflictsTitle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("settings.agentEnvironment.close", action: dismiss.callAsFunction)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}
