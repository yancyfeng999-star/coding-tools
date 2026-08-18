import Foundation

// MARK: - Process Execution
//
// 受控进程执行：强类型参数、取消、超时、日志脱敏。
// 完整定义见 docs/SECURITY_MODEL.md §7-8。
// 阶段 3 由子代理 A 实现。
//
// 关键安全约束：
//   - **绝对禁止** `/bin/sh -c "..."` —— 通过参数数组直接传给 Process
//   - stdout / stderr 实时收集，**全部内容**走 redact()
//   - 超时通过 Task 竞争 + process.terminate()
//   - 取消：当调用 Task 被 cancel 时，子进程同步 terminate
//   - 不暴露任何 shell 字符串拼接路径

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

    /// 合并 stdout+stderr 后做脱敏的输出（用于日志）。
    public var redactedCombined: String {
        OutputRedactor.redact(stdout + stderr)
    }
}

public protocol ProcessExecuting: Sendable {
    func run(_ request: ProcessRequest) async throws -> ProcessOutput
    /// 取消当前正在运行的进程（按 UUID）。当前实现中调用方一般通过取消
    /// 自己的 Task 来触发；保留此 API 供后续分片执行使用。
    func cancel(id: UUID) async
}

public actor ProcessExecutor: ProcessExecuting {
    private var running: [UUID: Process] = [:]

    public init() {}

    public func run(_ request: ProcessRequest) async throws -> ProcessOutput {
        // 1. 防御性检查：禁止 sh 包装器（即使调用方传错也无机会拼接）
        let path = request.executableURL.path
        let lowerName = (path as NSString).lastPathComponent.lowercased()
        if lowerName == "sh" || lowerName == "bash" || lowerName == "zsh" || lowerName == "csh" || lowerName == "tcsh" {
            throw ProcessExecutionError.shellForbidden
        }

        // 2. 构造 Process
        let process = Process()
        process.executableURL = request.executableURL
        process.arguments = request.arguments
        if let cwd = request.workingDirectory { process.currentDirectoryURL = cwd }
        if !request.environment.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (k, v) in request.environment { env[k] = v }
            process.environment = env
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        let box = ProcessExitBox()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { box.appendStdout(chunk) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { box.appendStderr(chunk) }
        }
        process.terminationHandler = { proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            box.appendStdout(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            box.appendStderr(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            box.finish(exitCode: proc.terminationStatus)
        }

        let id = UUID()
        running[id] = process
        defer { running.removeValue(forKey: id) }

        do {
            try process.run()
        } catch {
            throw ProcessExecutionError.launchFailed(String(describing: error))
        }

        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: ProcessOutput?.self) { group in
                group.addTask {
                    await box.wait()
                }
                group.addTask {
                    try await Task.sleep(for: request.timeout)
                    return nil
                }

                guard let first = try await group.next() else {
                    throw ProcessExecutionError.launchFailed("no task completed")
                }
                if let out = first {
                    group.cancelAll()
                    return out
                }

                if process.isRunning { process.terminate() }
                _ = try await group.next()
                throw ProcessExecutionError.timeout
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }

    public func cancel(id: UUID) async {
        if let proc = running[id] {
            proc.terminate()
        }
        running.removeValue(forKey: id)
    }

}

public enum ProcessExecutionError: Error, Sendable, Equatable {
    case notImplemented
    case timeout
    case cancelled
    case nonZeroExit(code: Int32, stderr: String)
    case shellForbidden
    case launchFailed(String)
    case executableNotFound(String)
}

// MARK: - OutputRedactor
//
// 脱敏规则。完整列表见 docs/SECURITY_MODEL.md §7。
//   1. Authorization: Bearer <token>      → Bearer ***
//   2. Basic auth in URL: user:pass@host   → user:***@host
//   3. 用户路径 /Users/<name>/...          → /Users/***/...
//   4. process.env.*                       → ***
//   5. Homebrew tap URL 中的 token          → ***
//   6. PEM block 私钥片段                   → ***（保守策略）
//   7. GitHub PAT: ghp_xxx / gho_xxx       → ***

public enum OutputRedactor {
    public static func redact(_ text: String) -> String {
        var out = text
        let patterns: [(String, String)] = [
            // Bearer token
            (#"(?i)(authorization:\s*bearer)\s+[A-Za-z0-9._\-+/=]+"#, "$1 ***"),
            // URL basic auth
            (#"https?://([^:/\s]+):([^@\s]+)@"#, "https://$1:***@"),
            // User home path
            (#"/Users/[^/\s\"']+/"#, "/Users/***/"),
            // GitHub PATs
            (#"\bghp_[A-Za-z0-9]{20,}\b"#, "***"),
            (#"\bgho_[A-Za-z0-9]{20,}\b"#, "***"),
            (#"\bghs_[A-Za-z0-9]{20,}\b"#, "***"),
            (#"\bghu_[A-Za-z0-9]{20,}\b"#, "***"),
            // npm tokens（P1-G3-4 修复）
            (#"\bnpm_[A-Za-z0-9]{36,}\b"#, "***"),
            // AWS access keys
            (#"\bAKIA[0-9A-Z]{16}\b"#, "***"),
            // Anthropic / OpenAI API keys
            (#"\bsk-ant-[A-Za-z0-9_\-]{20,}\b"#, "***"),
            (#"\bsk-[A-Za-z0-9]{20,}\b"#, "***"),
            // Generic API_KEY= / TOKEN= / SECRET=
            (#"(^|\s)(API_KEY|SECRET|TOKEN|PASSWORD|AUTH|CLIENT_SECRET|ACCESS_KEY)=([^\s]+)"#, "$1$2=***"),
            // process.env prints (e.g. "PATH=/usr/bin", "HOME=/Users/foo")
            (#"(^|\s)(HOME|PATH|SHELL)=([^\s]+)"#, "$1$2=***"),
            // PEM private key block
            (#"-----BEGIN (?:RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----"#, "***PRIVATE KEY REDACTED***"),
            // PostgreSQL connection string with password
            (#"\bpostgres(ql)?://[^:\s]+:[^@\s]+@"#, "***POSTGRES_URL***"),
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
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

    /// 截断绝对路径为 `/Users/***/.../last3` 形式（用于 UI 显示 P0-G3-3）。
    public static func redactPath(_ path: String, keepLastSegments: Int = 2) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            let suffix = path.dropFirst(home.count)
            let parts = suffix.split(separator: "/").map(String.init)
            let lastN = parts.suffix(keepLastSegments).joined(separator: "/")
            return "/Users/***/\(lastN)"
        }
        return path
    }
}

// MARK: - ProcessExitBox
//
// Single completion: either the result is already known, or exactly one waiter
// is parked. finish(_:) is idempotent.

private final class ProcessExitBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutData = Data()
    private var stderrData = Data()
    private var result: ProcessOutput?
    private var continuation: CheckedContinuation<ProcessOutput, Never>?

    func appendStdout(_ d: Data) {
        lock.lock(); defer { lock.unlock() }
        stdoutData.append(d)
    }

    func appendStderr(_ d: Data) {
        lock.lock(); defer { lock.unlock() }
        stderrData.append(d)
    }

    func wait() async -> ProcessOutput {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let result {
                lock.unlock()
                continuation.resume(returning: result)
            } else {
                precondition(self.continuation == nil)
                self.continuation = continuation
                lock.unlock()
            }
        }
    }

    func finish(exitCode: Int32) {
        let output: ProcessOutput
        let continuation: CheckedContinuation<ProcessOutput, Never>?
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        output = ProcessOutput(
            stdout: OutputRedactor.redact(String(decoding: stdoutData, as: UTF8.self)),
            stderr: OutputRedactor.redact(String(decoding: stderrData, as: UTF8.self)),
            exitCode: exitCode
        )
        result = output
        continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: output)
    }
}
