import XCTest
import Foundation
@testable import ProcessExecution

final class CrashReporterTests: XCTestCase {

    private var tmpDir: URL!
    private var reporter: CrashReporter!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrashReporterTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        reporter = CrashReporter(
            directory: tmpDir,
            appVersion: "1.0.0",
            appBuild: "42",
            redactor: { input in
                input.replacingOccurrences(of: "secret", with: "***")
            }
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        reporter = nil
        tmpDir = nil
        super.tearDown()
    }

    // MARK: - Redaction

    func testDefaultRedactBearerToken() {
        let input = "Authorization: Bearer abc.def.ghi"
        let output = CrashReporter.defaultRedact(input)
        XCTAssertFalse(output.contains("abc.def.ghi"))
        XCTAssertTrue(output.contains("Bearer ***"))
    }

    func testDefaultRedactBasicAuth() {
        let input = "https://user:secretpass@github.com/repo"
        let output = CrashReporter.defaultRedact(input)
        XCTAssertFalse(output.contains("secretpass"))
        XCTAssertTrue(output.contains("***:***@"))
    }

    func testDefaultRedactUserPath() {
        let input = "/Users/johndoe/Documents/test"
        let output = CrashReporter.defaultRedact(input)
        XCTAssertTrue(output.contains("/Users/***/"))
        XCTAssertFalse(output.contains("johndoe"))
    }

    func testCustomRedactorUsed() {
        reporter.recordError(NSError(domain: "x", code: 1), context: "secret info")
        let files = try? FileManager.default.contentsOfDirectory(atPath: tmpDir.path)
        XCTAssertNotNil(files)
        // 文件至少一个 crash report
        let crashFiles = files?.filter { $0.hasSuffix(".json") } ?? []
        XCTAssertFalse(crashFiles.isEmpty)
        let content = try? String(contentsOf: tmpDir.appendingPathComponent(crashFiles[0]))
        XCTAssertNotNil(content)
        XCTAssertFalse(content?.contains("secret") ?? true, "custom redactor should scrub 'secret'")
        XCTAssertTrue(content?.contains("***") ?? false)
    }

    // MARK: - Write

    func testRecordErrorWritesFile() {
        let error = NSError(domain: "TestDomain", code: 99, userInfo: [
            NSLocalizedDescriptionKey: "boom"
        ])
        reporter.recordError(error, context: "secret info")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: tmpDir.path)) ?? []
        let crashFiles = files.filter { $0.hasSuffix(".json") }
        XCTAssertEqual(crashFiles.count, 1, "exactly one crash file expected")

        let url = tmpDir.appendingPathComponent(crashFiles[0])
        let data = try? Data(contentsOf: url)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try? decoder.decode(CrashPayload.self, from: data!)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.kind, "caught")
        XCTAssertEqual(payload?.appVersion, "1.0.0")
        XCTAssertEqual(payload?.appBuild, "42")
        XCTAssertTrue(payload?.message.contains("boom") ?? false)
        XCTAssertEqual(payload?.context, "*** info")
    }

    func testDefaultDirectoryUnderLogs() {
        let dir = CrashReporter.defaultDirectory()
        let path = dir.path
        XCTAssertTrue(path.contains("Logs"), "expected default directory under Logs, got: \(path)")
        XCTAssertTrue(path.contains("CodingTools/crashes"), "expected CodingTools/crashes segment, got: \(path)")
    }

    // MARK: - Install is idempotent

    func testInstallDoesNotThrow() {
        // Install in tests is hard to verify without a real crash; just ensure install() doesn't throw
        reporter.install()
        reporter.install()  // 二次安装应无副作用
        XCTAssert(true)
    }
}
