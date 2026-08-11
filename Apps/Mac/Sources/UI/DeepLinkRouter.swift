import Foundation

// MARK: - DeepLink
//
// 解析 `codingtools://` URL scheme。
//
// 支持的 shape：
//   codingtools://tool/<id>                 → 打开 tool 详情
//   codingtools://install?tool=<id>         → 打开 tool 详情 + 触发 install
//   codingtools://home?tab=<catalog|home|content|settings>
//   codingtools://update                    → 检查 app 更新
//
// 错误格式：nil。UI 端忽略即可。

public enum DeepLink: Equatable, Sendable {
    case openTool(id: String, autoInstall: Bool)
    case home(tab: String?)   // tab id 留空 = 切到 home
    case checkForUpdate
}

public enum DeepLinkRouter: Sendable {
    public static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme?.lowercased() == "codingtools" else { return nil }
        let host = url.host?.lowercased() ?? ""
        let segments = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "tool":
            guard let id = segments.first, !id.isEmpty else { return nil }
            return .openTool(id: id, autoInstall: false)
        case "install":
            if let toolQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "tool" })?.value,
               !toolQuery.isEmpty {
                return .openTool(id: toolQuery, autoInstall: true)
            }
            if let id = segments.first, !id.isEmpty {
                return .openTool(id: id, autoInstall: true)
            }
            return nil
        case "home":
            let tab = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "tab" })?.value
            return .home(tab: tab)
        case "update":
            return .checkForUpdate
        default:
            return nil
        }
    }
}
