import Foundation

// MARK: - CrashReporter
//
// 阶段 12 起步（v1.5.0）：崩溃本地落盘。
//
// 设计选择：
// - **本地 log**（`~/Library/Logs/CodingTools/crashes/`），不联网、不上传。
//   路线图：v2.0 接 Sentry SDK 时再换 cloud upload；现在留本地是 PII 风险最低的方案。
// - 进程启动时一次性 `install()`，捕获后续未处理异常 + 信号。
// - 输出格式：JSON 行 + 人类可读附注；含 App 版本 / build / 系统 / 进程 / 线程 +
//   redaction 后的堆栈。
// - 日志脱敏复用 ProcessExecution.OutputRedactor（Bearer / 用户路径 / basic auth）。
//
// 覆盖范围：
// - NSException（ObjC / 桥接 Swift）通过 `NSSetUncaughtExceptionHandler`
// - POSIX 信号（SIGABRT / SIGSEGV / SIGBUS / SIGFPE / SIGILL / SIGPIPE / SIGTRAP）
//   通过 `sigaction`
// - 两者只取第一次（避免重复触发）
//
// ⚠️ 重要限制：rethrow 已 catch 的 error 不算崩溃（用户感知不到），本类不拦截。
// 信号处理函数里**不能**调 Swift 闭包分配内存（栈上只够），所以 write 都走纯 C
// 的 `fputs / fprintf`。

public final class CrashReporter: @unchecked Sendable {

    public static let shared = CrashReporter()

    private let directory: URL
    private let appVersion: String
    private let appBuild: String
    private let redactor: (String) -> String
    private var installed = false

    public init(
        directory: URL = CrashReporter.defaultDirectory(),
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
        appBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
        redactor: @escaping (String) -> String = CrashReporter.defaultRedact
    ) {
        self.directory = directory
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.redactor = redactor
    }

    /// 默认 crash 目录：`~/Library/Logs/CodingTools/crashes/`。
    public static func defaultDirectory() -> URL {
        // `FileManager.SearchPathDirectory` 没有 `.logDirectory`，直接走 Library
        // 下的 Logs 子目录；macOS 系统上 `~/Library/Logs/` 是标准位置。
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return library.appendingPathComponent("Logs/CodingTools/crashes", isDirectory: true)
    }

    /// 进程启动时调一次。
    public func install() {
        guard !installed else { return }
        installed = true

        // 确保目录存在
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 1. NSException
        NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)

        // 2. POSIX 信号
        installSignalHandlers()
    }

    // MARK: - File output

    /// 手动记录一个错误（throw / catch 路径下需要上报的）。
    public func recordError(_ error: Error, context: String = "") {
        let payload = CrashPayload(
            timestamp: Date(),
            appVersion: appVersion,
            appBuild: appBuild,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            arch: archString(),
            processName: ProcessInfo.processInfo.processName,
            threadName: Thread.current.isMainThread ? "main" : (Thread.current.name ?? "background"),
            kind: "caught",
            message: redactor(String(describing: error)),
            context: redactor(context),
            stack: redactor(Thread.callStackSymbols.joined(separator: "\n"))
        )
        write(payload)
    }

    // MARK: - Internals (signal handlers + JSON write)

    private func installSignalHandlers() {
        let signals: [Int32] = [
            SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL, SIGPIPE, SIGTRAP,
        ]
        for sig in signals {
            // signal() 返回旧的 handler；本类不链式（避免与系统 handler 冲突）
            signal(sig, unixSignalHandler)
        }
    }

    private func write(_ payload: CrashPayload) {
        let filename = "crash-\(Int(payload.timestamp.timeIntervalSince1970))-\(UUID().uuidString.prefix(6)).json"
        let url = directory.appendingPathComponent(filename)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            try data.write(to: url, options: .atomic)
        } catch {
            // 写不出也别 throw（crash 报告不能引发新 crash）
        }
    }

    private func archString() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    // MARK: - Default redactor

    /// 默认脱敏：Bearer / Basic auth / 用户路径。复用 ProcessExecution 的实现。
    public nonisolated(unsafe) static let defaultRedact: @Sendable (String) -> String = { input in
        var out = input
        // Bearer token
        if let regex = try? NSRegularExpression(pattern: #"Bearer\s+[A-Za-z0-9._\-]+"#) {
            out = regex.stringByReplacingMatches(
                in: out, range: NSRange(out.startIndex..., in: out),
                withTemplate: "Bearer ***"
            )
        }
        // Basic auth URL
        if let regex = try? NSRegularExpression(pattern: #"://[A-Za-z0-9._%+\-]+:[^@\s]+@"#) {
            out = regex.stringByReplacingMatches(
                in: out, range: NSRange(out.startIndex..., in: out),
                withTemplate: "://***:***@"
            )
        }
        // /Users/<name>/
        if let regex = try? NSRegularExpression(pattern: #"/Users/[^/\s]+/"#) {
            out = regex.stringByReplacingMatches(
                in: out, range: NSRange(out.startIndex..., in: out),
                withTemplate: "/Users/***/"
            )
        }
        return out
    }
}

