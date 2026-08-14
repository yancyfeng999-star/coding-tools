import XCTest
import Launching

final class TerminalLaunchCommandTests: XCTestCase {
    func testProcessInvocationRunsOsascriptNotAShellPipe() {
        let invocation = TerminalLaunchCommand.processInvocation(
            executable: URL(fileURLWithPath: "/usr/bin/true"),
            arguments: ["--version"]
        )
        XCTAssertEqual(invocation.executableURL.path, "/usr/bin/osascript")
        XCTAssertEqual(invocation.arguments.first, "-e")
        XCTAssertEqual(invocation.arguments.count, 2)
        let script = invocation.arguments[1]
        XCTAssertTrue(script.contains("tell application \"Terminal\""))
        XCTAssertTrue(script.contains("do script"))
        XCTAssertTrue(script.contains("/usr/bin/true"))
        XCTAssertTrue(script.contains("--version"))
        XCTAssertFalse(script.contains(" | "))
        XCTAssertFalse(script.contains("/bin/sh"))
    }

    func testAppleScriptQuotesArgumentWithSpacesAndQuotes() {
        let posix = TerminalLaunchCommand.posixCommand(
            executable: URL(fileURLWithPath: "/usr/bin/echo"),
            arguments: ["hello world", "say\"hi"]
        )
        XCTAssertEqual(posix, "'/usr/bin/echo' 'hello world' 'say\"hi'")
        let script = TerminalLaunchCommand.appleScript(
            executable: URL(fileURLWithPath: "/usr/bin/echo"),
            arguments: ["hello world", "say\"hi"]
        )
        XCTAssertTrue(script.contains("'hello world'"))
        XCTAssertTrue(script.contains("say\\\"hi"))
        XCTAssertFalse(script.contains("/bin/sh -c"))
    }
}
