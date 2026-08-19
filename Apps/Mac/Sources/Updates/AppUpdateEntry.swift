import Foundation

/// What the Settings / menu-bar update control should do when the user clicks it.
public enum AppUpdateAction: Equatable, Sendable {
    /// Start or retry a Sparkle check (may download and install).
    case check
    /// Finish a downloaded update that is waiting for an explicit install.
    case confirmInstall
}

/// Shared Settings / menu-bar / app-menu presentation for Sparkle app updates.
/// Tool updates never reuse these keys or this guard.
public struct AppUpdateEntry: Equatable, Sendable {
    public let showsCheckUpdate: Bool
    public let canStartCheck: Bool
    public let titleKey: String
    public let isEnabled: Bool
    public let action: AppUpdateAction
    public let systemImage: String

    public init(
        showsCheckUpdate: Bool,
        canStartCheck: Bool,
        titleKey: String,
        isEnabled: Bool,
        action: AppUpdateAction = .check,
        systemImage: String = "arrow.triangle.2.circlepath"
    ) {
        self.showsCheckUpdate = showsCheckUpdate
        self.canStartCheck = canStartCheck
        self.titleKey = titleKey
        self.isEnabled = isEnabled
        self.action = action
        self.systemImage = systemImage
    }

    /// Settings always exposes a primary update action, including idle / upToDate / failed.
    public static func forSettings(_ state: UpdateState) -> AppUpdateEntry {
        make(
            state: state,
            checkTitleKey: "settings.update.check",
            installNowTitleKey: "settings.update.installNow",
            installTitleKey: "settings.update.installAndRelaunch"
        )
    }

    /// Menu bar always exposes an update action, including idle.
    public static func forMenuBar(_ state: UpdateState) -> AppUpdateEntry {
        make(
            state: state,
            checkTitleKey: "menubar.checkForUpdates",
            installNowTitleKey: "menubar.installNow",
            installTitleKey: "menubar.installAndRelaunch"
        )
    }

    private static func make(
        state: UpdateState,
        checkTitleKey: String,
        installNowTitleKey: String,
        installTitleKey: String
    ) -> AppUpdateEntry {
        let canStart = AppUpdateCheckGuard.canStartCheck(state)
        switch state {
        case .readyToInstall:
            return AppUpdateEntry(
                showsCheckUpdate: true,
                canStartCheck: canStart,
                titleKey: installTitleKey,
                isEnabled: canStart,
                action: .confirmInstall,
                systemImage: "arrow.up.circle.fill"
            )
        case .available:
            return AppUpdateEntry(
                showsCheckUpdate: true,
                canStartCheck: canStart,
                titleKey: installNowTitleKey,
                isEnabled: canStart,
                action: .check,
                systemImage: "arrow.down.circle.fill"
            )
        default:
            return AppUpdateEntry(
                showsCheckUpdate: true,
                canStartCheck: canStart,
                titleKey: checkTitleKey,
                isEnabled: canStart,
                action: .check,
                systemImage: "arrow.triangle.2.circlepath"
            )
        }
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
