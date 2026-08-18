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
//   SparkleAppUpdater ← 默认实现（持有 UpdaterBackend）
//        ↓
//   UpdaterBackend  ← 内部协议（可被 mock）
//        ↑
//   SPUUpdaterBackend ← 包装 SPUUpdater（生产路径）
//
// 阶段 7 由子代理 C 完整接入。

/// Manual-only app updates. Sparkle must not schedule checks or install
/// unless the user clicked 检查更新.
public enum UpdateUserDriverPolicy {
    public static let automaticChecksEnabled = false
    public static let automaticDownloadsEnabled = false
    public static let permissionAllowsAutomaticChecks = false
    public static let installWhenUpdateFound = true
    public static let installAndRelaunchWhenReady = true

    public static func shouldRetryTermination(applicationTerminated: Bool) -> Bool {
        !applicationTerminated
    }
}

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

/// 内部协议：把 Sparkle `SPUUpdater` 抽象成可 mock 的接口。
/// 测试可用 `MockUpdaterBackend` 注入，避开真实 Sparkle。
@MainActor
public protocol UpdaterBackend: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }
    func checkForUpdates()
}

/// 默认 `AppUpdating` 实现：委托给 `UpdaterBackend`。
@MainActor
public final class SparkleAppUpdater: AppUpdating {
    private let backend: UpdaterBackend

    public init(backend: UpdaterBackend) {
        self.backend = backend
    }

    public var isAutomaticChecksEnabled: Bool { backend.automaticallyChecksForUpdates }
    public var isAutomaticDownloadEnabled: Bool { backend.automaticallyDownloadsUpdates }

    public func checkForUpdates() {
        backend.checkForUpdates()
    }

    public func setAutomaticChecksEnabled(_ enabled: Bool) {
        backend.automaticallyChecksForUpdates = enabled
    }

    public func setAutomaticDownloadEnabled(_ enabled: Bool) {
        backend.automaticallyDownloadsUpdates = enabled
    }
}

/// 生产路径：把 `SPUUpdater` 适配成 `UpdaterBackend`。
@MainActor
public final class SPUUpdaterBackend: UpdaterBackend {
    private let updater: SPUUpdater

    public init(updater: SPUUpdater) {
        self.updater = updater
    }

    public var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    public var automaticallyDownloadsUpdates: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set { updater.automaticallyDownloadsUpdates = newValue }
    }

    public func checkForUpdates() {
        updater.checkForUpdates()
    }
}

/// 空实现：用于 SwiftUI previews、UI 测试、`AppModel` 单元测试。
@MainActor
public final class NoOpAppUpdater: AppUpdating {
    public private(set) var checkCount: Int = 0
    public private(set) var automaticChecksEnabled: Bool = UpdateUserDriverPolicy.automaticChecksEnabled
    public private(set) var automaticDownloadEnabled: Bool = UpdateUserDriverPolicy.automaticDownloadsEnabled

    public init() {}

    public var isAutomaticChecksEnabled: Bool { automaticChecksEnabled }
    public var isAutomaticDownloadEnabled: Bool { automaticDownloadEnabled }

    public func checkForUpdates() { checkCount += 1 }
    public func setAutomaticChecksEnabled(_ enabled: Bool) { automaticChecksEnabled = enabled }
    public func setAutomaticDownloadEnabled(_ enabled: Bool) { automaticDownloadEnabled = enabled }
}
