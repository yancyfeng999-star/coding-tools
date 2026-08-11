import Foundation
import ProcessExecution
import Domain

// MARK: - NpmLatestVersionProvider
//
// 走 `npm view <package> version` 拿 latest version。
// 失败 / 超时 / package 不在 npm → 返回 nil。
//
// 3s 硬超时（npm registry 偶尔慢）。

public final class NpmLatestVersionProvider: LatestVersionProvider, @unchecked Sendable {

    private let executor: any ProcessExecuting
    private let npmPath: String
    private let timeout: TimeInterval

    public init(
        executor: any ProcessExecuting = ProcessExecutor(),
        npmPath: String = "/usr/bin/npm",
        timeout: TimeInterval = 3.0
    ) {
        self.executor = executor
        self.npmPath = npmPath
        self.timeout = timeout
    }

    public func latestVersion(toolID: String, installedVersion: String?) async -> String? {
        // toolID 可能是 "@anthropic-ai/claude-code"（scoped package），直接传
        guard FileManager.default.isExecutableFile(atPath: npmPath) else { return nil }
        let request = ProcessRequest(
            executableURL: URL(fileURLWithPath: npmPath),
            arguments: ["view", toolID, "version"],
            timeout: .seconds(Int(timeout))
        )
        let result: ProcessOutput
        do {
            result = try await executor.run(request)
        } catch {
            return nil
        }
        guard result.exitCode == 0 else { return nil }
        // npm view <pkg> version 输出形如 "1.2.3\n"，去空白即可
        let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
