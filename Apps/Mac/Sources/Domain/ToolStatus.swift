import Foundation

// MARK: - ToolStatus

public enum ToolStatus: String, Hashable, Sendable, Codable {
    case active
    case deprecated
    case experimental
}
