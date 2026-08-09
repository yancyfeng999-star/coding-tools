import Foundation

// MARK: - Process Execution
//
// 受控进程执行：强类型参数、取消、超时、日志脱敏。
// 完整定义见 docs/SECURITY_MODEL.md §7-8。
// 阶段 3 由子代理 A 实现。

public struct ProcessRequest: Hashable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let timeout: Duration
    public let workingDirectory: URL?
    public let environment: [String: String]

    public init(
        executableURL: URL,
        arguments: [String],
        timeout: Duration = .seconds(300),
        workingDirectory: URL? = nil,
        environment: [String: String] = [:]
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.timeout = timeout
        self.workingDirectory = workingDirectory
        self.environment = environment
    }
}

public struct ProcessOutput: Hashable, Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public protocol ProcessExecuting: Sendable {
    func run(_ request: ProcessRequest) async throws -> ProcessOutput
    func cancel(id: UUID) async
}

public actor ProcessExecutor: ProcessExecuting {
    private var running: [UUID: Task<Void, Never>] = [:]

    public init() {}

    public func run(_ request: ProcessRequest) async throws -> ProcessOutput {
        // 阶段 3 占位：使用 Foundation Process + Pipe 实现
        // 关键点：
        // 1. 不拼接 /bin/sh -c
        // 2. stdout/stderr 实时收集
        // 3. 全部内容走 redact()
        // 4. 超时通过 withThrowingTaskGroup
        throw ProcessExecutionError.notImplemented
    }

    public func cancel(id: UUID) async {
        running[id]?.cancel()
        running.removeValue(forKey: id)
    }
}

public enum ProcessExecutionError: Error, Sendable, Equatable {
    case notImplemented
    case timeout
    case cancelled
    case nonZeroExit(code: Int32, stderr: String)
}

/// 脱敏规则。完整列表见 docs/SECURITY_MODEL.md §7。
public enum OutputRedactor {
    public static func redact(_ text: String) -> String {
        var out = text
        let patterns: [(String, String)] = [
            (#"(?i)(authorization:\s*bearer)\s+[A-Za-z0-9._-]+"#, "$1 ***"),
            (#"https?://[^:]+:[^@]+@"#, "https://user:***@"),
            (#"/Users/[^/\s]+/"#, "/Users/***/"),
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(out.startIndex..., in: out)
                out = regex.stringByReplacingMatches(
                    in: out,
                    range: range,
                    withTemplate: replacement
                )
            }
        }
        return out
    }
}
