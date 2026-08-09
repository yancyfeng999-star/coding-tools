import SwiftUI
import Combine

/// 整个 App 的状态中枢。Coordinator/Owner 负责扩展。
/// 任何 UI 状态、目录、安装队列、收藏、最近使用都通过 AppModel 暴露。
@MainActor
final class AppModel: ObservableObject {
    // MARK: - UI State

    @Published var selectedTab: AppTab = .home
    @Published var searchText: String = ""

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
