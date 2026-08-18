import Foundation
import Domain

public struct BulkToolUpdateItem: Identifiable, Equatable, Sendable {
    public let tool: Tool
    public let option: InstallOption
    public let localVersion: String
    public let targetVersion: String
    public var id: String { tool.id }

    public init(tool: Tool, option: InstallOption, localVersion: String, targetVersion: String) {
        self.tool = tool
        self.option = option
        self.localVersion = localVersion
        self.targetVersion = targetVersion
    }
}

public enum BulkToolUpdateItemState: Equatable, Sendable {
    case pending
    case running
    case completed
    case failed(String)
    case skipped
}

public struct BulkToolUpdateState: Equatable, Sendable {
    public var itemStates: [String: BulkToolUpdateItemState]

    public init(itemStates: [String: BulkToolUpdateItemState] = [:]) {
        self.itemStates = itemStates
    }

    public var completedCount: Int {
        itemStates.values.filter { $0 == .completed }.count
    }

    public var failedCount: Int {
        itemStates.values.filter {
            if case .failed = $0 { return true }
            return false
        }.count
    }
}

public enum BulkToolUpdatePlanner {
    public static func makeItems(
        tools: [Tool],
        presentations: [String: ToolPresentation]
    ) -> [BulkToolUpdateItem] {
        tools.compactMap { tool in
            guard let presentation = presentations[tool.id] else { return nil }
            guard case .update(let target) = presentation.primaryAction else { return nil }
            guard let option = InstallConfirmation.resolvedOption(tool: tool) else { return nil }
            guard (try? option.toInstallAction()) != nil else { return nil }
            let local: String
            if case .updateAvailable(let value, _) = presentation.status {
                local = value
            } else if case .known(let value) = presentation.localDisplay {
                local = value
            } else {
                local = ""
            }
            return BulkToolUpdateItem(
                tool: tool,
                option: option,
                localVersion: local,
                targetVersion: target
            )
        }
    }
}
