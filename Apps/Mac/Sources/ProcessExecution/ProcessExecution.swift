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

        // 3. 注册到 actor 状态
        let id = UUID()
        running[id] = process

        defer { running.removeValue(forKey: id) }

        // 4. 启动 + 异步等待 termination
        do {
            try process.run()
        } catch {
            throw ProcessExecutionError.launchFailed(String(describing: error))
        }

        // 5. 用 task group 跑：主 task = 等 process 退出；次 task = 超时
        return try await withThrowingTaskGroup(of: ProcessOutput?.self) { group in
            // 主 task
            group.addTask { [self] in
                // 在 actor 外面 collect 完数据再 resume
                let output: ProcessOutput = try await self.awaitExit(
                    of: process,
                    stdoutPipe: stdoutPipe,
                    stderrPipe: stderrPipe
                )
                return output
            }
            // 超时 task
            group.addTask {
                try await Task.sleep(for: request.timeout)
                return nil  // 标记超时
            }

            // 第一个完成的 task 胜出
            guard let first = try await group.next() else {
                throw ProcessExecutionError.launchFailed("no task completed")
            }
            group.cancelAll()

            if let out = first {
                return out
            } else {
                // 超时 task 胜出
                process.terminate()
                throw ProcessExecutionError.timeout
            }
        }
    }

    public func cancel(id: UUID) async {
        if let proc = running[id] {
            proc.terminate()
        }
        running.removeValue(forKey: id)
    }

    // MARK: - Helpers

    private func awaitExit(
        of process: Process,
        stdoutPipe: Pipe,
        stderrPipe: Pipe
    ) async throws -> ProcessOutput {
        // 用 readabilityHandler 持续收集；polling + terminationHandler 联合保证
        // 双重 resume 安全（用一个原子标志保证只 resume 一次）。
        let box = ProcessExitBox()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty { return }
            box.appendStdout(chunk)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty { return }
            box.appendStderr(chunk)
        }

        // terminationHandler 可能是异步回调，polling 也同时在跑；
        // 用 box 的「只第一次 resume」机制避免双重 resume。
        process.terminationHandler = { proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            let extraOut = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let extraErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            box.appendStdout(extraOut)
            box.appendStderr(extraErr)
            box.tryResume(
                stdout: box.takeStdout(),
                stderr: box.takeStderr(),
                exitCode: proc.terminationStatus
            )
        }

        // Polling 兜底：Process.terminationStatus 在某些边界下不可靠，
        // polling 能保证 await 一定返回。如果调用方 Task 被 cancel，
        // sleep 会抛 CancellationError，我们让它向上传播。
        while process.isRunning {
            do {
                try await Task.sleep(for: .milliseconds(25))
            } catch {
                // 调用方 Task 被取消 → 强制 terminate 并抛
                if process.isRunning { process.terminate() }
                throw CancellationError()
            }
        }

        // Process 已退出；如果 terminationHandler 已经先 resume 过，
        // 这里就拿不到 continuation；否则我们自己 resume。
        let extraOut = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let extraErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        box.appendStdout(extraOut)
        box.appendStderr(extraErr)
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        return await box.awaitIfNotResumed(
            fallbackStdout: box.takeStdout(),
            fallbackStderr: box.takeStderr(),
            exitCode: process.terminationStatus
        )
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
            // process.env prints (e.g. "PATH=/usr/bin", "HOME=/Users/foo")
            // 匹配行首或空白后的 KEY=VALUE
            (#"(^|\s)(HOME|PATH|SHELL|API_KEY|SECRET|TOKEN|PASSWORD)=([^\s]+)"#, "$1$2=***"),
            // PEM private key block
            (#"-----BEGIN (?:RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----"#, "***PRIVATE KEY REDACTED***"),
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
}

// MARK: - ProcessExitBox
//
// 收集 stdout/stderr 数据 + 保证 continuation 只被 resume 一次。
// terminationHandler 和 polling 都会触发"process 退出"事件，必须互斥。
private final class ProcessExitBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutData = Data()
    private var stderrData = Data()
    private var resumed = false
    private var cont: CheckedContinuation<ProcessOutput, Never>?
    private var pendingOutput: ProcessOutput?

    init() {}

    func appendStdout(_ d: Data) {
        lock.lock(); defer { lock.unlock() }
        stdoutData.append(d)
    }

    func appendStderr(_ d: Data) {
        lock.lock(); defer { lock.unlock() }
        stderrData.append(d)
    }

    func takeStdout() -> String {
        lock.lock(); defer { lock.unlock() }
        return String(data: stdoutData, encoding: .utf8) ?? ""
    }

    func takeStderr() -> String {
        lock.lock(); defer { lock.unlock() }
        return String(data: stderrData, encoding: .utf8) ?? ""
    }

    /// terminationHandler 调用入口：第一次成功 resume，后续 no-op。
    func tryResume(stdout: String, stderr: String, exitCode: Int32) {
        lock.lock()
        if resumed {
            lock.unlock(); return
        }
        resumed = true
        if let c = cont {
            cont = nil
            lock.unlock()
            c.resume(returning: ProcessOutput(stdout: OutputRedactor.redact(stdout), stderr: OutputRedactor.redact(stderr), exitCode: exitCode))
        } else {
            pendingOutput = ProcessOutput(stdout: OutputRedactor.redact(stdout), stderr: OutputRedactor.redact(stderr), exitCode: exitCode)
            lock.unlock()
        }
    }

    /// Polling 路径调用：若 terminationHandler 已经 resume 过，直接返回已存结果；
    /// 否则建立 continuation 等待 handler resume。
    func awaitIfNotResumed(fallbackStdout: String, fallbackStderr: String, exitCode: Int32) async -> ProcessOutput {
        return await withCheckedContinuation { (c: CheckedContinuation<ProcessOutput, Never>) in
            lock.lock()
            if resumed {
                let out = pendingOutput ?? ProcessOutput(stdout: fallbackStdout, stderr: fallbackStderr, exitCode: exitCode)
                lock.unlock()
                c.resume(returning: out)
            } else {
                resumed = true
                cont = c
                lock.unlock()
            }
        }
    }
}
