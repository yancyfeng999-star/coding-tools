import Foundation
import Domain

// MARK: - Detection
//
// 工具检测：版本检测、路径检测、架构检测。阶段 3 由子代理 A 实现。
// 数据契约（InstallationProbe / Architecture / HealthStatus）见 Domain 模块。

public protocol InstallationDetecting: Sendable {
    func probe(tool: Tool) async -> InstallationProbe
    func probeAll(tools: [Tool]) async -> [InstallationProbe]
}

public actor InstallationDetector: InstallationDetecting {
    public init() {}

    public func probe(tool: Tool) async -> InstallationProbe {
        // 阶段 3 占位
        InstallationProbe(
            toolID: tool.id,
            installedVersion: nil,
            detectedPath: nil,
            architecture: nil,
            healthStatus: .notInstalled
        )
    }

    public func probeAll(tools: [Tool]) async -> [InstallationProbe] {
        await withTaskGroup(of: InstallationProbe.self) { group in
            for tool in tools {
                group.addTask { await self.probe(tool: tool) }
            }
            var result: [InstallationProbe] = []
            for await probe in group {
                result.append(probe)
            }
            return result
        }
    }
}
