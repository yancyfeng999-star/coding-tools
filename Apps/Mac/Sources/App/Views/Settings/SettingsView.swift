import SwiftUI
import Localization
import Theme
import UI
import Updates
import Persistence
import ProcessExecution
import UniformTypeIdentifiers

/// 设置：外观 / 语言 / 应用更新 / 通用 / 支持与反馈 / 诊断与恢复 / 关于。
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var language = LanguageManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var showDiagnosticPreview = false
    @State private var showHelp = false

    private var updateEntry: AppUpdateEntry { AppUpdateEntry.forSettings(appState.updateState) }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                languageSection
                agentEnvironmentSection
                updatesSection
                generalSection
                supportSection
                diagnosticsSection
                aboutCard
            }
            .formStyle(.grouped)
            .navigationTitle("settings.title")
            .sheet(isPresented: $showDiagnosticPreview) {
                DiagnosticPreviewSheet(summary: diagnosticSummary) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(diagnosticSummary.previewText, forType: .string)
                    showDiagnosticPreview = false
                }
            }
            .sheet(isPresented: $showHelp) {
                HelpSheet()
            }
        }
        .background(DesignTokens.Palette.appBackground)
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section {
            Picker("settings.theme.label", selection: themeBinding) {
                Text("settings.theme.system").tag(ThemeMode.system)
                Text("settings.theme.light").tag(ThemeMode.light)
                Text("settings.theme.dark").tag(ThemeMode.dark)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("settings.section.appearance")
        }
    }

    private var languageSection: some View {
        Section {
            Picker("settings.language.label", selection: languageBinding) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
        } header: {
            Text("settings.section.language")
        }
    }

    private var agentEnvironmentSection: some View {
        Section {
            AgentEnvironmentSection()
                .environmentObject(appState)
        } header: {
            Text("settings.section.agentEnvironment")
        } footer: {
            Text("settings.agentEnvironment.footer")
        }
    }

    private var updatesSection: some View {
        Section {
            Button(action: appState.performAppUpdateAction) {
                Label(LocalizedStringKey(updateEntry.titleKey), systemImage: updateEntry.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!updateEntry.isEnabled)
            .accessibilityIdentifier("settings.update.action")
            .accessibilityLabel(Text(LocalizedStringKey(updateEntry.titleKey)))

            versionRow(label: "settings.update.local",
                       value: displayedLocalVersion,
                       build: displayedLocalBuild)

            versionRow(label: "settings.update.remote",
                       value: remoteVersionDisplay,
                       build: remoteBuildDisplay)

            statusRow
            progressRow

            HStack {
                Text("settings.update.channel")
                Spacer()
                Text("settings.update.channel.stable")
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
            }
            HStack {
                Text("settings.update.feed")
                Spacer()
                Text(feedURL)
                    .tokenFont(.compactCode)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Button {
                openURL(URL(string: IssueURLBuilder.latestReleaseURL)!)
            } label: {
                Label("settings.update.downloadRelease", systemImage: "arrow.down.app")
            }
        } header: {
            Text("settings.section.appUpdate")
        } footer: {
            Text("settings.update.footer")
        }
    }

    private var generalSection: some View {
        Section {
            HStack {
                Text("settings.version")
                Spacer()
                Text(appVersionString)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
                    .monospacedDigit()
            }
        } header: {
            Text("settings.section.general")
        }
    }

    private var supportSection: some View {
        Section {
            Button {
                openURL(IssueURLBuilder.bugReportURL(metadata: issueMetadata))
            } label: {
                Label("settings.support.reportIssue", systemImage: "exclamationmark.bubble")
            }
            Button {
                openURL(IssueURLBuilder.featureIdeaURL())
            } label: {
                Label("settings.support.featureIdea", systemImage: "lightbulb")
            }
            Button {
                openURL(URL(string: IssueURLBuilder.homepageURL)!)
            } label: {
                Label("settings.support.homepage", systemImage: "globe")
            }
            Button {
                openURL(URL(string: IssueURLBuilder.helpURL)!)
            } label: {
                Label("settings.support.help", systemImage: "questionmark.circle")
            }
            Button {
                showHelp = true
            } label: {
                Label("settings.help.open", systemImage: "questionmark.circle")
            }
            Button {
                showDiagnosticPreview = true
            } label: {
                Label("settings.support.copyDiagnostics", systemImage: "doc.on.clipboard")
            }
        } header: {
            Text("settings.section.support")
        } footer: {
            Text("settings.support.footer")
        }
    }

    private var diagnosticsSection: some View {
        Section {
            labeled("settings.diagnostics.catalogVersion", value: appState.catalogSnapshot?.catalogVersion ?? "—")
            labeled("settings.diagnostics.keyID", value: appState.catalogSnapshot?.keyID ?? "—")
            labeled("settings.diagnostics.toolCount", value: "\(appState.catalogSnapshot?.tools.count ?? 0)")
            labeled("settings.diagnostics.expires", value: expiresText)
            labeled("settings.diagnostics.cache", value: cacheText)
            labeled("settings.diagnostics.lastCrash", value: lastCrashText)
            labeled("settings.diagnostics.compatibility", value: compatibilityText)

            Button("settings.diagnostics.refreshCatalog") {
                Task {
                    await appState.refreshCatalog()
                    appState.refreshCatalogCacheMetadata()
                }
            }
            Button("settings.diagnostics.resetCache") {
                Task { await appState.resetCatalogCache() }
            }
            Button("settings.diagnostics.openCrashFolder") {
                appState.openCrashFolder()
            }
            Button("settings.diagnostics.export") {
                exportUserData()
            }
            Button("settings.diagnostics.import") {
                importUserData()
            }
            Button("settings.diagnostics.clearHistory") {
                Task { await appState.clearOperationHistory() }
            }
            Button("settings.support.copyDiagnostics") {
                showDiagnosticPreview = true
            }
        } header: {
            Text("settings.section.diagnostics")
        } footer: {
            Text("settings.diagnostics.footer")
        }
    }

    @ViewBuilder
    private var aboutCard: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
                HStack(spacing: DesignTokens.Space.space3) {
                    Image("CodingToolsLogo")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel(Text("app.name"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("app.name")
                            .tokenFont(.itemTitle)
                        Text("settings.about.subtitle")
                            .tokenFont(.tinyMetadata)
                            .foregroundStyle(DesignTokens.Palette.secondaryText)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                labeled("settings.version", value: appVersionString)
                labeled("settings.about.minmacos", value: "macOS 14.0+")
                labeled("settings.about.architecture", value: "Universal (arm64 + x86_64)")
                Button {
                    openURL(URL(string: IssueURLBuilder.homepageURL)!)
                } label: {
                    HStack {
                        Text("settings.about.github")
                        Spacer()
                        Text("yancyfeng999-star/coding-tools")
                            .tokenFont(.compactCode)
                            .foregroundStyle(DesignTokens.Palette.tertiaryText)
                    }
                }
                .buttonStyle(.plain)
                labeled("settings.about.credits", value: "Sparkle · Tuist · SwiftUI")
            }
            .padding(.vertical, DesignTokens.Space.space2)
        } header: {
            Text("settings.section.about")
        }
    }

    private func labeled(_ key: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
                .monospacedDigit()
        }
    }

    private func versionRow(label: LocalizedStringKey, value: String, build: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            if build > 0 {
                Text("\(value) (\(build))")
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
                    .monospacedDigit()
            } else {
                Text(value)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack {
            Text("settings.update.status")
            Spacer()
            statusLabel
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        let presentation = UpdateStatusPresentation.settings(for: appState.updateState)
        switch appState.updateState {
        case .idle:
            Text(statusText(presentation))
                .foregroundStyle(DesignTokens.Palette.secondaryText)
        case .checking:
            HStack(spacing: DesignTokens.Space.space2) {
                ProgressView().controlSize(.small)
                Text(statusText(presentation))
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
            }
        case .upToDate:
            Label(statusText(presentation), systemImage: "checkmark.circle.fill")
                .foregroundStyle(DesignTokens.Palette.success)
        case .available(_, _, let size):
            VStack(alignment: .trailing, spacing: 2) {
                Label(statusText(presentation), systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(DesignTokens.Palette.accent)
                Text(byteString(size))
                    .tokenFont(.tinyMetadata)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
            }
        case .downloading(_, let bytes, let total):
            VStack(alignment: .trailing, spacing: 2) {
                Text(statusText(presentation))
                    .foregroundStyle(DesignTokens.Palette.accent)
                    .monospacedDigit()
                Text("\(byteString(bytes)) / \(byteString(total))")
                    .tokenFont(.tinyMetadata)
                    .foregroundStyle(DesignTokens.Palette.secondaryText)
            }
        case .extracting:
            Text(statusText(presentation))
                .foregroundStyle(DesignTokens.Palette.accent)
                .monospacedDigit()
        case .readyToInstall:
            Label(statusText(presentation), systemImage: "arrow.up.circle.fill")
                .foregroundStyle(DesignTokens.Palette.warning)
        case .installing:
            HStack(spacing: DesignTokens.Space.space2) {
                ProgressView().controlSize(.small)
                Text(statusText(presentation))
                    .foregroundStyle(DesignTokens.Palette.accent)
            }
        case .installed:
            Label(statusText(presentation), systemImage: "checkmark.seal.fill")
                .foregroundStyle(DesignTokens.Palette.success)
        case .failed:
            Label(statusText(presentation), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.Palette.danger)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var progressRow: some View {
        if case .downloading(let progress, _, _) = appState.updateState {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(DesignTokens.Palette.accent)
        } else if case .extracting(let progress) = appState.updateState {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(DesignTokens.Palette.accent)
        }
    }

    private var displayedLocalVersion: String {
        UpdateStatusPresentation.runningVersion().version
    }

    private var displayedLocalBuild: Int {
        UpdateStatusPresentation.runningVersion().build
    }

    private func statusText(_ presentation: UpdateStatusPresentation) -> String {
        if presentation.key.isEmpty {
            return presentation.argument ?? ""
        }
        if let argument = presentation.argument {
            return String(format: NSLocalizedString(presentation.key, comment: ""), locale: .current, argument)
        }
        return NSLocalizedString(presentation.key, comment: "")
    }

    private var remoteVersionDisplay: String {
        switch appState.updateState {
        case .upToDate(let v): return UpdateStatusPresentation.displayVersion(v)
        case .available(let v, _, _): return UpdateStatusPresentation.displayVersion(v)
        case .readyToInstall(let v): return UpdateStatusPresentation.displayVersion(v)
        default: return "—"
        }
    }

    private var remoteBuildDisplay: Int {
        switch appState.updateState {
        case .available(_, let b, _): return b
        default: return 0
        }
    }

    private var feedURL: String {
        (Bundle.main.infoDictionary?["SUFeedURL"] as? String) ?? "—"
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var themeBinding: Binding<ThemeMode> {
        Binding(
            get: { theme.mode },
            set: { theme.apply($0) }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { language.current },
            set: { language.switchTo($0) }
        )
    }

    private var appVersionString: String {
        let dict = Bundle.main.infoDictionary
        let short = (dict?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
        let build = (dict?["CFBundleVersion"] as? String) ?? "1"
        return "\(short) (\(build))"
    }

    private var issueMetadata: IssueReportMetadata {
        IssueURLBuilder.currentMetadata(
            version: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? appState.localVersion,
            build: (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "\(appState.localBuild)"
        )
    }

    private var diagnosticSummary: DiagnosticSummary {
        let meta = issueMetadata
        return DiagnosticSummaryBuilder.make(
            version: meta.version,
            build: meta.build,
            macOSVersion: meta.macOSVersion,
            architecture: meta.architecture,
            theme: theme.mode.rawValue,
            language: language.current.rawValue,
            catalogStatus: appState.catalogStatusSummary(),
            appUpdateState: appState.updateState.statusTextKey,
            selectedToolStatus: appState.selectedTool.map { "\($0.id):\(appState.presentation(for: $0).statusKey)" }
        )
    }

    private var expiresText: String {
        guard let date = appState.catalogSnapshot?.expiresAt else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var cacheText: String {
        guard let meta = appState.catalogCacheMetadata else {
            return String(localized: "settings.diagnostics.cache.empty")
        }
        let when = meta.savedAt.formatted(.relative(presentation: .named))
        return "\(meta.catalogVersion) · \(meta.bytes) · \(when)"
    }

    private var lastCrashText: String {
        if let date = appState.crashRecovery?.lastCrashAt ?? CrashRecovery.status(
            directory: CrashReporter.defaultDirectory(),
            acknowledgedAt: nil
        ).lastCrashAt {
            return date.formatted(.relative(presentation: .named))
        }
        return String(localized: "settings.diagnostics.noCrash")
    }

    private var compatibilityText: String {
        let report = appState.compatibilityReport()
        return "macOS \(report.currentMacOS) · \(report.architecture) · \(report.isHealthy ? "ok" : "warn")"
    }

    private func exportUserData() {
        let payload = appState.exportUserData()
        guard let data = try? UserDataPortable.encode(payload) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "coding-tools-user-data.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private func importUserData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
            Task { @MainActor in
                do {
                    try await appState.importUserData(data)
                } catch {
                    appState.toastCenter?.show(Toast(kind: .error, messageKey: "settings.diagnostics.importFailed"))
                }
            }
        }
    }

    private func openURL(_ url: URL) {
        if !NSWorkspace.shared.open(url) {
            appState.toastCenter?.show(Toast(kind: .warning, messageKey: "settings.support.urlFailed", messageArg: url.absoluteString))
        }
    }
}

private struct DiagnosticPreviewSheet: View {
    let summary: DiagnosticSummary
    let onCopy: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space4) {
            HStack {
                Text("settings.diagnostics.previewTitle")
                    .tokenFont(.sectionTitle)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("common.close"))
            }
            Text("settings.diagnostics.previewBody")
                .tokenFont(.supporting)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
            Text(summary.previewText)
                .tokenFont(.code)
                .textSelection(.enabled)
                .padding(DesignTokens.Space.space3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    DesignTokens.Palette.contentBackground,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                )
            HStack {
                Spacer()
                Button("common.cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("settings.diagnostics.confirmCopy", action: onCopy)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DesignTokens.Space.space5)
        .frame(minWidth: 420, minHeight: 280)
    }
}
