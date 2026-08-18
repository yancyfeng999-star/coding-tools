import XCTest
@testable import Updates

@MainActor
final class MockUpdaterBackend: UpdaterBackend {
    var automaticallyChecksForUpdates: Bool = false
    var automaticallyDownloadsUpdates: Bool = false
    private(set) var checkForUpdatesCallCount: Int = 0

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }
}

@MainActor
final class NoOpAppUpdaterTests: XCTestCase {
    func testCheckForUpdatesIncrementsCounter() {
        let updater = NoOpAppUpdater()
        XCTAssertEqual(updater.checkCount, 0)
        updater.checkForUpdates()
        updater.checkForUpdates()
        XCTAssertEqual(updater.checkCount, 2)
    }

    func testDefaultsAreDisabled() {
        let updater = NoOpAppUpdater()
        XCTAssertFalse(updater.isAutomaticChecksEnabled)
        XCTAssertFalse(updater.isAutomaticDownloadEnabled)
    }

    func testSetAutomaticChecksEnabledPersists() {
        let updater = NoOpAppUpdater()
        updater.setAutomaticChecksEnabled(false)
        XCTAssertFalse(updater.isAutomaticChecksEnabled)
        updater.setAutomaticChecksEnabled(true)
        XCTAssertTrue(updater.isAutomaticChecksEnabled)
    }

    func testSetAutomaticDownloadEnabledPersists() {
        let updater = NoOpAppUpdater()
        updater.setAutomaticDownloadEnabled(false)
        XCTAssertFalse(updater.isAutomaticDownloadEnabled)
    }
}

@MainActor
final class SparkleAppUpdaterTests: XCTestCase {
    func testCheckForUpdatesDelegatesToBackend() {
        let backend = MockUpdaterBackend()
        let updater = SparkleAppUpdater(backend: backend)
        updater.checkForUpdates()
        XCTAssertEqual(backend.checkForUpdatesCallCount, 1)
    }

    func testSetAutomaticChecksEnabledWritesBackend() {
        let backend = MockUpdaterBackend()
        let updater = SparkleAppUpdater(backend: backend)
        updater.setAutomaticChecksEnabled(false)
        XCTAssertFalse(backend.automaticallyChecksForUpdates)
        XCTAssertFalse(updater.isAutomaticChecksEnabled)
    }

    func testSetAutomaticDownloadEnabledWritesBackend() {
        let backend = MockUpdaterBackend()
        let updater = SparkleAppUpdater(backend: backend)
        updater.setAutomaticDownloadEnabled(true)
        XCTAssertTrue(backend.automaticallyDownloadsUpdates)
        XCTAssertTrue(updater.isAutomaticDownloadEnabled)
    }

    func testReadsCurrentBackendState() {
        let backend = MockUpdaterBackend()
        backend.automaticallyChecksForUpdates = false
        backend.automaticallyDownloadsUpdates = true
        let updater = SparkleAppUpdater(backend: backend)
        XCTAssertFalse(updater.isAutomaticChecksEnabled)
        XCTAssertTrue(updater.isAutomaticDownloadEnabled)
    }
}

@MainActor
final class MockUpdaterBackendTests: XCTestCase {
    func testDefaultStateMatchesManualUpdatePolicy() {
        let backend = MockUpdaterBackend()
        XCTAssertFalse(backend.automaticallyChecksForUpdates)
        XCTAssertFalse(backend.automaticallyDownloadsUpdates)
    }

    func testTogglingFlags() {
        let backend = MockUpdaterBackend()
        backend.automaticallyChecksForUpdates = false
        backend.automaticallyDownloadsUpdates = true
        XCTAssertFalse(backend.automaticallyChecksForUpdates)
        XCTAssertTrue(backend.automaticallyDownloadsUpdates)
    }
}
