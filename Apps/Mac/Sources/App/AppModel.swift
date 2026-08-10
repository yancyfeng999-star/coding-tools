import SwiftUI
import Combine
import Updates

/// 整个 App 的状态中枢。Coordinator/Owner 负责扩展。
/// 任何 UI 状态、目录、安装队列、收藏、最近使用都通过 AppModel 暴露。
@MainActor
final class AppModel: ObservableObject {
    // MARK: - UI State

    @Published var selectedTab: AppTab = .home
    @Published var searchText: String = ""

    // MARK: - Updates (Sparkle)

    /// 给 SettingsView 暴露的更新门面。nil 表示 AppDelegate 尚未就绪（极少见）。
    var appUpdater: AppUpdating? { AppDelegate.shared?.appUpdater }
    /// 更新流程状态机（AppState 通过它订阅 emit）。
    var updateFlowModel: UpdateFlowModel? { AppDelegate.shared?.updateModel }

    // MARK: - Lifecycle

    init() {
        // 阶段 1 占位：阶段 2 接入 Catalog 加载
        // 阶段 3 接入 Installers / Detection
        // 阶段 5 接入 Content
    }
}

enum AppTab: Hashable {
    case home
    case catalog
    case content
    case settings
}
