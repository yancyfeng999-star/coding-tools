import Foundation
import AppKit
import Domain
import ProcessExecution

// MARK: - Detection
//
// 工具检测：版本检测、路径检测、架构检测、App 启动能力。阶段 3 由子代理 A 实现。
// 数据契约（InstallationProbe / Architecture / HealthStatus）见 Domain 模块。
//
// 检测策略（按优先级）：
//   CLI 工具（launchCapability.type == .cli）：
//     1. 在 PATH（/opt/homebrew/bin, /usr/local/bin, /usr/bin, /Users/<u>/.local/bin, /Users/<u>/.cargo/bin）中查找
//     2. `which <cmd>` 兜底
//     3. 执行 `<cmd> --version` 解析版本
//   App 工具（launchCapability.type == .app）：
//     1. NSWorkspace.urlForApplication(withBundleIdentifier:)
//     2. 读 Info.plist 拿 version
//     3. codesign -dv 拿 Team ID
//   架构：
//     1. 对二进制：`file <path>` 或 `lipo -info`
//     2. 系统整体：`uname -m`（仅在 tool 缺失时用作 machine arch）

public protocol InstallationDetecting: Sendable {
    func probe(tool: Tool) async -> InstallationProbe
    func probeAll(tools: [Tool]) async -> [InstallationProbe]
    /// 系统架构：arm64 / x86_64
    func systemArchitecture() async -> Architecture
}

public protocol InstallationDiagnosing: Sendable {
    func installations(tool: Tool) async -> ToolInstallationReport
}

public final class InstallationDetector: InstallationDetecting, InstallationDiagnosing, @unchecked Sendable {
    private let executor: any ProcessExecuting
    private let fileManager: FileManager
    private let resolver: any CLIExecutableResolving

    public init(
        executor: any ProcessExecuting = ProcessExecutor(),
        fileManager: FileManager = .default,
        resolver: any CLIExecutableResolving = CLIExecutableResolver()
    ) {
        self.executor = executor
        self.fileManager = fileManager
        self.resolver = resolver
    }

    public func probe(tool: Tool) async -> InstallationProbe {
        // 优先按 launchCapability.type 分支
        if let lc = tool.launchCapability {
            switch lc.type {
            case .cli:
                return await probeCLI(tool: tool, command: lc.command ?? tool.slug)
            case .app:
                if let bid = lc.bundleID ?? tool.launchCapability?.bundleID {
                    return await probeApp(tool: tool, bundleID: bid)
                }
                return makeProbe(tool: tool, version: nil, path: nil, status: .notInstalled)
            case .url:
                return makeProbe(tool: tool, version: nil, path: nil, status: .notInstalled)
            case .none:
                return makeProbe(tool: tool, version: nil, path: nil, status: .notInstalled)
            }
        }
        // 没有 launchCapability 时按 installOptions 启发式
        for opt in tool.installOptions {
            switch opt.type {
            case .homebrewFormula, .homebrewCask, .miseTool, .npmGlobal:
                // npmGlobal：探测 CLI `command`（来自 launchCapability），
                // 没有就用 slug（npm 工具通常 `<slug>` 命令名）
                let name = opt.packageName ?? opt.toolName ?? tool.slug
                return await probeCLI(tool: tool, command: name)
            case .officialArtifact:
                if let bid = opt.bundleID {
                    return await probeApp(tool: tool, bundleID: bid)
                }
            }
        }
        return makeProbe(tool: tool, version: nil, path: nil, status: .notInstalled)
    }

    public func probeAll(tools: [Tool]) async -> [InstallationProbe] {
        await withTaskGroup(of: InstallationProbe.self) { group in
            for tool in tools {
                group.addTask { await self.probe(tool: tool) }
            }
            var result: [InstallationProbe] = []
            result.reserveCapacity(tools.count)
            for await probe in group {
                result.append(probe)
            }
            return result
        }
    }

