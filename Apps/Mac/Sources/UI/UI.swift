import Foundation
import SwiftUI
import Domain
import Content
import Persistence
import Launching

// MARK: - UI
//
// SwiftUI 视图层。阶段 4 由子代理 B 接入完整 UI。
//
// 注意：原 `UIDependencies` 引用了 `Catalog.CatalogLoading` / `Installers.InstallAdapter` /
// `Installers.InstallActionType`，但 Catalog / Installers 阶段 2/3 接入中编译失败。
// 这里改为**协议存在型 (any ...)**，并把具体类型隔离到使用方（AppState 用闭包注入），
// 保证 UI 模块自身在 Catalog/Installers 修复前也能独立编译。
//
// 阶段 6 由子代理 B 引入完整类型桥接（占位 → 真实）。

/// UI 模块的依赖容器。**当前是占位**。
/// 阶段 2/3 接入完成后：
/// - `catalogLoader` 改为 `any CatalogLoading`
/// - `installAdapters` 改为 `[InstallActionType: any InstallAdapter]`
/// - 移除 default
@MainActor
public final class UIDependencies: ObservableObject {
    public init() {}
}
