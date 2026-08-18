import XCTest
import Foundation
@testable import Persistence

final class AppPreferencesTests: XCTestCase {
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("prefs-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testMissingFileCreatesDefault() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = AppPreferencesStore(directory: dir)
        let result = await store.recoverIfNeeded()
        guard case .createdDefault(let doc) = result else {
            return XCTFail("expected createdDefault, got \(result)")
        }
        XCTAssertEqual(doc.schemaVersion, AppPreferencesDocument.currentSchemaVersion)
        XCTAssertFalse(doc.hasCompletedOnboarding)
        XCTAssertNil(doc.lastAcknowledgedCrashAt)
    }

    func testV1DocumentMigratesToV2() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("preferences.json")
        let v1 = """
        {"hasCompletedOnboarding":true}
        """.data(using: .utf8)!
        try v1.write(to: url)
        let store = AppPreferencesStore(directory: dir)
        let result = await store.recoverIfNeeded()
        guard case .migrated(let from, let doc) = result else {
            return XCTFail("expected migrated, got \(result)")
        }
        XCTAssertEqual(from, 1)
        XCTAssertEqual(doc.schemaVersion, 2)
        XCTAssertTrue(doc.hasCompletedOnboarding)
    }

    func testCorruptJSONIsBackedUpAndReset() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("preferences.json")
        try Data("{not-json".utf8).write(to: url)
        let store = AppPreferencesStore(directory: dir)
        let result = await store.recoverIfNeeded()
        guard case .recoveredFromCorruption(let backup) = result else {
            return XCTFail("expected recoveredFromCorruption, got \(result)")
        }
        XCTAssertTrue(backup.contains("preferences.json.corrupt-"))
        let backupURL = dir.appendingPathComponent(backup)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        let loaded = await store.load()
        XCTAssertFalse(loaded.hasCompletedOnboarding)
        XCTAssertEqual(loaded.schemaVersion, 2)
    }

    func testSaveRoundTrip() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = AppPreferencesStore(directory: dir)
        _ = await store.recoverIfNeeded()
        var doc = AppPreferencesDocument.default
        doc.hasCompletedOnboarding = true
        doc.lastAcknowledgedCrashAt = Date(timeIntervalSince1970: 1_700_000_000)
        try await store.save(doc)
        let store2 = AppPreferencesStore(directory: dir)
        let loaded = await store2.load()
        XCTAssertTrue(loaded.hasCompletedOnboarding)
        XCTAssertEqual(loaded.lastAcknowledgedCrashAt, doc.lastAcknowledgedCrashAt)
        XCTAssertEqual(loaded.schemaVersion, 2)
    }
}
