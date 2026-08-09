import XCTest
import SwiftUI
@testable import CodingTools

@MainActor
final class AppModelTests: XCTestCase {
    func testDefaultTabIsHome() {
        let model = AppModel()
        XCTAssertEqual(model.selectedTab, .home)
    }

    func testSearchTextStartsEmpty() {
        let model = AppModel()
        XCTAssertEqual(model.searchText, "")
    }
}

final class ProcessExecutionRedactionTests: XCTestCase {
    func testBearerTokenRedacted() {
        let input = "Authorization: Bearer abc.def.ghi"
        let output = OutputRedactor.redact(input)
        XCTAssertFalse(output.contains("abc.def.ghi"))
        XCTAssertTrue(output.contains("***"))
    }

    func testUserPathRedacted() {
        let input = "/Users/johndoe/Documents/test"
        let output = OutputRedactor.redact(input)
        XCTAssertTrue(output.contains("/Users/***/"))
    }

    func testBasicAuthInUrlRedacted() {
        let input = "https://user:secretpass@github.com/repo"
        let output = OutputRedactor.redact(input)
        XCTAssertFalse(output.contains("secretpass"))
    }
}
