import Foundation

/// Shared Settings / menu-bar / app-menu presentation for Sparkle app updates.
/// Tool updates never reuse these keys or this guard.
public struct AppUpdateEntry: Equatable, Sendable {
    public let showsCheckUpdate: Bool
    public let canStartCheck: Bool
    public let titleKey: String
    public let isEnabled: Bool

    public init(showsCheckUpdate: Bool, canStartCheck: Bool, titleKey: String, isEnabled: Bool) {
        self.showsCheckUpdate = showsCheckUpdate
        self.canStartCheck = canStartCheck
        self.titleKey = titleKey
        self.isEnabled = isEnabled
    }

    /// Settings always exposes 检查更新, including idle / upToDate / failed.
    public static func forSettings(_ state: UpdateState) -> AppUpdateEntry {
        make(state: state, titleKey: "settings.update.check")
    }

    /// Menu bar always exposes 检查更新, including idle.
    public static func forMenuBar(_ state: UpdateState) -> AppUpdateEntry {
        make(state: state, titleKey: "menubar.checkForUpdates")
    }

    private static func make(state: UpdateState, titleKey: String) -> AppUpdateEntry {
        let canStart = AppUpdateCheckGuard.canStartCheck(state)
        return AppUpdateEntry(
            showsCheckUpdate: true,
            canStartCheck: canStart,
            titleKey: titleKey,
            isEnabled: canStart
        )
    }
}

public enum AppUpdateCheckGuard {
    /// A check already in flight (or a download/install) cannot start a second check.
    public static func canStartCheck(_ state: UpdateState) -> Bool {
        switch state {
        case .checking, .downloading, .extracting, .installing:
            return false
        case .idle, .upToDate, .available, .readyToInstall, .installed, .failed:
            return true
        }
    }
}
