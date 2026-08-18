import XCTest
import Foundation
@testable import ProcessExecution

final class CrashRecoveryTests: XCTestCase {
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("crash-rec-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testEmptyDirectoryHasNoCrash() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let status = CrashRecovery.status(directory: dir, acknowledgedAt: nil)
        XCTAssertNil(status.lastCrashAt)
        XCTAssertEqual(status.unacknowledgedCount, 0)
        XCTAssertEqual(status.directory, dir)
    }

    func testUnacknowledgedCrashIsCounted() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let ts: TimeInterval = 1_700_000_100
        let url = dir.appendingPathComponent("crash-\(Int(ts))-abc123.json")
        try Data("{}".utf8).write(to: url)
        let status = CrashRecovery.status(directory: dir, acknowledgedAt: nil)
        XCTAssertEqual(status.unacknowledgedCount, 1)
        XCTAssertEqual(status.lastCrashAt, Date(timeIntervalSince1970: ts))
    }

    func testAcknowledgedCrashIsIgnored() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let ts: TimeInterval = 1_700_000_100
        try Data("{}".utf8).write(to: dir.appendingPathComponent("crash-\(Int(ts))-abc123.json"))
        let status = CrashRecovery.status(
            directory: dir,
            acknowledgedAt: Date(timeIntervalSince1970: ts + 10)
        )
        XCTAssertEqual(status.unacknowledgedCount, 0)
        XCTAssertEqual(status.lastCrashAt, Date(timeIntervalSince1970: ts))
    }
}
