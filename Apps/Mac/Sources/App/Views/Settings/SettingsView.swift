import SwiftUI
import Localization
import Theme
import UI
import Updates

/// 设置：主题切换 / 语言切换 / 更新 / 通用。
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var language = LanguageManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            Form {
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

                Section {
                    Picker("settings.language.label", selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                } header: {
                    Text("settings.section.language")
                }

                Section {
                    Button {
                        isChecking = true
                        appModel.appUpdater?.checkForUpdates()
                        // Sparkle 自己管弹窗；3s 后解锁按钮（避免重复点）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            isChecking = false
                        }
                    } label: {
                        HStack {
                            Label("settings.update.check", systemImage: "arrow.triangle.2.circlepath")
                            if isChecking {
                                Spacer()
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .disabled(isChecking || appModel.appUpdater == nil)
                    .help("settings.update.help")

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
            .formStyle(.grouped)
            .navigationTitle("settings.title")
        }
    }

    private var feedURL: String {
        (Bundle.main.infoDictionary?["SUFeedURL"] as? String) ?? "—"
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
