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
