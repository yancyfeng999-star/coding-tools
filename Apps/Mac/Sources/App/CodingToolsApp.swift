import SwiftUI
import Updates
import UI

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
                    // 启动时把 AppState 连到 AppModel + UpdateFlowModel
                    appState.appUpdatingProvider = { [weak appModel] in
                        appModel?.appUpdater
                    }
                    if let model = appModel.updateFlowModel {
                        appState.bindUpdates(model)
                    }
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
