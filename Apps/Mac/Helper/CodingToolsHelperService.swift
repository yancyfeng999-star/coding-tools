import Foundation
import Installers

// MARK: - CodingToolsHelperService
//
// Helper 入口：监听 XPC 连接，每个连接对应 CodingToolsHelperProtocol 实例。
// 真正干活的逻辑委托给 `HelperInstallExecutor`（避免 main 把 IPC 和业务混在一起）。
//
// 注意：本类是 @objc + NSObjectProtocol，因为 NSXPCListener 期望的 delegate
// 接口是 NSObjectProtocol + ListenerDelegate。
//
// 阶段 9：完整接入所有 Installer Adapter。本轮先接入 NpmGlobalAdapter 验证
// 整条链路（App 沙箱 → XPC → Helper 调 npm）。

@objc(CodingToolsHelperService)
public final class CodingToolsHelperService: NSObject, CodingToolsHelperProtocol {

    private let executor: HelperInstallExecutor
    private let environment: HelperEnvironmentProbe

    public override init() {
        self.executor = HelperInstallExecutor()
        self.environment = HelperEnvironmentProbe()
        super.init()
    }

    // MARK: - CodingToolsHelperProtocol

    public func installTool(_ request: HelperInstallRequest, reply: @escaping @Sendable (HelperInstallResponse) -> Void) {
        executor.execute(
            planID: request.planID,
            toolID: request.toolID,
            actionType: request.actionType,
            actionJSON: request.actionJSON,
            reply: reply
        )
    }

    public func uninstallTool(_ request: HelperUninstallRequest, reply: @escaping @Sendable (HelperUninstallResponse) -> Void) {
        executor.executeUninstall(
            toolID: request.toolID,
            actionType: request.actionType,
            actionJSON: request.actionJSON,
            reply: reply
        )
    }

    public func checkEnvironment(_ request: HelperEnvironmentRequest, reply: @escaping @Sendable (HelperEnvironmentResponse) -> Void) {
        let env = environment.probe()
        reply(env)
    }

    public func cancelInstall(planID: String, reply: @escaping @Sendable (Bool) -> Void) {
        let cancelled = executor.cancel(planID: planID)
        reply(cancelled)
    }
}

// MARK: - Listener bootstrap
//
// XPC Listener 的标准启动模式：
// 1. Helper 进程入口调 `bootstrap()`（由 main.swift 触发）
// 2. 创建 NSXPCListener（service name = bundle id）
// 3. delegate.resume() 接受新连接，每个连接创建一个 CodingToolsHelperService 实例

public enum HelperBootstrap {

    /// 启动 XPC listener，永久持有直到进程被终止。
    public static func bootstrap(serviceName: String) {
        let listener = NSXPCListener(machServiceName: serviceName)
        listener.delegate = HelperListenerDelegate()
        listener.resume()
        // 防止进程退出（XPC listener 持有自己）
        RunLoop.current.run()
    }
}

private final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // 只接受本 App bundle id 的连接
        newConnection.exportedInterface = NSXPCInterface(with: CodingToolsHelperProtocol.self)
        newConnection.exportedObject = CodingToolsHelperService()
        newConnection.resume()
        return true
    }
}
