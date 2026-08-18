import XCTest
@testable import UI

final class CompatibilityCheckTests: XCTestCase {
    func testSupportedMacOSWithKeyIsHealthy() {
        let report = CompatibilityCheck.evaluate(
            majorVersion: 14,
            minimumMajor: 14,
            architecture: "arm64",
            sparklePublicKey: "Utj+cIsQE5MVs9tD2lId3s4zvzHnPgThFD1JebEfcEA=",
            catalogReady: true
        )
        XCTAssertTrue(report.macOSSupported)
        XCTAssertTrue(report.sparkleKeyPresent)
        XCTAssertTrue(report.catalogReady)
        XCTAssertTrue(report.isHealthy)
        XCTAssertEqual(report.architecture, "arm64")
        XCTAssertEqual(report.minimumMacOS, "14.0")
    }

    func testOldMacOSIsUnsupported() {
        let report = CompatibilityCheck.evaluate(
            majorVersion: 13,
            minimumMajor: 14,
            architecture: "x86_64",
            sparklePublicKey: "present",
            catalogReady: true
        )
        XCTAssertFalse(report.macOSSupported)
        XCTAssertFalse(report.isHealthy)
        XCTAssertEqual(report.currentMacOS, "13")
    }

    func testMissingSparkleKeyIsUnhealthy() {
        let report = CompatibilityCheck.evaluate(
            majorVersion: 15,
            minimumMajor: 14,
            architecture: "arm64",
            sparklePublicKey: "   ",
            catalogReady: false
        )
        XCTAssertTrue(report.macOSSupported)
        XCTAssertFalse(report.sparkleKeyPresent)
        XCTAssertFalse(report.catalogReady)
        XCTAssertFalse(report.isHealthy)
    }
}
