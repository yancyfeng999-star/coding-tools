import SwiftUI
import Localization
import Theme
import UI

/// 阶段 4 完整 UI：4 个 tab + 安装弹窗 + 菜单栏。
/// AppModel 只负责 selectedTab / searchText（高冲突，Coordinator 拥有）；
/// 其他状态由 AppState 持有（Sources/UI/State/）。
struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var state: AppState
    @ObservedObject private var language = LanguageManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @StateObject private var menuBar = AppMenuBar.shared

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            HomeView()
                .tabItem {
                    Label(LocalizedStringKey("tab.home"), systemImage: "house")
                }
                .tag(AppTab.home)
            CatalogView()
                .tabItem {
                    Label(LocalizedStringKey("tab.catalog"), systemImage: "shippingbox")
                }
                .tag(AppTab.catalog)
            ContentView()
                .tabItem {
                    Label(LocalizedStringKey("tab.content"), systemImage: "book")
                }
                .tag(AppTab.content)
            SettingsView()
                .tabItem {
                    Label(LocalizedStringKey("tab.settings"), systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
        .frame(minWidth: 880, minHeight: 560)
        .environmentObject(language)
        .environmentObject(theme)
        .bindLanguage(language)
        .bindTheme(theme)
        .task {
            await state.loadCatalogIfNeeded()
            await state.loadContentIfNeeded()
            await state.loadFavorites()
            menuBar.attach(state: state)
            menuBar.refreshMenu()
        }
        .onChange(of: state.recent) { _, _ in
            menuBar.refreshMenu()
        }
        .onChange(of: state.favorites) { _, _ in
            menuBar.refreshMenu()
        }
        .onChange(of: theme.mode) { _, _ in
            menuBar.refreshMenu()
        }
        .onReceive(NotificationCenter.default.publisher(for: .codingToolsOpenSettings)) { _ in
            appModel.selectedTab = .settings
            // 菜单栏点击 Settings 时也把主窗口拉到前台
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
