import XCTest
import Foundation
@testable import Persistence

final class UserDataPortableTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let export = UserDataPortable.make(
            favorites: ["git", "nodejs"],
            recents: ["git"],
            theme: "system",
            language: "zh-Hans",
            autoCheckUpdates: true,
            autoDownloadUpdates: false,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try UserDataPortable.encode(export)
        let decoded = try UserDataPortable.decode(data)
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.favorites, ["git", "nodejs"])
        XCTAssertEqual(decoded.recents, ["git"])
        XCTAssertEqual(decoded.theme, "system")
        XCTAssertEqual(decoded.language, "zh-Hans")
        XCTAssertTrue(decoded.autoCheckUpdates)
        XCTAssertFalse(decoded.autoDownloadUpdates)
        XCTAssertFalse(UserDataPortable.containsForbiddenPayload(data))
    }

    func testRejectsHomePathAndTokens() {
        let home = #"{"formatVersion":1,"favorites":[],"recents":[],"theme":"light","language":"en","autoCheckUpdates":true,"autoDownloadUpdates":false,"note":"/Users/yancyfeng/secret"}"#
        XCTAssertTrue(UserDataPortable.containsForbiddenPayload(Data(home.utf8)))
        let token = #"{"formatVersion":1,"token":"sk-abc","favorites":[],"recents":[],"theme":"light","language":"en","autoCheckUpdates":true,"autoDownloadUpdates":false}"#
        XCTAssertTrue(UserDataPortable.containsForbiddenPayload(Data(token.utf8)))
        let pathEnv = #"{"formatVersion":1,"PATH":"/opt/homebrew/bin","favorites":[],"recents":[],"theme":"light","language":"en","autoCheckUpdates":true,"autoDownloadUpdates":false}"#
        XCTAssertTrue(UserDataPortable.containsForbiddenPayload(Data(pathEnv.utf8)))
    }

    func testSanitizeDropsInvalidToolIDs() {
        let cleaned = UserDataPortable.sanitizeToolIDs([
            "git",
            "../etc/passwd",
            "Claude Code",
            "openclaw",
            "",
            String(repeating: "a", count: 80),
        ])
        XCTAssertEqual(cleaned, ["git", "openclaw"])
    }

    func testDecodeRejectsUnknownFormat() {
        let data = Data(#"{"formatVersion":99,"favorites":[],"recents":[],"theme":"system","language":"en","autoCheckUpdates":true,"autoDownloadUpdates":false}"#.utf8)
        XCTAssertThrowsError(try UserDataPortable.decode(data))
    }
}
