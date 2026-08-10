import SwiftUI
import Localization
import Theme
import UI

/// 设置：主题切换 / 语言切换 / 通用。
struct SettingsView: View {
    @ObservedObject private var language = LanguageManager.shared
    @ObservedObject private var theme = ThemeManager.shared

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
