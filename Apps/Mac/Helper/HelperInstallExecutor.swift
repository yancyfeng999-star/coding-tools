import Foundation
import Installers
import ProcessExecution
import Domain

// MARK: - HelperInstallExecutor
//
// 真正跑安装逻辑的层。负责把 wire JSON 反序列化成 InstallAction，
// 走对应的 Installer Adapter，跑完回 HelperInstallResponse。
//
// 阶段 9：本轮只接 NpmGlobalAdapter（npm 路径最简单，权限最少）。
// Homebrew / Mise / OfficialArtifact 留到 v1.5.0 后续 PR。

public final class HelperInstallExecutor: @unchecked Sendable {

    private var inFlight: [String: Task<Void, Never>] = [:]
    private let lock = NSLock()

    public init() {}

    public func execute(
        planID: String,
        toolID: String,
        actionType: String,
        actionJSON: Data,
        reply: @escaping @Sendable (HelperInstallResponse) -> Void
    ) {
        guard let action = decode(actionType: actionType, data: actionJSON) else {
            reply(HelperInstallResponse(
                success: false,
                exitCode: -1,
                resolvedVersion: nil,
                errorMessage: "unknown actionType: \(actionType)"
            ))
            return
        }
        let task = Task {
            await self.run(planID: planID, toolID: toolID, action: action, reply: reply)
        }
        lock.withLock { inFlight[planID] = task }
    }

    public func executeUninstall(
        toolID: String,
        actionType: String,
        actionJSON: Data,
        reply: @escaping (HelperUninstallResponse) -> Void
    ) {
        // 阶段 9 stub：本轮只实现 install，uninstall 留 TODO
        reply(HelperUninstallResponse(
            success: false,
            exitCode: -1,
            errorMessage: "uninstall not yet implemented in helper (v1.5.0 follow-up)"
        ))
        _ = (toolID, actionType, actionJSON)  // silence unused
    }

    public func cancel(planID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let task = inFlight[planID] else { return false }
        task.cancel()
        inFlight[planID] = nil
        return true
    }

    // MARK: - Internals

    private func decode(actionType: String, data: Data) -> InstallAction? {
        // 用 JSONEncoder 形状（与 App 端 InstallAction Codable 一致）
        let decoder = JSONDecoder()
        switch actionType {
        case "npm-global":
            return try? decoder.decode(NpmGlobalWire.self, from: data).toDomain()
        case "homebrew-formula":
            return try? decoder.decode(HomebrewFormulaWire.self, from: data).toDomain()
        case "homebrew-cask":
            return try? decoder.decode(HomebrewCaskWire.self, from: data).toDomain()
        case "mise-tool":
            return try? decoder.decode(MiseToolWire.self, from: data).toDomain()
        case "official-artifact":
            return try? decoder.decode(OfficialArtifactWire.self, from: data).toDomain()
        default:
            return nil
        }
    }

    private func run(
        planID: String,
        toolID: String,
        action: InstallAction,
        reply: @escaping @Sendable (HelperInstallResponse) -> Void
    ) async {
        let registry = AdapterRegistry.defaultRegistry()
        let actionType = InstallActionType(rawValue: actionTypeRaw(action)) ?? .npmGlobal
        guard let adapter = registry.adapter(for: actionType) else {
            reply(HelperInstallResponse(
                success: false,
                exitCode: -1,
                resolvedVersion: nil,
                errorMessage: "no adapter for \(actionType.rawValue)"
            ))
            return
        }
        do {
            let plan = try await adapter.plan(toolID: toolID, action: action)
            let result = try await adapter.execute(plan, progress: nil)
            reply(HelperInstallResponse(
                success: result.exitCode == 0,
                exitCode: result.exitCode,
                resolvedVersion: result.resolvedVersion,
                errorMessage: result.exitCode == 0 ? nil : "non-zero exit: \(result.exitCode)"
            ))
        } catch {
            reply(HelperInstallResponse(
                success: false,
                exitCode: -1,
                resolvedVersion: nil,
                errorMessage: String(describing: error)
            ))
        }
        // 异步上下文下用 lock.withLock（async-safe）
        lock.withLock { inFlight[planID] = nil }
    }

    private func actionTypeRaw(_ action: InstallAction) -> String {
        switch action {
        case .homebrewFormula: return "homebrew-formula"
        case .homebrewCask: return "homebrew-cask"
        case .miseTool: return "mise-tool"
        case .officialArtifact: return "official-artifact"
        case .npmGlobal: return "npm-global"
        }
    }
}

// MARK: - Wire types (Helper 反序列化 JSON 用)
//
// InstallAction 在源码里是 enum with associated values（Codable 形状稳定但跨进程
// wire 必须自己定义 mirror）。本轮只 npm-global 用得上，其余 stub。

struct NpmGlobalWire: Codable {
    let packageName: String?
    let scriptURL: String?
    let versionRule: String?
    func toDomain() -> InstallAction {
        InstallAction.npmGlobal(
            packageName: packageName,
            scriptURL: scriptURL.flatMap { URL(string: $0) },
            versionRule: versionRule
        )
    }
}

struct HomebrewFormulaWire: Codable {
    let name: String
    func toDomain() -> InstallAction { .homebrewFormula(name: name) }
}

struct HomebrewCaskWire: Codable {
    let name: String
    func toDomain() -> InstallAction { .homebrewCask(name: name) }
}

struct MiseToolWire: Codable {
    let name: String
    let version: String?
    func toDomain() -> InstallAction { .miseTool(name: name, version: version) }
}

struct OfficialArtifactWire: Codable {
    let url: String
    let sha256: String
    let bundleID: String?
    let teamID: String?
    func toDomain() -> InstallAction {
        .officialArtifact(
            url: URL(string: url)!,
            sha256: sha256,
            bundleID: bundleID,
            teamID: teamID
        )
    }
}

// MARK: - HelperEnvironmentProbe

public final class HelperEnvironmentProbe {
    public init() {}

    public func probe() -> HelperEnvironmentResponse {
        let brew = which("brew")
        let npm = which("npm")
        let mise = which("mise")
        let home = NSHomeDirectory()
        let arch: String
        #if arch(arm64)
        arch = "arm64"
        #elseif arch(x86_64)
        arch = "x86_64"
        #else
        arch = "unknown"
        #endif
        return HelperEnvironmentResponse(
            brewPath: brew,
            npmPath: npm,
            misePath: mise,
            homeDirectory: home,
            arch: arch
        )
    }

    private func which(_ name: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }
}
