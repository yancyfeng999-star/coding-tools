import Foundation

// MARK: - UpdateState
//
// 状态机：覆盖一次更新检查的全生命周期。
// UI（SettingsView / MenuBar）订阅 `UpdateObserver` 拿到 emit，自行渲染。
//
// 阶段 7+ 完善：替代 SPUStandardUserDriver 的弹窗。
public enum UpdateState: Equatable, Sendable {
    /// 启动后 / 用户未触发检查
    case idle
    /// 拉 appcast 中
    case checking
    /// 已是最新（remoteVersion 用来在 UI 显示「已是最新 v1.0.1」）
    case upToDate(remoteVersion: String)
    /// 找到新版本；size 来自 appcast 的 <enclosure length>
    case available(remoteVersion: String, remoteBuild: Int, size: Int64)
    /// 下载中（progress 0.0 - 1.0）
    case downloading(progress: Double, bytesDownloaded: Int64, totalBytes: Int64)
    /// 解压中（progress 0.0 - 1.0；.pkg 安装包没有此步）
    case extracting(progress: Double)
    /// 下载/解压完成，等用户点安装
    case readyToInstall(remoteVersion: String)
    /// 安装中（quit + Installer.app 接管）
    case installing
    /// 安装完成（relaunched = Sparkle 是否已自动重启）
    case installed(relaunched: Bool)
    /// 出错（reason 用户可读；code 是 SUSparkleErrorDomain code）
    case failed(reason: String, code: Int?)

    public var isBusy: Bool {
        switch self {
        case .checking, .downloading, .extracting, .installing: return true
        default: return false
        }
    }

    /// 简短中文/英文标签：UI 直接显示
    public var statusTextKey: String {
        switch self {
        case .idle:                       return "updates.state.idle"
        case .checking:                   return "updates.state.checking"
        case .upToDate:                   return "updates.state.upToDate"
        case .available:                  return "updates.state.available"
        case .downloading:                return "updates.state.downloading"
        case .extracting:                 return "updates.state.extracting"
        case .readyToInstall:             return "updates.state.readyToInstall"
        case .installing:                 return "updates.state.installing"
        case .installed:                  return "updates.state.installed"
        case .failed:                     return "updates.state.failed"
        }
    }
}

// MARK: - UpdateObserver
//
// UI 端（AppState、SettingsView、MenuBar）实现这个协议接收状态变化。
@MainActor
public protocol UpdateObserver: AnyObject {
    func updateStateChanged(_ state: UpdateState)
    /// Sparkle 找到新版本时同时返回元数据（让 UI 可以显示「本地 X / 最新 Y / 大小 Z」）
    func updateMetadata(localVersion: String, localBuild: Int)
}

// MARK: - UpdateFlowModel
//
// 状态聚合器：单例/共享。一个进程内只有一个 user driver，所以只需一个 model。
@MainActor
public final class UpdateFlowModel {
    public private(set) var state: UpdateState = .idle {
        didSet { notify() }
    }
    public private(set) var localVersion: String = ""
    public private(set) var localBuild: Int = 0

    private var observers: [WeakBox] = []
    private var pendingReply: ((UpdateDecision) -> Void)?

    public enum UpdateDecision: Sendable {
        case install
        case dismiss
        case skip
    }

    public init() {
        let info = Bundle.main.infoDictionary
        localVersion = (info?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
        localBuild = Int((info?["CFBundleVersion"] as? String) ?? "0") ?? 0
    }

    public func addObserver(_ observer: UpdateObserver) {
        observers.append(WeakBox(observer))
        // 立即同步一次当前状态
        observer.updateStateChanged(state)
        observer.updateMetadata(localVersion: localVersion, localBuild: localBuild)
    }

    public func transition(_ newState: UpdateState) {
        state = newState
    }

    /// True while Sparkle is waiting for an explicit install / dismiss / skip.
    public var hasPendingReply: Bool { pendingReply != nil }

    /// 记录 Sparkle 等待用户决策的回调；当 UI 点「安装」时调 `fulfillDecision(.install)`
    public func setPendingReply(_ reply: @escaping (UpdateDecision) -> Void) {
        self.pendingReply = reply
    }

    public func fulfillDecision(_ decision: UpdateDecision) {
        let reply = pendingReply
        pendingReply = nil
        reply?(decision)
    }

    private func notify() {
        // 清掉已被释放的 observer
        observers.removeAll { $0.value == nil }
        observers.forEach { $0.value?.updateStateChanged(state) }
    }
}

private struct WeakBox {
    weak var value: (any UpdateObserver)?
    init(_ v: any UpdateObserver) { self.value = v }
}
