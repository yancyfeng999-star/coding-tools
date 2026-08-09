import XCTest
@testable import Installers
@testable import Domain

final class InstallActionTests: XCTestCase {
    func testHomebrewFormulaActionEquality() {
        let a = InstallAction.homebrewFormula(name: "git")
        let b = InstallAction.homebrewFormula(name: "git")
        XCTAssertEqual(a, b)
    }

    func testMiseToolActionPreservesVersion() {
        let a = InstallAction.miseTool(name: "node", version: "22")
        if case .miseTool(let name, let version) = a {
            XCTAssertEqual(name, "node")
            XCTAssertEqual(version, "22")
        } else {
            XCTFail("Expected mise tool action")
        }
    }

    func testOfficialArtifactPreservesSha256() {
        let url = URL(string: "https://nodejs.org/dist/v22.7.5/node-v22.7.5.pkg")!
        let a = InstallAction.officialArtifact(
            url: url,
            sha256: "deadbeef",
            bundleID: "org.nodejs.node.pkg",
            teamID: "EA7RXK7B3K"
        )
        if case .officialArtifact(let u, let s, let b, let t) = a {
            XCTAssertEqual(u, url)
            XCTAssertEqual(s, "deadbeef")
            XCTAssertEqual(b, "org.nodejs.node.pkg")
            XCTAssertEqual(t, "EA7RXK7B3K")
        } else {
            XCTFail("Expected official artifact")
        }
    }
}
