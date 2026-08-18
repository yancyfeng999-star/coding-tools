import SwiftUI
import Theme
import UI

struct OnboardingSheet: View {
    @EnvironmentObject private var state: AppState

    private var report: CompatibilityReport { state.compatibilityReport() }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space5) {
            Text("onboarding.title")
                .tokenFont(.pageTitle)
            VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
                labeledRow(systemImage: "square.grid.2x2", key: "onboarding.body.tabs")
                labeledRow(systemImage: "checkmark.seal", key: "onboarding.body.sources")
                labeledRow(systemImage: "lock.shield", key: "onboarding.body.sudo")
                labeledRow(systemImage: "arrow.triangle.2.circlepath", key: "onboarding.body.updates")
            }
            compatibilityBlock
            Spacer()
            HStack {
                Spacer()
                Button {
                    Task { await state.completeOnboarding() }
                } label: {
                    Text("onboarding.continue")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DesignTokens.Space.space6)
        .frame(minWidth: 480, minHeight: 360)
        .background(DesignTokens.Palette.appBackground)
    }

    private func labeledRow(systemImage: String, key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.space3) {
            Image(systemName: systemImage)
                .foregroundStyle(DesignTokens.Palette.accent)
                .frame(width: 20)
            Text(key)
                .tokenFont(.body)
        }
    }

    @ViewBuilder
    private var compatibilityBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space2) {
            Text("onboarding.compatibility")
                .tokenFont(.sectionTitle)
            Text(report.isHealthy ? "onboarding.compatibility.ok" : "onboarding.compatibility.warn")
                .tokenFont(.supporting)
                .foregroundStyle(report.isHealthy ? DesignTokens.Palette.secondaryText : DesignTokens.Palette.warning)
            Text("\(report.currentMacOS) / \(report.architecture)")
                .tokenFont(.compactCode)
                .foregroundStyle(DesignTokens.Palette.tertiaryText)
                .textSelection(.enabled)
        }
        .padding(DesignTokens.Space.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignTokens.Palette.contentBackground,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
        )
    }
}