    public func systemArchitecture() async -> Architecture {
        do {
            let out = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/uname"),
                arguments: ["-m"],
                timeout: .seconds(3)
            ))
            switch out.stdout.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "arm64": return .arm64
            case "x86_64": return .x86_64
            default: return currentArchFromHost()
            }
        } catch {
            return currentArchFromHost()
        }
    }

    public func installations(tool: Tool) async -> ToolInstallationReport {
        let command = command(for: tool)
        let resolved = resolver.resolve(command: command, toolID: tool.id)
        let installations = await withTaskGroup(of: DetectedToolInstallation.self) { group in
            for executable in resolved {
                group.addTask { await self.inspect(tool: tool, executable: executable) }
            }
            return await group.reduce(into: [DetectedToolInstallation]()) { $0.append($1) }
        }
        return ToolInstallationReport(toolID: tool.id, installations: installations)
    }

    // MARK: - CLI Probe

    private func probeCLI(tool: Tool, command: String) async -> InstallationProbe {
        let resolved = resolver.resolve(command: command, toolID: tool.id)
        guard let preferred = resolved.first else {
            return makeProbe(tool: tool, version: nil, path: nil, status: .notInstalled)
        }
        let inspected = await inspect(tool: tool, executable: preferred)
        let status: HealthStatus
        if inspected.failure == nil, inspected.version != nil {
            status = .installed
        } else if inspected.failure != nil {
            status = .broken
        } else {
            status = .broken
        }
        let arch = await detectBinaryArch(path: preferred.canonicalPath)
        return makeProbe(
            tool: tool,
            version: inspected.version,
            path: preferred.canonicalPath.path,
            arch: arch,
            status: status,
            installSource: preferred.source,
            failure: inspected.failure
        )
    }

    private func command(for tool: Tool) -> String {
        if let profile = AgentToolProfiles.profile(for: tool.id) {
            return profile.command
        }
        return tool.launchCapability?.command ?? tool.slug
    }

    private func inspect(tool: Tool, executable: ResolvedExecutable) async -> DetectedToolInstallation {
        let (version, failure) = await readVersion(tool: tool, executable: executable.canonicalPath)
        return DetectedToolInstallation(
            path: executable.path.path,
            canonicalPath: executable.canonicalPath.path,
            version: version,
            source: executable.source,
            isPreferred: executable.isPreferred,
            failure: failure
        )
    }

    private func readVersion(tool: Tool, executable: URL) async -> (String?, ProbeFailure?) {
        let attempts: [[String]]
        if let profile = AgentToolProfiles.profile(for: tool.id) {
            attempts = [profile.versionArguments]
        } else {
            attempts = [["--version"], ["-version"], ["version"]]
        }
        var lastFailure: ProbeFailure?
        for args in attempts {
            do {
                let out = try await executor.run(ProcessRequest(
                    executableURL: executable,
                    arguments: args,
                    timeout: .seconds(8)
                ))
                if out.exitCode != 0 {
                    lastFailure = ProbeFailure(
                        kind: .nonZeroExit,
                        redactedMessage: "version command exited \(out.exitCode)"
                    )
                    continue
                }
                let text = out.stdout + out.stderr
                if let version = Self.parseVersion(from: text) {
                    return (version, nil)
                }
                lastFailure = ProbeFailure(
                    kind: .versionUnparseable,
                    redactedMessage: "version output was not parseable"
                )
            } catch {
                lastFailure = failure(from: error)
            }
        }
        return (nil, lastFailure)
    }

    private func failure(from error: Error) -> ProbeFailure {
        switch error {
        case ProcessExecutionError.timeout:
            return ProbeFailure(kind: .timedOut, redactedMessage: "version command timed out")
        case ProcessExecutionError.launchFailed(let message):
            return ProbeFailure(kind: .launchFailed, redactedMessage: OutputRedactor.redact(message))
        default:
            return ProbeFailure(
                kind: .nonZeroExit,
                redactedMessage: OutputRedactor.redact(String(describing: error))
            )
        }
    }

    private func detectBinaryArch(path: URL) async -> Architecture? {
        do {
            let out = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/file"),
                arguments: [path.path],
                timeout: .seconds(3)
            ))
            let text = out.stdout.lowercased()
            if text.contains("arm64") { return .arm64 }
            if text.contains("x86_64") { return .x86_64 }
        } catch {
            // ignore
        }
        return nil
    }

    // MARK: - App Probe

    private func probeApp(tool: Tool, bundleID: String) async -> InstallationProbe {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return makeProbe(tool: tool, version: nil, path: nil, status: .notInstalled)
        }
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        var version: String? = nil
        if let data = try? Data(contentsOf: plistURL),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            version = dict["CFBundleShortVersionString"] as? String
        }
        let teamID = await detectTeamID(appURL: appURL)
        let arch = await detectBinaryArch(path: appURL.appendingPathComponent("Contents/MacOS").appendingPathComponent(Self.firstExecutable(in: appURL) ?? ""))
        return makeProbe(
            tool: tool,
            version: version,
            path: appURL.path,
            arch: arch,
            bundleID: bundleID,
            teamID: teamID,
            status: version == nil ? .broken : .installed
        )
    }

    private func detectTeamID(appURL: URL) async -> String? {
        do {
            let out = try await executor.run(ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/codesign"),
                arguments: ["-dv", "--format=xml", appURL.path],
                timeout: .seconds(3)
            ))
            // codesign -dv --format=xml 输出 plist XML；regex 简单抓 TeamIdentifier
            let pattern = #"<key>TeamIdentifier</key>\s*<string>([A-Z0-9]+)</string>"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let m = regex.firstMatch(
                   in: out.stderr + out.stdout,
                   range: NSRange((out.stderr + out.stdout).startIndex..., in: out.stderr + out.stdout)
               ),
               m.numberOfRanges > 1,
               let r = Range(m.range(at: 1), in: out.stderr + out.stdout) {
                return String((out.stderr + out.stdout)[r])
            }
        } catch {
            // ignore
        }
        return nil
    }

    private static func firstExecutable(in appURL: URL) -> String? {
        let macos = appURL.appendingPathComponent("Contents/MacOS")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: macos.path) else { return nil }
        return files.first
    }

    // MARK: - Helpers

    private func currentArchFromHost() -> Architecture {
        #if arch(arm64)
        return .arm64
        #elseif arch(x86_64)
        return .x86_64
        #else
        return .arm64
        #endif
    }

    private func makeProbe(
        tool: Tool,
        version: String?,
        path: String?,
        arch: Architecture? = nil,
        bundleID: String? = nil,
        teamID: String? = nil,
        status: HealthStatus,
        installSource: DetectedInstallSource? = nil,
        failure: ProbeFailure? = nil
    ) -> InstallationProbe {
        InstallationProbe(
            toolID: tool.id,
            installedVersion: version,
            detectedPath: path,
            architecture: arch,
            bundleID: bundleID,
            teamID: teamID,
            healthStatus: status,
            installSource: installSource,
            failure: failure
        )
    }

    /// 解析常见 `--version` / `-version` 输出中的版本号。
    /// 覆盖：git version 2.46.0、Python 3.12.4、go version go1.23.0 darwin/arm64、
    /// node v22.7.5、rustc 1.80.0、Visual Studio Code 1.90.0 等。
    static func parseVersion(from text: String) -> String? {
        // 1. 第一个看起来像 semver / dotted 版本
        let pattern = #"(\d+\.\d+(?:\.\d+)?(?:[\.\-+][A-Za-z0-9.\-]+)*)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           m.numberOfRanges > 1,
           let r = Range(m.range(at: 1), in: text) {
            return String(text[r])
        }
        return nil
    }
}
