import XCTest
import Foundation
@testable import UI

final class DeepLinkRouterTests: XCTestCase {

    // MARK: - Open tool

    func testOpenToolByPath() {
        let url = URL(string: "codingtools://tool/git")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertEqual(link, .openTool(id: "git", autoInstall: false))
    }

    func testOpenToolByPathNoID() {
        let url = URL(string: "codingtools://tool/")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertNil(link)
    }

    // MARK: - Install

    func testInstallByQuery() {
        let url = URL(string: "codingtools://install?tool=claude-code")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertEqual(link, .openTool(id: "claude-code", autoInstall: true))
    }

    func testInstallByPath() {
        let url = URL(string: "codingtools://install/claude-code")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertEqual(link, .openTool(id: "claude-code", autoInstall: true))
    }

    func testInstallNoID() {
        let url = URL(string: "codingtools://install")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertNil(link)
    }

    // MARK: - Home

    func testHomeNoTab() {
        let url = URL(string: "codingtools://home")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertEqual(link, .home(tab: nil))
    }

    func testHomeWithTab() {
        let url = URL(string: "codingtools://home?tab=catalog")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertEqual(link, .home(tab: "catalog"))
    }

    // MARK: - Update

    func testCheckForUpdate() {
        let url = URL(string: "codingtools://update")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertEqual(link, .checkForUpdate)
    }

    // MARK: - Errors

    func testWrongSchemeIgnored() {
        let url = URL(string: "https://example.com/tool/git")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertNil(link)
    }

    func testUnknownHostIgnored() {
        let url = URL(string: "codingtools://garbage/foo")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertNil(link)
    }

    func testEmptyHostIgnored() {
        // codingtools:///path → host is nil
        let url = URL(string: "codingtools:///path")!
        let link = DeepLinkRouter.parse(url)
        XCTAssertNil(link)
    }
}
