import AppKit
import Sparkle
import Updates

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 进程内共享入口，给 SwiftUI 视图（SettingsView）调 `checkForUpdates()`。
    /// AppDelegate 在 NSApplicationDelegateAdaptor 启动时由系统构造并持有，
    /// 所以 weak 引用安全，进程生命周期内不会释放。
    static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem?

    // 阶段 7：Sparkle 2 集成（EdDSA + HTTPS Appcast + GitHub Releases）
    private let updater: SPUUpdater

    /// 更新流程状态机：让 Settings/MenuBar 订阅 emit（不弹窗）。
    let updateModel: UpdateFlowModel

    /// 给 UI / AppModel 使用的更新门面。子代理 B 的设置页可直接调用。
    private(set) lazy var appUpdater: AppUpdating = {
        SparkleAppUpdater(updater: updater)
    }()

    override init() {
        // 关键：直接用 SPUUpdater 才能注入自定义 userDriver。
        // SPUStandardUpdaterController 不支持 SPUUserDriver，只能挂 SPUStandardUserDriverDelegate。
        let model = UpdateFlowModel()
        self.updateModel = model
        let driver = SilentUpdateUserDriver(model: model)
        self.updater = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: driver,
            delegate: nil
        )
        super.init()
        Self.shared = self
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

    /// 启动 Sparkle 调度循环（后台定时检查 + 静默下载）。
    /// 静默策略：SUEnableAutomaticDownloading=true → 静默拉新包。
    /// 不弹窗：所有用户交互通过 SilentUpdateUserDriver emit 到 updateModel。
    private func startSparkleUpdater() {
        // 触发 lazy init（确保 appUpdater 在 start() 之前已建好）
        _ = appUpdater
        do {
            try updater.start()
        } catch {
            // SPUUpdater.start() 在已启动 / 配置错误时抛错；不致命，只是不自动调度
            NSLog("⚠️ Sparkle updater.start() failed: \(error)")
        }
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
