import XCTest
@testable import UI

final class IssueURLBuilderTests: XCTestCase {
    func testBugReportURLIncludesOnlySafeMetadata() {
        let metadata = IssueReportMetadata(
            version: "1.5.1",
            build: "24",
            macOSVersion: "macOS 14.6.1",
            architecture: "arm64"
        )
        let url = IssueURLBuilder.bugReportURL(metadata: metadata)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "version" })?.value, "1.5.1")
        XCTAssertEqual(items.first(where: { $0.name == "build" })?.value, "24")
        XCTAssertEqual(items.first(where: { $0.name == "macos_version" })?.value, "macOS 14.6.1")
        XCTAssertEqual(items.first(where: { $0.name == "architecture" })?.value, "Apple Silicon")
        XCTAssertEqual(items.first(where: { $0.name == "template" })?.value, "bug_report.yml")
        XCTAssertFalse(IssueURLBuilder.containsForbiddenPayload(url))
        let text = url.absoluteString
        XCTAssertFalse(text.contains("/Users/"))
        XCTAssertFalse(text.contains("Bearer"))
        XCTAssertFalse(text.contains("PATH="))
    }

    func testSanitizeStripsHomePathAndToken() {
        let dirty = IssueReportMetadata(
            version: "1.0.0",
            build: "1",
            macOSVersion: "macOS 15 /Users/alice/secret Bearer abc.def",
            architecture: "arm64"
        )
        let url = IssueURLBuilder.bugReportURL(metadata: dirty)
        XCTAssertFalse(url.absoluteString.contains("/Users/alice"))
        XCTAssertFalse(url.absoluteString.contains("abc.def"))
        XCTAssertFalse(IssueURLBuilder.containsForbiddenPayload(url))
    }

    func testDiagnosticPreviewListsIncludedFieldsOnly() {
        let summary = DiagnosticSummaryBuilder.make(
            version: "1.5.1",
            build: "24",
            macOSVersion: "macOS 14.6.1",
            architecture: "arm64",
            theme: "system",
            language: "zh-Hans",
            catalogStatus: "signed",
            appUpdateState: "idle",
            selectedToolStatus: "git:installed"
        )
        XCTAssertTrue(summary.includedKeys.contains("app.version"))
        XCTAssertTrue(summary.previewText.contains("1.5.1"))
        XCTAssertFalse(summary.previewText.contains("/Users/"))
        XCTAssertFalse(summary.includedKeys.contains("home.path"))
        XCTAssertFalse(summary.includedKeys.contains("token"))
    }

    func testIssueFormArchitectureMatchesGitHubDropdown() {
        XCTAssertEqual(IssueURLBuilder.issueFormArchitecture("arm64"), "Apple Silicon")
        XCTAssertEqual(IssueURLBuilder.issueFormArchitecture("x86_64"), "Intel")
        XCTAssertEqual(IssueURLBuilder.issueFormArchitecture("unknown"), "Universal / unknown")
        let intel = IssueURLBuilder.bugReportURL(metadata: IssueReportMetadata(
            version: "1.0.0", build: "2", macOSVersion: "macOS 14.0", architecture: "x86_64"
        ))
        let items = URLComponents(url: intel, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "build" })?.value, "2")
        XCTAssertEqual(items.first(where: { $0.name == "architecture" })?.value, "Intel")
    }
}
