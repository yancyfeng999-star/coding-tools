import Foundation
import SwiftUI
import Domain
import Catalog
import Installers
import Detection
import Launching
import Content
import Persistence

// MARK: - UI
//
// SwiftUI 视图层。阶段 4 由子代理 B 接入完整 UI。
// 阶段 1 占位：暴露公共依赖容器供 AppModel 注入。
// 备注：Localization / Theme 类型由 AppModel 直接持有（不在 UI 模块内构造），
// 避免跨模块类型引用问题。阶段 6 由子代理 B 引入 UI 视图层时再决定是否需要。

/// UI 模块的依赖容器。子代理 B 在阶段 4 引入真实依赖。
@MainActor
public final class UIDependencies: ObservableObject {
    public let catalogLoader: CatalogLoading?
    public let installAdapters: [InstallActionType: InstallAdapter]
    public let detector: InstallationDetecting
    public let launcher: Launching
    public let contentLoader: ContentLoading?
    public let store: Store

    public init(
        catalogLoader: CatalogLoading? = nil,
        installAdapters: [InstallActionType: InstallAdapter] = [:],
        detector: InstallationDetecting = InstallationDetector(),
        launcher: Launching = MacLauncher(),
        contentLoader: ContentLoading? = nil,
        store: Store = InMemoryStore()
    ) {
        self.catalogLoader = catalogLoader
        self.installAdapters = installAdapters
        self.detector = detector
        self.launcher = launcher
        self.contentLoader = contentLoader
        self.store = store
    }
}
