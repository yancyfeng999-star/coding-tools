import Foundation
import Sparkle

// MARK: - Updates
//
// Sparkle 2 集成：EdDSA 签名 + HTTPS Appcast + GitHub Releases。
// 完整定义见 docs/RELEASE_WORKFLOW.md 与 docs/SECURITY_MODEL.md §5。
// 阶段 7 由子代理 C 接入；阶段 1 仅占位 API。

@MainActor
public protocol AppUpdating: AnyObject {
    func checkForUpdates()
    func setAutomaticChecksEnabled(_ enabled: Bool)
    func setAutomaticDownloadEnabled(_ enabled: Bool)
}

@MainActor
public final class SparkleAppUpdater: AppUpdating {
    private let controller: SPUStandardUpdaterController

    public init(controller: SPUStandardUpdaterController) {
        self.controller = controller
    }

    public func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    public func setAutomaticChecksEnabled(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    public func setAutomaticDownloadEnabled(_ enabled: Bool) {
        controller.updater.automaticallyDownloadsUpdates = enabled
    }
}
