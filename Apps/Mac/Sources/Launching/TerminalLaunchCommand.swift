import Foundation

/// Builds a typed `/usr/bin/osascript` invocation that asks Terminal to run
/// the resolved executable with arguments. No `/bin/sh -c`, no pipes.
public enum TerminalLaunchCommand {
    public struct ProcessInvocation: Equatable, Sendable {
        public let executableURL: URL
        public let arguments: [String]
    }

    public static func appleScript(executable: URL, arguments: [String]) -> String {
        let command = posixCommand(executable: executable, arguments: arguments)
        return "tell application \"Terminal\" to do script \"\(escapeAppleScript(command))\""
    }

    public static func processInvocation(executable: URL, arguments: [String]) -> ProcessInvocation {
        ProcessInvocation(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", appleScript(executable: executable, arguments: arguments)]
        )
    }

    public static func posixCommand(executable: URL, arguments: [String]) -> String {
        ([executable.path] + arguments).map(quotePOSIX).joined(separator: " ")
    }

    private static func quotePOSIX(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func escapeAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
