import XCTest
@testable import Installers
import Domain

// MARK: - Helper wire encoding round-trip

final class HelperWireEncodingTests: XCTestCase {

    func testNpmGlobalRoundTrip() throws {
        let action = InstallAction.npmGlobal(
            packageName: "@openai/codex",
            scriptURL: nil,
            versionRule: ">=0.1.0"
        )
        let data = try encodeHelper(action)
        let decoded = try JSONDecoder().decode(HelperNpmGlobalWire.self, from: data)
        XCTAssertEqual(decoded.packageName, "@openai/codex")
        XCTAssertEqual(decoded.versionRule, ">=0.1.0")
        XCTAssertNil(decoded.scriptURL)
    }

    func testHomebrewFormulaRoundTrip() throws {
        let action = InstallAction.homebrewFormula(name: "git")
        let data = try encodeHelper(action)
        let decoded = try JSONDecoder().decode(HelperHomebrewFormulaWire.self, from: data)
        XCTAssertEqual(decoded.name, "git")
    }

    func testHomebrewCaskRoundTrip() throws {
        let action = InstallAction.homebrewCask(name: "docker")
        let data = try encodeHelper(action)
        let decoded = try JSONDecoder().decode(HelperHomebrewCaskWire.self, from: data)
        XCTAssertEqual(decoded.name, "docker")
    }

    func testMiseToolRoundTrip() throws {
        let action = InstallAction.miseTool(name: "node", version: "20.10.0")
        let data = try encodeHelper(action)
        let decoded = try JSONDecoder().decode(HelperMiseToolWire.self, from: data)
        XCTAssertEqual(decoded.name, "node")
        XCTAssertEqual(decoded.version, "20.10.0")
    }

    func testOfficialArtifactRoundTrip() throws {
        let url = URL(string: "https://example.com/foo.dmg")!
        let action = InstallAction.officialArtifact(
            url: url,
            sha256: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            bundleID: "com.example.foo",
            teamID: "ABCDE12345"
        )
        let data = try encodeHelper(action)
        let decoded = try JSONDecoder().decode(HelperOfficialArtifactWire.self, from: data)
        XCTAssertEqual(decoded.url, url.absoluteString)
        XCTAssertEqual(decoded.sha256.count, 64)
        XCTAssertEqual(decoded.bundleID, "com.example.foo")
        XCTAssertEqual(decoded.teamID, "ABCDE12345")
    }

    // MARK: - Helpers

    private func encodeHelper(_ action: InstallAction) throws -> Data {
        let encoder = JSONEncoder()
        switch action {
        case .npmGlobal(let packageName, let scriptURL, let versionRule):
            return try encoder.encode(HelperNpmGlobalWire(
                packageName: packageName,
                scriptURL: scriptURL?.absoluteString,
                versionRule: versionRule
            ))
        case .homebrewFormula(let name):
            return try encoder.encode(HelperHomebrewFormulaWire(name: name))
        case .homebrewCask(let name):
            return try encoder.encode(HelperHomebrewCaskWire(name: name))
        case .miseTool(let name, let version):
            return try encoder.encode(HelperMiseToolWire(name: name, version: version))
        case .officialArtifact(let url, let sha256, let bundleID, let teamID):
            return try encoder.encode(HelperOfficialArtifactWire(
                url: url.absoluteString,
                sha256: sha256,
                bundleID: bundleID,
                teamID: teamID
            ))
        }
    }
}

// MARK: - HelperInstallRequest / Response (NSSecureCoding)

final class HelperRequestResponseCodingTests: XCTestCase {

    func testInstallRequestRoundTrip() throws {
        let original = HelperInstallRequest(
            planID: "p1",
            toolID: "codex",
            actionType: "npm-global",
            actionJSON: Data("hello".utf8)
        )
        let archived = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: HelperInstallRequest.self,
            from: archived
        )
        XCTAssertEqual(decoded?.planID, "p1")
        XCTAssertEqual(decoded?.toolID, "codex")
        XCTAssertEqual(decoded?.actionType, "npm-global")
        XCTAssertEqual(decoded?.actionJSON, Data("hello".utf8))
    }

    func testInstallResponseRoundTrip() throws {
        let original = HelperInstallResponse(
            success: true,
            exitCode: 0,
            resolvedVersion: "0.1.0",
            errorMessage: nil
        )
        let archived = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: HelperInstallResponse.self,
            from: archived
        )
        XCTAssertEqual(decoded?.success, true)
        XCTAssertEqual(decoded?.exitCode, 0)
        XCTAssertEqual(decoded?.resolvedVersion, "0.1.0")
        XCTAssertNil(decoded?.errorMessage)
    }

    func testEnvironmentResponseRoundTrip() throws {
        let original = HelperEnvironmentResponse(
            brewPath: "/opt/homebrew/bin/brew",
            npmPath: "/usr/local/bin/npm",
            misePath: nil,
            homeDirectory: "/Users/test",
            arch: "arm64"
        )
        let archived = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: HelperEnvironmentResponse.self,
            from: archived
        )
        XCTAssertEqual(decoded?.brewPath, "/opt/homebrew/bin/brew")
        XCTAssertEqual(decoded?.arch, "arm64")
    }
}

// MARK: - HelperClientError

final class HelperClientErrorTests: XCTestCase {
    func testSendable() {
        let error: HelperClientError = .connectionInvalidated
        let _: Sendable = error
        // 编译期保证 — 仅确认存在
        XCTAssertNotNil(error)
    }
}
