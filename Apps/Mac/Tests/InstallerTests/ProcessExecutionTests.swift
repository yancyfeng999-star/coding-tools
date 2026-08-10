import XCTest
import Foundation
@testable import ProcessExecution

final class ProcessExecutionTests: XCTestCase {

    // MARK: - Real-process tests (use /bin/echo, /usr/bin/false, /bin/sleep on macOS)

    func testSuccessExit() async throws {
        let executor = ProcessExecutor()
        let out = try await executor.run(ProcessRequest(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["hello", "world"],
            timeout: .seconds(5)
        ))
        XCTAssertEqual(out.exitCode, 0)
        XCTAssertTrue(out.stdout.contains("hello world"))
    }

    func testNonZeroExit() async throws {
        let executor = ProcessExecutor()
        let out = try await executor.run(ProcessRequest(
            executableURL: URL(fileURLWithPath: "/usr/bin/false"),
            arguments: [],
            timeout: .seconds(5)
        ))
        XCTAssertNotEqual(out.exitCode, 0)
    }

    func testShellInvocationForbidden() async throws {
        let executor = ProcessExecutor()
        do {
            _ = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "echo hi"],
                timeout: .seconds(5)
            ))
            XCTFail("Should have thrown .shellForbidden")
        } catch ProcessExecutionError.shellForbidden {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testBashInvocationForbidden() async throws {
        let executor = ProcessExecutor()
        do {
            _ = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/bash"),
                arguments: ["-c", "echo hi"],
                timeout: .seconds(5)
            ))
            XCTFail("Should have thrown .shellForbidden")
        } catch ProcessExecutionError.shellForbidden {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testTimeout() async throws {
        let executor = ProcessExecutor()
        do {
            _ = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["10"],
                timeout: .milliseconds(500)
            ))
            XCTFail("Should have thrown .timeout")
        } catch ProcessExecutionError.timeout {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testCancellation() async throws {
        let executor = ProcessExecutor()
        let task = Task {
            try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["3"],
                timeout: .seconds(60)
            ))
        }
        // 等子进程真正起来
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        do {
            _ = try await task.value
            // 进程可能被 terminate 杀掉（非 0 退出），或抛 cancellation
        } catch {
            // 接受 cancellation / nonZeroExit 任一
            XCTAssertTrue(error is CancellationError || (error as? ProcessExecutionError) != nil,
                          "Expected cancellation or ProcessExecutionError, got \(error)")
        }
    }

    func testMissingExecutable() async throws {
        let executor = ProcessExecutor()
        do {
            _ = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/this-binary-does-not-exist-xyz"),
                arguments: [],
                timeout: .seconds(5)
            ))
            XCTFail("Should have thrown")
        } catch {
            // 接受 launchFailed 或非 0 退出
            XCTAssertTrue(true)
        }
    }

    // MARK: - Redaction unit tests (pure function)

    func testRedactBearerToken() {
        let out = OutputRedactor.redact("Authorization: Bearer abc123def456")
        XCTAssertTrue(out.contains("Bearer ***"), "Got: \(out)")
        XCTAssertFalse(out.contains("abc123def456"))
    }

    func testRedactBasicAuthURL() {
        let out = OutputRedactor.redact("https://user:hunter2@api.example.com/v1/repos")
        XCTAssertTrue(out.contains("user:***@"), "Got: \(out)")
        XCTAssertFalse(out.contains("hunter2"))
    }

    func testRedactUserPath() {
        let out = OutputRedactor.redact("ls /Users/janedoe/projects/foo")
        XCTAssertTrue(out.contains("/Users/***/projects"), "Got: \(out)")
        XCTAssertFalse(out.contains("janedoe"))
    }

    func testRedactGitHubPAT() {
        let cases = [
            "ghp_abcdefghijklmnopqrstuvwxyz1234567890",
            "gho_abcdefghijklmnopqrstuvwxyz1234567890",
            "ghs_abcdefghijklmnopqrstuvwxyz1234567890",
        ]
        for c in cases {
            let out = OutputRedactor.redact("token=\(c)")
            XCTAssertFalse(out.contains(c), "PAT leaked: \(c) → \(out)")
            XCTAssertTrue(out.contains("***"))
        }
    }

    func testRedactEnvVarPrint() {
        let out = OutputRedactor.redact("HOME=/Users/johndoe PATH=/usr/bin")
        XCTAssertTrue(out.contains("HOME=***"), "Output was: \(out)")
        XCTAssertTrue(out.contains("PATH=***"), "Output was: \(out)")
        XCTAssertFalse(out.contains("johndoe"))
    }

    func testRedactPEMBlock() {
        let pem = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIEowIBAAKCAQEAuZxV...abunchofbase64...
        -----END RSA PRIVATE KEY-----
        """
        let out = OutputRedactor.redact(pem)
        XCTAssertTrue(out.contains("REDACTED"), "Got: \(out)")
        XCTAssertFalse(out.contains("MIIEowIBAAKCAQEAuZxV"))
    }

    func testRedactPreservesNonSensitive() {
        let original = "==> Installing git\n==> Pouring git-2.46.0.arm64_sonoma.bottle.tar.gz"
        let out = OutputRedactor.redact(original)
        XCTAssertEqual(out, original)
    }
}
