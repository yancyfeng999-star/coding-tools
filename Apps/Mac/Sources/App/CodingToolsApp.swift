import SwiftUI
import Updates
import UI
import Catalog
import LatestVersion
import Persistence
import Installers

@main
struct CodingToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .frame(minWidth: 720, minHeight: 480)
                .task {
                    // 启动时把 AppState 连到 AppModel + UpdateFlowModel + ToastCenter
                    appState.appUpdatingProvider = { [weak appModel] in
                        appModel?.appUpdater
                    }
                    appState.toastCenter = ToastCenter.shared
                    if let model = appModel.updateFlowModel {
                        appState.bindUpdates(model)
                    }
                    // 阶段 11 修复（P0-G1-1/3）：catalogProvider 不再用 try?；
                    // 失败通过 catch 路径显示具体错误（签名 / 过期 / 缺失公钥）。
                    let loader = LocalCatalogLoader()
                    appState.catalogProvider = {
                        try await loader.loadCatalog()
                    }
                    appState.persistStore = AppState.makeDefaultStore()
                    // P0-G2-5 修复：注入 HelperClient；Helper 不可用时 in-process
                    // adapter 兜底。
                    appState.helperClient = HelperClient()
                    await appState.loadCatalogIfNeeded()
                    // 启动扫 AI CLI 配置（在用户 home 找 Claude/Codex/Gemini 等配置）
                    await appState.discoverAIConfigs()
                    // Catalog 加载完跑更新后 Detection，UI 立刻能看到 24 个工具的安装状态
                    await appState.refreshProbes()
                    // 探测完后再拉 latest version（依赖 installed version）
                    await appState.refreshLatestVersions()
                    // P0-G3-1 修复：从 store 恢复最近列表
                    await appState.loadRecents()
                    await appState.loadFavorites()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
