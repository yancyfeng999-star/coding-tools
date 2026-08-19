import XCTest
@testable import Updates

final class AppUpdateEntryTests: XCTestCase {
    func testSettingsExposesCheckWhenIdle() {
        let entry = AppUpdateEntry.forSettings(.idle)
        XCTAssertTrue(entry.showsCheckUpdate)
        XCTAssertTrue(entry.canStartCheck)
        XCTAssertEqual(entry.titleKey, "settings.update.check")
    }

    func testSettingsExposesCheckWhenUpToDate() {
        let entry = AppUpdateEntry.forSettings(.upToDate(remoteVersion: "1.5.0"))
        XCTAssertTrue(entry.showsCheckUpdate)
        XCTAssertTrue(entry.canStartCheck)
    }

    func testSettingsExposesCheckWhenFailed() {
        let entry = AppUpdateEntry.forSettings(.failed(reason: "network", code: 1))
        XCTAssertTrue(entry.showsCheckUpdate)
        XCTAssertTrue(entry.canStartCheck)
    }

    func testMenuBarExposesCheckWhenIdle() {
        let entry = AppUpdateEntry.forMenuBar(.idle)
        XCTAssertTrue(entry.showsCheckUpdate)
        XCTAssertTrue(entry.canStartCheck)
        XCTAssertEqual(entry.titleKey, "menubar.checkForUpdates")
    }

    func testMenuBarExposesCheckWhenUpToDateAndFailed() {
        XCTAssertTrue(AppUpdateEntry.forMenuBar(.upToDate(remoteVersion: "1.0.0")).showsCheckUpdate)
        XCTAssertTrue(AppUpdateEntry.forMenuBar(.failed(reason: "x", code: nil)).showsCheckUpdate)
    }

    func testCheckingDisablesASecondCheck() {
        XCTAssertFalse(AppUpdateCheckGuard.canStartCheck(.checking))
        XCTAssertFalse(AppUpdateEntry.forSettings(.checking).canStartCheck)
        XCTAssertFalse(AppUpdateEntry.forMenuBar(.checking).isEnabled)
    }

    func testDownloadingAndInstallingAreInFlight() {
        XCTAssertFalse(AppUpdateCheckGuard.canStartCheck(.downloading(progress: 0.2, bytesDownloaded: 1, totalBytes: 10)))
        XCTAssertFalse(AppUpdateCheckGuard.canStartCheck(.extracting(progress: 0.5)))
        XCTAssertFalse(AppUpdateCheckGuard.canStartCheck(.installing))
    }

    func testSettingsReadyToInstallConfirmsInstall() {
        let entry = AppUpdateEntry.forSettings(.readyToInstall(remoteVersion: "1.5.7"))
        XCTAssertEqual(entry.action, .confirmInstall)
        XCTAssertEqual(entry.titleKey, "settings.update.installAndRelaunch")
    }

    func testSettingsReadyToInstallUsesInstallAction() {
        let entry = AppUpdateEntry.forSettings(.readyToInstall(remoteVersion: "1.5.5"))
        XCTAssertEqual(entry.action, .confirmInstall)
        XCTAssertEqual(entry.titleKey, "settings.update.installAndRelaunch")
        XCTAssertTrue(entry.showsCheckUpdate)
        XCTAssertTrue(entry.isEnabled)
    }

    func testSettingsAvailableUsesInstallNowAndCheckAction() {
        let entry = AppUpdateEntry.forSettings(
            .available(remoteVersion: "1.5.5", remoteBuild: 28, size: 1024)
        )
        XCTAssertEqual(entry.action, .check)
        XCTAssertEqual(entry.titleKey, "settings.update.installNow")
        XCTAssertTrue(entry.isEnabled)
    }

    func testMenuBarReadyToInstallUsesInstallAction() {
        let entry = AppUpdateEntry.forMenuBar(.readyToInstall(remoteVersion: "—"))
        XCTAssertEqual(entry.action, .confirmInstall)
        XCTAssertEqual(entry.titleKey, "menubar.installAndRelaunch")
        XCTAssertTrue(entry.isEnabled)
    }

    func testStatusPresentationKeepsArgumentOutOfTheKey() {
        let empty = UpdateStatusPresentation.settings(for: .readyToInstall(remoteVersion: ""))
        XCTAssertEqual(empty.key, "settings.update.status.readyToInstall")
        XCTAssertEqual(empty.argument, "—")
        XCTAssertFalse(empty.key.contains("—"))
        XCTAssertFalse(empty.key.contains(" "))

        let dash = UpdateStatusPresentation.settings(for: .readyToInstall(remoteVersion: "—"))
        XCTAssertEqual(dash.key, "settings.update.status.readyToInstall")
        XCTAssertEqual(dash.argument, "—")

        let named = UpdateStatusPresentation.settings(for: .upToDate(remoteVersion: "1.5.5"))
        XCTAssertEqual(named.key, "settings.update.status.upToDate")
        XCTAssertEqual(named.argument, "1.5.5")
    }
}

final class UpdateUserDriverPolicyTests: XCTestCase {
    func testNeverSchedulesAutomaticChecksOrDownloads() {
        XCTAssertFalse(UpdateUserDriverPolicy.automaticChecksEnabled)
        XCTAssertFalse(UpdateUserDriverPolicy.automaticDownloadsEnabled)
        XCTAssertFalse(UpdateUserDriverPolicy.permissionAllowsAutomaticChecks)
    }

    func testUserInitiatedCheckInstallsAndRelaunchesWhenReady() {
        XCTAssertTrue(UpdateUserDriverPolicy.installWhenUpdateFound)
        XCTAssertTrue(UpdateUserDriverPolicy.installAndRelaunchWhenReady)
        XCTAssertTrue(UpdateUserDriverPolicy.shouldRetryTermination(applicationTerminated: false))
        XCTAssertFalse(UpdateUserDriverPolicy.shouldRetryTermination(applicationTerminated: true))
    }
}

@MainActor
final class AppUpdateCheckGuardIntegrationTests: XCTestCase {
    func testSparkleUpdaterStillDelegatesWhenCalledDirectly() {
        let backend = MockUpdaterBackend()
        let updater = SparkleAppUpdater(backend: backend)
        updater.checkForUpdates()
        XCTAssertEqual(backend.checkForUpdatesCallCount, 1)
    }
}
