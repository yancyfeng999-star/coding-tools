import SwiftUI
import Localization
import Theme
import UI
import Updates

/// 设置：主题 / 语言 / 更新（Sparkle 静默流 + 进度条）/ 通用。
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var language = LanguageManager.shared
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                languageSection
                updatesSection
                generalSection
                aboutCard
            }
            .formStyle(.grouped)
            .navigationTitle("settings.title")
        }
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

    /// Sparkle 更新区：本地版本 / 远端版本 / 状态 / 进度条 / 操作按钮。
    /// 全部数据来自 AppState.updateState（订阅 UpdateFlowModel），不弹窗。
    private var updatesSection: some View {
        Section {
            versionRow(label: "settings.update.local",
                       value: appState.localVersion.isEmpty ? "—" : appState.localVersion,
                       build: appState.localBuild)

            versionRow(label: "settings.update.remote",
                       value: remoteVersionDisplay,
                       build: remoteBuildDisplay)

            statusRow
            progressRow

            HStack {
                Text("settings.update.channel")
                Spacer()
                Text("settings.update.channel.stable")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("settings.update.feed")
                Spacer()
                Text(feedURL)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        } header: {
            Text("settings.section.update")
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
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("settings.about")
                Spacer()
                Text("app.name")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("settings.section.general")
        }
    }

    // MARK: - About card (app icon + 名字 + 版本 + GitHub + 致谢)

    @ViewBuilder
    private var aboutCard: some View {
        Section {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    // 临时 icon：SF Symbol "curlybraces" + 主题色背景
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Image(systemName: "curlybraces")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("app.name")
                            .font(.title2.bold())
                        Text("settings.about.subtitle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                Divider()
                HStack {
                    Text("settings.version")
                    Spacer()
                    Text(appVersionString)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Text("settings.about.minmacos")
                    Spacer()
                    Text("macOS 14.0+")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("settings.about.architecture")
                    Spacer()
                    Text("Universal (arm64 + x86_64)")
                        .foregroundStyle(.secondary)
                }
                Divider()
                Button {
                    if let url = URL(string: "https://github.com/yancyfeng999-star/coding-tools") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                        Text("settings.about.github")
                        Spacer()
                        Text("yancyfeng999-star/coding-tools")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                HStack {
                    Text("settings.about.credits")
                    Spacer()
                    Text("Sparkle · Tuist · SwiftUI")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("settings.section.about")
        }
    }

    // MARK: - Sub-views

    private func versionRow(label: LocalizedStringKey, value: String, build: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            if build > 0 {
                Text("\(value) (\(build))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text(value)
                    .foregroundStyle(.secondary)
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
        switch appState.updateState {
        case .idle:
            Text("settings.update.status.idle")
                .foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("settings.update.status.checking")
                    .foregroundStyle(.secondary)
            }
        case .upToDate(let remote):
            Label("settings.update.status.upToDate \(remote)", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)
        case .available(let remote, _, let size):
            VStack(alignment: .trailing, spacing: 2) {
                Label("settings.update.status.available \(remote)", systemImage: "arrow.down.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.blue)
                Text(byteString(size))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        case .downloading(let progress, let bytes, let total):
            VStack(alignment: .trailing, spacing: 2) {
                Text("settings.update.status.downloading \(Int(progress * 100))")
                    .foregroundStyle(.blue)
                    .monospacedDigit()
                Text("\(byteString(bytes)) / \(byteString(total))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        case .extracting(let progress):
            Text("settings.update.status.extracting \(Int(progress * 100))")
                .foregroundStyle(.blue)
                .monospacedDigit()
        case .readyToInstall(let remote):
            Label("settings.update.status.readyToInstall \(remote)", systemImage: "arrow.up.circle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.orange)
        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("settings.update.status.installing")
                    .foregroundStyle(.blue)
            }
        case .installed:
            Label("settings.update.status.installed", systemImage: "checkmark.seal.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)
        case .failed(let reason, _):
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var progressRow: some View {
        if case .downloading(let progress, _, _) = appState.updateState {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.blue)
        } else if case .extracting(let progress) = appState.updateState {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.blue)
        } else {
            // 不显示进度条占空间
            EmptyView()
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        // 旧的「检查更新」按钮：被 actionRow 取代，保留入口方便 grep
        Button {
            appState.checkForUpdates()
        } label: {
            Label("settings.update.check", systemImage: "arrow.triangle.2.circlepath")
        }
    }

    // MARK: - Helpers

    private var remoteVersionDisplay: String {
        switch appState.updateState {
        case .upToDate(let v): return v
        case .available(let v, _, _): return v
        case .readyToInstall(let v): return v
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
}
