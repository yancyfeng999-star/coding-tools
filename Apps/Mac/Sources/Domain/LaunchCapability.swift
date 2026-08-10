import Foundation

// MARK: - LaunchCapability
//
// 工具的「启动能力」—— 描述用户安装后如何打开它。
// 对应 schema 中 tool.launchCapability。

public enum LaunchType: String, Hashable, Sendable, Codable {
    case cli
    case app
    case url
    case none
}

public struct LaunchCapability: Hashable, Sendable, Codable {
    public let type: LaunchType
    public let command: String?
    public let arguments: [String]
    public let openInTerminal: Bool
    public let bundleID: String?
    public let url: URL?

    public init(
        type: LaunchType,
        command: String? = nil,
        arguments: [String] = [],
        openInTerminal: Bool = false,
        bundleID: String? = nil,
        url: URL? = nil
    ) {
        self.type = type
        self.command = command
        self.arguments = arguments
        self.openInTerminal = openInTerminal
        self.bundleID = bundleID
        self.url = url
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decode(LaunchType.self, forKey: .type)
        self.command = try c.decodeIfPresent(String.self, forKey: .command)
        self.arguments = try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
        self.openInTerminal = try c.decodeIfPresent(Bool.self, forKey: .openInTerminal) ?? false
        self.bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID)
        self.url = try c.decodeIfPresent(URL.self, forKey: .url)
    }
}
