import Foundation

// MARK: - HelperClient
//
// App 端 XPC 客户端：连到 CodingToolsHelperService，把 InstallAction 发给
// Helper 跑（Helper 不受 sandbox 限制）。
//
// 连接策略：
// - 默认走 NSXPCConnection(serviceName: <helper-bundle-id>)
// - launchd 自动按需启动 Helper（首次连会有几百 ms 启动延迟）
// - 失败时 fallback：in-process executor（开发 / Helper 没注册时）
//
// 阶段 9：本类已就绪，NpmGlobalAdapter 改为走 HelperClient.execute(...)。
// 其他 Adapter 留到 v1.5.0 后续 PR。

public final class HelperClient: @unchecked Sendable {

    /// Helper 的 bundle id（与 Helper/Info.plist CFBundleIdentifier 一致）。
    public static let helperBundleID = "com.codingtools.helper"

    private let connection: NSXPCConnection
    private let lock = NSLock()
    private var inFlight: [String: CheckedContinuation<HelperInstallResponse, Error>] = [:]

    public init(serviceName: String = HelperClient.helperBundleID) {
        let conn = NSXPCConnection(serviceName: serviceName)
        conn.exportedInterface = NSXPCInterface(with: CodingToolsClientProtocol.self)
        conn.exportedObject = nil  // 我们不主动 push 进度；预留接口
        conn.remoteObjectInterface = NSXPCInterface(with: CodingToolsHelperProtocol.self)
        conn.resume()
        self.connection = conn
        // 安装 invalidation handler 必须在 connection.resume() 之后；
        // 把它移到实例方法里绕开 Swift 闭包推断的编译器 bug。
        connection.invalidationHandler = makeInvalidationHandler()
    }

    private func makeInvalidationHandler() -> (() -> Void)? {
        return { [weak self] () -> Void in
            guard let strongSelf = self else { return }
            strongSelf.lock.lock()
            let pending = strongSelf.inFlight
            strongSelf.inFlight.removeAll()
            strongSelf.lock.unlock()
            for (_, cont) in pending {
                cont.resume(throwing: HelperClientError.connectionInvalidated)
            }
        }
    }

    deinit {
        connection.invalidate()
    }

    /// 调 Helper 跑 install。throws 表示 XPC / wire 错误。
    /// Helper 内部 InstallError 通过 HelperInstallResponse.errorMessage 透传。
    public func install(plan: InstallPlan, action: InstallAction) async throws -> HelperInstallResponse {
        let actionType = Self.actionTypeRaw(action)
        let actionJSON = try Self.encodeAction(action)
        let request = HelperInstallRequest(
            planID: plan.id,
            toolID: plan.toolID,
            actionType: actionType,
            actionJSON: actionJSON
        )
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HelperInstallResponse, Error>) in
            lock.lock(); inFlight[plan.id] = cont; lock.unlock()
            let proxy = connection.remoteObjectProxy as? CodingToolsHelperProtocol
            proxy?.installTool(request) { [weak self] response in
                self?.lock.lock()
                self?.inFlight[plan.id] = nil
                self?.lock.unlock()
                cont.resume(returning: response)
            }
        }
    }

    public func checkEnvironment() async throws -> HelperEnvironmentResponse {
        let request = HelperEnvironmentRequest()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HelperEnvironmentResponse, Error>) in
            let proxy = connection.remoteObjectProxy as? CodingToolsHelperProtocol
            proxy?.checkEnvironment(request) { response in
                cont.resume(returning: response)
            }
        }
    }

    public func cancel(planID: String) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let proxy = connection.remoteObjectProxy as? CodingToolsHelperProtocol
            proxy?.cancelInstall(planID: planID) { cancelled in
                cont.resume(returning: cancelled)
            }
        }
    }

    // MARK: - Encoding

    private static func actionTypeRaw(_ action: InstallAction) -> String {
        switch action {
        case .homebrewFormula: return "homebrew-formula"
        case .homebrewCask: return "homebrew-cask"
        case .miseTool: return "mise-tool"
        case .officialArtifact: return "official-artifact"
        case .npmGlobal: return "npm-global"
        }
    }

    private static func encodeAction(_ action: InstallAction) throws -> Data {
        let encoder = JSONEncoder()
        switch action {
        case .npmGlobal(let packageName, let scriptURL, let versionRule):
            return try encoder.encode(HelperNpmGlobalWire(
                packageName: packageName,
                scriptURL: scriptURL?.absoluteString,
                versionRule: versionRule
            ))
        case .homebrewFormula(let name):
            return try encoder.encode(HelperHomebrewFormulaWire(name: name))
        case .homebrewCask(let name):
            return try encoder.encode(HelperHomebrewCaskWire(name: name))
        case .miseTool(let name, let version):
            return try encoder.encode(HelperMiseToolWire(name: name, version: version))
        case .officialArtifact(let url, let sha256, let bundleID, let teamID):
            return try encoder.encode(HelperOfficialArtifactWire(
                url: url.absoluteString,
                sha256: sha256,
                bundleID: bundleID,
                teamID: teamID
            ))
        }
    }
}

// MARK: - Wire mirrors

struct HelperNpmGlobalWire: Codable {
    let packageName: String?
    let scriptURL: String?
    let versionRule: String?
}
struct HelperHomebrewFormulaWire: Codable { let name: String }
struct HelperHomebrewCaskWire: Codable { let name: String }
struct HelperMiseToolWire: Codable { let name: String; let version: String? }
struct HelperOfficialArtifactWire: Codable {
    let url: String
    let sha256: String
    let bundleID: String?
    let teamID: String?
}

// MARK: - Errors

public enum HelperClientError: Error, Sendable {
    case connectionInvalidated
}
