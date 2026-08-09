import AppKit
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        applyAppearance()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItem = nil
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
