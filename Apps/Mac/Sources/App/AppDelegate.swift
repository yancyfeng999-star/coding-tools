import AppKit
import Sparkle
import Updates

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    // 阶段 7：Sparkle 2 集成（EdDSA + HTTPS Appcast + GitHub Releases）
    // - 启动时 init（`updaterController` 在 init 构造，startingUpdater=false）
    // - applicationDidFinishLaunching 显式调用 startUpdater
    // - 设置项由 Sparkle 内部持久化到 UserDefaults
    // - 手动触发：UI 调用 `appUpdater.checkForUpdates()`（"设置 → 检查更新"）
    private let updaterController: SPUStandardUpdaterController

    /// 给 UI / AppModel 使用的更新门面。子代理 B 的设置页可直接调用。
    private(set) lazy var appUpdater: AppUpdating = {
        let backend = SparkleUpdaterBackend(controller: updaterController)
        return SparkleAppUpdater(backend: backend)
    }()

    override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        applyAppearance()
        startSparkleUpdater()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItem = nil
    }

    // MARK: - Sparkle

    /// 阶段 7：启动 Sparkle 调度循环（后台定时检查 + 安装提示）。
    /// Info.plist 配错（缺 SUFeedURL / SUPublicEDKey）时 Sparkle 会在数秒后弹窗提示用户。
    private func startSparkleUpdater() {
        // 触发 lazy init（确保 backend 在 startUpdater 之前已建好）
        _ = appUpdater
        #if DEBUG
        // dev build：暂跳过 Sparkle。SUPublicEDKey 还是占位符、SUFeedURL 指向的
        // GitHub Release 还没建，启动检查会必失败弹窗。v1.0.0 release 流程
        // （填真公钥 + 推 appcast）前都不启用。
        return
        #else
        updaterController.startUpdater()
        #endif
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        // Phase 1 占位：阶段 4 接入完整 MenuBarExtra
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "CT"
        }
        statusItem = item
    }

    private func applyAppearance() {
        // 阶段 6 接入 Theme 模块；此处仅占位
    }
}
