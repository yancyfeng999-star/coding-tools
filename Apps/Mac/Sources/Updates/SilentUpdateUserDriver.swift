import Foundation
import Sparkle

// MARK: - SilentUpdateUserDriver
//
// 实现 SPUUserDriver 协议；**不弹窗**，把状态 emit 到 UpdateFlowModel。
// 让 AppDelegate 把它作为 `userDriverDelegate` 传给 SPUStandardUpdaterController。
//
// 设计取舍：
// - 收到 "showUpdateFound..." 时立即 reply(.install) —— 不等用户点（因为 UI 已经在监听，
//   UI 自己的「下载并安装」按钮通过 `updateStateChanged` 路径触发的就是这次更新。
//   自动模式：Sparkle 找到新版本 → userDriver 自动同意安装 → 进度回调驱动 UI。
// - 收到 "showReadyToInstallAndRelaunch" 时暂存 reply，等 UI 显式发 .install 再继续。
//   实际流程：Sparkle 下载完成 → 提示「准备好」 → UI 显示「点击重启安装」→ 用户点 → reply。
@MainActor
public final class SilentUpdateUserDriver: NSObject, SPUUserDriver {

    private weak var model: UpdateFlowModel?
    private var bytesReceived: UInt64 = 0
    private var expectedContentLength: UInt64 = 0

    public init(model: UpdateFlowModel) {
        self.model = model
        super.init()
    }

    // MARK: SPUUserDriver

    public func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        // 自动同意所有权限请求（settings 默认值）
        let response = SUUpdatePermissionResponse(
            automaticUpdateChecks: true,
            sendSystemProfile: false
        )
        reply(response)
    }

    public func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        model?.transition(.checking)
    }

    public func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // 找到新版本：emit available + 自动 install（如果是 NotDownloaded）
        let remoteVersion = appcastItem.displayVersionString
        let remoteBuild = Int(appcastItem.versionString) ?? 0
        let size = Int64(appcastItem.contentLength)
        model?.transition(.available(remoteVersion: remoteVersion, remoteBuild: remoteBuild, size: size))

        // 重置进度
        bytesReceived = 0
        expectedContentLength = 0

        // 立即同意安装（流程会走 download → extract → readyToInstall）
        // Sparkle 会根据 state.stage 走 download / install
        reply(.install)
    }

    public func showUpdateReleaseNotes(with data: SPUDownloadData) {
        // 不弹窗；release notes 由 UI 在「更新」section 自取（暂未实现）
        // 留个 hook，未来 AppState 可以缓存 latestReleaseNotes
        _ = data
    }

    public func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
        _ = error // 不弹窗
    }

    public func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        // SPUNoUpdateFoundReason 在 Swift 里是 Int rawValue，直接 cast
        let ns = error as NSError
        let remote = latestKnownRemoteVersion() ?? "—"
        // 找不到也走 upToDate（不是 error）。错误由 showUpdaterError 单独处理。
        model?.transition(.upToDate(remoteVersion: remote))
        _ = ns // 不解析 reason：UI 统一显示「已是最新」
        acknowledgement()
    }

    public func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let ns = error as NSError
        let reason = ns.localizedDescription
        model?.transition(.failed(reason: reason, code: ns.code))
        acknowledgement()
    }

    public func showDownloadInitiated(cancellation: @escaping () -> Void) {
        // 进度 0
        model?.transition(.downloading(progress: 0, bytesDownloaded: 0, totalBytes: Int64(expectedContentLength)))
    }

    public func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        self.expectedContentLength = expectedContentLength
    }

    public func showDownloadDidReceiveData(ofLength length: UInt64) {
        bytesReceived += length
        let progress = expectedContentLength > 0
            ? min(1.0, Double(bytesReceived) / Double(expectedContentLength))
            : 0
        model?.transition(.downloading(progress: progress, bytesDownloaded: Int64(bytesReceived), totalBytes: Int64(expectedContentLength)))
    }

    public func showDownloadDidStartExtractingUpdate() {
        // .pkg 安装包不进 extracting；这里我们仍然 emit 0
        model?.transition(.extracting(progress: 0))
    }

    public func showExtractionReceivedProgress(_ progress: Double) {
        model?.transition(.extracting(progress: progress))
    }

    public func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // 暂存 reply；UI 主动调用 fulfillInstall() 才会继续
        model?.setPendingReply { decision in
            switch decision {
            case .install: reply(.install)
            case .dismiss: reply(.dismiss)
            case .skip:    reply(.skip)
            }
        }
        let remote = latestKnownRemoteVersion() ?? "—"
        model?.transition(.readyToInstall(remoteVersion: remote))
    }

    public func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        model?.transition(.installing)
    }

    public func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        model?.transition(.installed(relaunched: relaunched))
        acknowledgement()
    }

    public func dismissUpdateInstallation() {
        // 用户在 Settings 点「取消」或 reset：回到 idle
        bytesReceived = 0
        expectedContentLength = 0
        model?.transition(.idle)
    }

    // MARK: Helpers

    /// 从上一次 known state 推断 remoteVersion；不持久化
    private func latestKnownRemoteVersion() -> String? {
        switch model?.state {
        case .available(let v, _, _)?: return v
        case .readyToInstall(let v)?: return v
        default: return nil
        }
    }
}

// MARK: - 桥接到 UpdateFlowModel 的 UpdateDecision
extension UpdateFlowModel.UpdateDecision {
    public static func from(sparkle choice: SPUUserUpdateChoice) -> Self {
        switch choice {
        case .install: return .install
        case .dismiss: return .dismiss
        case .skip:    return .skip
        @unknown default: return .dismiss
        }
    }
}
