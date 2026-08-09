import SwiftUI

/// 阶段 1 占位：阶段 4 接入完整 UI（首页 / 工具目录 / 内容中心 / 设置）
struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            HomePlaceholder()
                .tabItem { Label("首页", systemImage: "house") }
                .tag(AppTab.home)
            CatalogPlaceholder()
                .tabItem { Label("工具", systemImage: "shippingbox") }
                .tag(AppTab.catalog)
            ContentPlaceholder()
                .tabItem { Label("教程", systemImage: "book") }
                .tag(AppTab.content)
            SettingsPlaceholder()
                .tabItem { Label("设置", systemImage: "gear") }
                .tag(AppTab.settings)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

private struct HomePlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Coding Tools")
                .font(.largeTitle)
            Text("v0.0.0 · 工程原型")
                .foregroundStyle(.secondary)
            Text("阶段 0 — 产品和安全契约")
                .font(.callout)
        }
        .padding()
    }
}

private struct CatalogPlaceholder: View {
    var body: some View {
        ContentUnavailableView("工具目录", systemImage: "shippingbox", description: Text("阶段 2 接入"))
    }
}

private struct ContentPlaceholder: View {
    var body: some View {
        ContentUnavailableView("教程与视频", systemImage: "book", description: Text("阶段 5 接入"))
    }
}

private struct SettingsPlaceholder: View {
    var body: some View {
        ContentUnavailableView("设置", systemImage: "gear", description: Text("阶段 6 完善"))
    }
}
