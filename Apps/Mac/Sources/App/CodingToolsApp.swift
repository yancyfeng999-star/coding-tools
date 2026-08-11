import SwiftUI
import Updates
import UI
import Catalog

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
                    // 加载本地 Catalog 资源（v1.5.0+）：从 Bundle 读 Catalog/tools/*.json
                    // 阶段 11 切换到 RemoteCatalogLoader + Ed25519 验签后，这里替换 provider。
                    appState.catalogProvider = {
                        try? await LocalCatalogLoader().loadCatalog()
                    }
                    await appState.loadCatalogIfNeeded()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
