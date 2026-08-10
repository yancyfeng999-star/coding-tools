import Foundation
import Sparkle

// MARK: - Updates
//
// Sparkle 2 集成：EdDSA 签名 + HTTPS Appcast + GitHub Releases。
// 完整定义见 docs/RELEASE_WORKFLOW.md 与 docs/SECURITY_MODEL.md §5。
//
// 架构：
//   AppUpdating  ← 公开协议（UI / Settings 调用）
//        ↑
//   SparkleAppUpdater ← 默认实现
//        ↓
//   UpdaterBackend  ← 内部协议（可被 mock）
//        ↑
//   SparkleUpdaterBackend  ← 包 SPUStandardUpdaterController
//
// 阶段 7 由子代理 C 完整接入。

@MainActor
public protocol AppUpdating: AnyObject {
    /// 主动检查更新（"设置 → 检查更新" 触发，弹窗显示进度）。
    func checkForUpdates()

    /// 设置自动检查。
    func setAutomaticChecksEnabled(_ enabled: Bool)

    /// 设置自动下载。
    func setAutomaticDownloadEnabled(_ enabled: Bool)

    /// 当前自动检查状态。
    var isAutomaticChecksEnabled: Bool { get }

    /// 当前自动下载状态。
    var isAutomaticDownloadEnabled: Bool { get }
}

/// 默认 `AppUpdating` 实现：直接包装 SPUUpdater。
@MainActor
public final class SparkleAppUpdater: AppUpdating {
    private let updater: SPUUpdater

    public init(updater: SPUUpdater) {
        self.updater = updater
    }

    public var isAutomaticChecksEnabled: Bool { updater.automaticallyChecksForUpdates }
    public var isAutomaticDownloadEnabled: Bool { updater.automaticallyDownloadsUpdates }

    public func checkForUpdates() {
        updater.checkForUpdates()
    }

    public func setAutomaticChecksEnabled(_ enabled: Bool) {
        updater.automaticallyChecksForUpdates = enabled
    }

    public func setAutomaticDownloadEnabled(_ enabled: Bool) {
        updater.automaticallyDownloadsUpdates = enabled
    }
}

/// 空实现：用于 SwiftUI previews、UI 测试、`AppModel` 单元测试。
@MainActor
public final class NoOpAppUpdater: AppUpdating {
    public private(set) var checkCount: Int = 0
    public private(set) var automaticChecksEnabled: Bool = true
    public private(set) var automaticDownloadEnabled: Bool = true

    public init() {}

    public var isAutomaticChecksEnabled: Bool { automaticChecksEnabled }
    public var isAutomaticDownloadEnabled: Bool { automaticDownloadEnabled }

    public func checkForUpdates() { checkCount += 1 }
    public func setAutomaticChecksEnabled(_ enabled: Bool) { automaticChecksEnabled = enabled }
    public func setAutomaticDownloadEnabled(_ enabled: Bool) { automaticDownloadEnabled = enabled }
}
