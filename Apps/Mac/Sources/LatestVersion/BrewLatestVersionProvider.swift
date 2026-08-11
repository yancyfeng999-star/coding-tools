import Foundation
import ProcessExecution
import Domain

// MARK: - BrewLatestVersionProvider
//
// 走 `brew info --json=v2 <package>` 拿 latest version。
// 失败 / 超时 / 不在 brew 仓库 → 返回 nil。
//
// 3s 硬超时（brew info 首次可能 5-10s；超时后 silent skip）。

public final class BrewLatestVersionProvider: LatestVersionProvider, @unchecked Sendable {

    private let executor: any ProcessExecuting
    private let pathResolver: HomebrewPathResolver
    private let timeout: TimeInterval

    public init(
        executor: any ProcessExecuting = ProcessExecutor(),
        pathResolver: HomebrewPathResolver = HomebrewPathResolver(),
        timeout: TimeInterval = 3.0
    ) {
        self.executor = executor
        self.pathResolver = pathResolver
        self.timeout = timeout
    }

    public func latestVersion(toolID: String, installedVersion: String?) async -> String? {
        // 解析 brew 路径
        guard let brew = await resolveBrewPath() else { return nil }
        // 跑 `brew info --json=v2 <package>`（formula + cask 都用这个）
        let request = ProcessRequest(
            executableURL: brew,
            arguments: ["info", "--json=v2", toolID],
            timeout: .seconds(Int(timeout))
        )
        let result: ProcessOutput
        do {
            result = try await executor.run(request)
        } catch {
            return nil
        }
        guard result.exitCode == 0 else { return nil }
        // 解析 JSON
        return Self.parseBrewInfoJSON(Data(result.stdout.utf8), toolID: toolID)
    }

    private func resolveBrewPath() async -> URL? {
        await pathResolver.resolveBrew(executor: executor)
    }

    /// brew info --json=v2 返回的顶层是 `{"formulae": [...], "casks": [...]}`
    /// 任意一个数组里含该 package 就取 versions.stable。
    /// 公开让测试直接验证。
    public static func parseBrewInfoJSON(_ data: Data, toolID: String) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        // Formulae
        if let formulae = json["formulae"] as? [[String: Any]] {
            for formula in formulae {
                if let name = formula["name"] as? String, name == toolID {
                    if let v = (formula["versions"] as? [String: Any])?["stable"] as? String,
                       !v.isEmpty {
                        return v
                    }
                }
            }
        }
        // Casks
        if let casks = json["casks"] as? [[String: Any]] {
            for cask in casks {
                if let token = cask["token"] as? String, token == toolID {
                    if let v = cask["version"] as? String, !v.isEmpty {
                        return v
                    }
                }
            }
        }
        return nil
    }
}

// MARK: - HomebrewPathResolver (共用)
//
// 复制 Installers 模块的实现，避免 LatestVersion 依赖 Installers
// （保持模块边界独立）。

public final class HomebrewPathResolver: Sendable {
    public init() {}

    public func resolveBrew(executor: any ProcessExecuting) async -> URL? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/usr/bin/brew",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        // Fallback: which brew
        do {
            let out = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/which"),
                arguments: ["brew"],
                timeout: .seconds(5)
            ))
            let trimmed = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, FileManager.default.isExecutableFile(atPath: trimmed) {
                return URL(fileURLWithPath: trimmed)
            }
        } catch {
            // ignore
        }
        return nil
    }
}