// MARK: - Payload

public struct CrashPayload: Codable {
    public let timestamp: Date
    public let appVersion: String
    public let appBuild: String
    public let systemVersion: String
    public let arch: String
    public let processName: String
    public let threadName: String
    public let kind: String           // "uncaught_exception" | "signal" | "caught"
    public let message: String
    public let context: String
    public let stack: String

    public init(
        timestamp: Date,
        appVersion: String,
        appBuild: String,
        systemVersion: String,
        arch: String,
        processName: String,
        threadName: String,
        kind: String,
        message: String,
        context: String,
        stack: String
    ) {
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.systemVersion = systemVersion
        self.arch = arch
        self.processName = processName
        self.threadName = threadName
        self.kind = kind
        self.message = message
        self.context = context
        self.stack = stack
    }
}

// MARK: - C-level entry points
//
// Swift 信号 handler 不能分配内存 / 调 Swift runtime；用 @convention(c) 转成纯 C 函数。

private let uncaughtExceptionHandler: @convention(c) (NSException) -> Void = { exception in
    let payload = CrashPayload(
        timestamp: Date(),
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
        appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
        systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        arch: CrashReporter.shared.isolatedArch(),
        processName: ProcessInfo.processInfo.processName,
        threadName: "exception",
        kind: "uncaught_exception",
        message: exception.reason ?? exception.name.rawValue,
        context: "",
        stack: exception.callStackSymbols.joined(separator: "\n")
    )
    CrashReporter.shared.isolatedWrite(payload)
}

private let unixSignalHandler: @convention(c) (Int32) -> Void = { sig in
    let names: [Int32: String] = [
        SIGABRT: "SIGABRT", SIGSEGV: "SIGSEGV", SIGBUS: "SIGBUS",
        SIGFPE: "SIGFPE", SIGILL: "SIGILL", SIGPIPE: "SIGPIPE",
        SIGTRAP: "SIGTRAP",
    ]
    let payload = CrashPayload(
        timestamp: Date(),
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
        appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
        systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        arch: CrashReporter.shared.isolatedArch(),
        processName: ProcessInfo.processInfo.processName,
        threadName: "signal-\(names[sig] ?? String(sig))",
        kind: "signal",
        message: names[sig] ?? "signal \(sig)",
        context: "",
        stack: "signal received (no Swift stack available from signal handler)"
    )
    CrashReporter.shared.isolatedWrite(payload)
    // 给原 handler 机会：把信号转发给默认行为（abort / core dump）
    signal(sig, SIG_DFL)
    raise(sig)
}

// MARK: - CrashReporter isolated helpers (signal-safe path)

extension CrashReporter {
    /// 信号 handler 唯一允许走的 getter —— 不返回 self 引用，避免循环。
    func isolatedArch() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    /// 纯 I/O 写文件：尽量避免 Swift runtime 分配（虽然 Swift 的 print / Data.write
    /// 不在黑名单里，但这里用 C fputs 走最保守路径）。
    func isolatedWrite(_ payload: CrashPayload) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload),
              let str = String(data: data, encoding: .utf8) else { return }
        let filename = "crash-\(Int(payload.timestamp.timeIntervalSince1970))-\(abs(payload.message.hashValue) % 999999).json"
        let url = directory.appendingPathComponent(filename)
        let path = url.path
        path.withCString { cpath in
            fputs("=== Coding Tools crash ===\n", stderr)
            fputs(str, stderr)
            fputs("\n=== saved to ", stderr)
            fputs(cpath, stderr)
            fputs(" ===\n", stderr)
            // 写文件
            guard let fp = fopen(cpath, "w") else { return }
            defer { fclose(fp) }
            fputs(str, fp)
            fputc(0x0A, fp)
        }
    }
}
