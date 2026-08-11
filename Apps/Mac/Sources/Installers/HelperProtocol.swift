import Foundation

// MARK: - Helper XPC Protocol
//
// Coding Tools Helper 是一个独立的 XPC service（特权进程），
// 负责执行 brew / npm / curl / 文件写入等 App 主进程在 sandbox 下不能做的操作。
//
// 架构：
//   Coding Tools.app  ──XPC──▶  CodingToolsHelper.xpc
//   (sandbox: ON)               (no sandbox; 按需 entitlements)
//
// 强类型消息：所有请求/响应都是 Codable + @objc，避免 NSXPCConnection 的字典歧义。
// 协议名：com.codingtools.helper.protocol（与 Helper Info.plist NSExtension 一致）

@objc(CodingToolsHelperProtocol)
public protocol CodingToolsHelperProtocol {
    /// 安装一个工具（npm-global / homebrew / official-artifact / mise）。
    func installTool(_ request: HelperInstallRequest, reply: @escaping @Sendable (HelperInstallResponse) -> Void)

    /// 卸载一个工具（brew uninstall / npm uninstall -g）。
    func uninstallTool(_ request: HelperUninstallRequest, reply: @escaping @Sendable (HelperUninstallResponse) -> Void)

    /// 检查环境（brew 是否在 PATH、npm 是否可用、PATH 探测）。
    func checkEnvironment(_ request: HelperEnvironmentRequest, reply: @escaping @Sendable (HelperEnvironmentResponse) -> Void)

    /// 取消正在进行的安装。
    func cancelInstall(planID: String, reply: @escaping @Sendable (Bool) -> Void)
}

/// App → Helper 端回调协议（Helper 主动推进度 / 日志到 App）。
@objc(CodingToolsClientProtocol)
public protocol CodingToolsClientProtocol {
    func progressEvent(_ event: HelperProgressEvent)
    func logChunk(_ chunk: HelperLogChunk)
}

// MARK: - Wire types

@objc public final class HelperInstallRequest: NSObject, NSSecureCoding, @unchecked Sendable {
    public let planID: String
    public let toolID: String
    public let actionType: String   // InstallActionType.rawValue
    public let actionJSON: Data     // InstallAction encoded as JSON（用 wire-stable shape）

    public init(planID: String, toolID: String, actionType: String, actionJSON: Data) {
        self.planID = planID
        self.toolID = toolID
        self.actionType = actionType
        self.actionJSON = actionJSON
        super.init()
    }

    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(planID, forKey: "planID")
        coder.encode(toolID, forKey: "toolID")
        coder.encode(actionType, forKey: "actionType")
        coder.encode(actionJSON, forKey: "actionJSON")
    }
    public init?(coder: NSCoder) {
        self.planID = (coder.decodeObject(of: NSString.self, forKey: "planID") as? String) ?? ""
        self.toolID = (coder.decodeObject(of: NSString.self, forKey: "toolID") as? String) ?? ""
        self.actionType = (coder.decodeObject(of: NSString.self, forKey: "actionType") as? String) ?? ""
        let _d = coder.decodeObject(of: NSData.self, forKey: "actionJSON") as? NSData; self.actionJSON = _d.map { Data($0) } ?? Data()
        super.init()
    }
}

@objc public final class HelperInstallResponse: NSObject, NSSecureCoding, @unchecked Sendable {
    public let success: Bool
    public let exitCode: Int32
    public let resolvedVersion: String?
    public let errorMessage: String?

    public init(success: Bool, exitCode: Int32, resolvedVersion: String?, errorMessage: String?) {
        self.success = success
        self.exitCode = exitCode
        self.resolvedVersion = resolvedVersion
        self.errorMessage = errorMessage
        super.init()
    }

    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(success, forKey: "success")
        coder.encode(exitCode, forKey: "exitCode")
        coder.encode(resolvedVersion as NSString?, forKey: "resolvedVersion")
        coder.encode(errorMessage as NSString?, forKey: "errorMessage")
    }
    public init?(coder: NSCoder) {
        self.success = coder.decodeBool(forKey: "success")
        self.exitCode = coder.decodeInt32(forKey: "exitCode")
        self.resolvedVersion = coder.decodeObject(of: NSString.self, forKey: "resolvedVersion") as? String
        self.errorMessage = coder.decodeObject(of: NSString.self, forKey: "errorMessage") as? String
        super.init()
    }
}

@objc public final class HelperUninstallRequest: NSObject, NSSecureCoding, @unchecked Sendable {
    public let toolID: String
    public let actionType: String
    public let actionJSON: Data

    public init(toolID: String, actionType: String, actionJSON: Data) {
        self.toolID = toolID
        self.actionType = actionType
        self.actionJSON = actionJSON
        super.init()
    }

    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(toolID, forKey: "toolID")
        coder.encode(actionType, forKey: "actionType")
        coder.encode(actionJSON, forKey: "actionJSON")
    }
    public init?(coder: NSCoder) {
        self.toolID = (coder.decodeObject(of: NSString.self, forKey: "toolID") as? String) ?? ""
        self.actionType = (coder.decodeObject(of: NSString.self, forKey: "actionType") as? String) ?? ""
        let _d = coder.decodeObject(of: NSData.self, forKey: "actionJSON") as? NSData; self.actionJSON = _d.map { Data($0) } ?? Data()
        super.init()
    }
}

@objc public final class HelperUninstallResponse: NSObject, NSSecureCoding, @unchecked Sendable {
    public let success: Bool
    public let exitCode: Int32
    public let errorMessage: String?

    public init(success: Bool, exitCode: Int32, errorMessage: String?) {
        self.success = success
        self.exitCode = exitCode
        self.errorMessage = errorMessage
        super.init()
    }

    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(success, forKey: "success")
        coder.encode(exitCode, forKey: "exitCode")
        coder.encode(errorMessage as NSString?, forKey: "errorMessage")
    }
    public init?(coder: NSCoder) {
        self.success = coder.decodeBool(forKey: "success")
        self.exitCode = coder.decodeInt32(forKey: "exitCode")
        self.errorMessage = coder.decodeObject(of: NSString.self, forKey: "errorMessage") as? String
        super.init()
    }
}

@objc public final class HelperEnvironmentRequest: NSObject, NSSecureCoding, @unchecked Sendable {
    public override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {}
    public init?(coder: NSCoder) { super.init() }
}

@objc public final class HelperEnvironmentResponse: NSObject, NSSecureCoding, @unchecked Sendable {
    public let brewPath: String?
    public let npmPath: String?
    public let misePath: String?
    public let homeDirectory: String
    public let arch: String

    public init(brewPath: String?, npmPath: String?, misePath: String?, homeDirectory: String, arch: String) {
        self.brewPath = brewPath
        self.npmPath = npmPath
        self.misePath = misePath
        self.homeDirectory = homeDirectory
        self.arch = arch
        super.init()
    }

    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(brewPath as NSString?, forKey: "brewPath")
        coder.encode(npmPath as NSString?, forKey: "npmPath")
        coder.encode(misePath as NSString?, forKey: "misePath")
        coder.encode(homeDirectory, forKey: "homeDirectory")
        coder.encode(arch, forKey: "arch")
    }
    public init?(coder: NSCoder) {
        self.brewPath = coder.decodeObject(of: NSString.self, forKey: "brewPath") as String?
        self.npmPath = coder.decodeObject(of: NSString.self, forKey: "npmPath") as String?
        self.misePath = coder.decodeObject(of: NSString.self, forKey: "misePath") as String?
        self.homeDirectory = (coder.decodeObject(of: NSString.self, forKey: "homeDirectory") as? String) ?? "/"
        self.arch = (coder.decodeObject(of: NSString.self, forKey: "arch") as? String) ?? "unknown"
        super.init()
    }
}

@objc public final class HelperProgressEvent: NSObject, NSSecureCoding, @unchecked Sendable {
    public let planID: String
    public let stage: String   // InstallProgress.Stage.rawValue
    public let message: String
    public let percentage: NSNumber?

    public init(planID: String, stage: String, message: String, percentage: NSNumber?) {
        self.planID = planID
        self.stage = stage
        self.message = message
        self.percentage = percentage
        super.init()
    }

    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(planID, forKey: "planID")
        coder.encode(stage, forKey: "stage")
        coder.encode(message, forKey: "message")
        coder.encode(percentage, forKey: "percentage")
    }
    public init?(coder: NSCoder) {
        self.planID = (coder.decodeObject(of: NSString.self, forKey: "planID") as? String) ?? ""
        self.stage = (coder.decodeObject(of: NSString.self, forKey: "stage") as? String) ?? ""
        self.message = (coder.decodeObject(of: NSString.self, forKey: "message") as? String) ?? ""
        self.percentage = coder.decodeObject(of: NSNumber.self, forKey: "percentage")
        super.init()
    }
}

@objc public final class HelperLogChunk: NSObject, NSSecureCoding, @unchecked Sendable {
    public let planID: String
    public let stream: String   // "stdout" | "stderr"
    public let data: Data        // 已脱敏

    public init(planID: String, stream: String, data: Data) {
        self.planID = planID
        self.stream = stream
        self.data = data
        super.init()
    }

    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(planID, forKey: "planID")
        coder.encode(stream, forKey: "stream")
        coder.encode(data, forKey: "data")
    }
    public init?(coder: NSCoder) {
        self.planID = (coder.decodeObject(of: NSString.self, forKey: "planID") as? String) ?? ""
        self.stream = (coder.decodeObject(of: NSString.self, forKey: "stream") as? String) ?? ""
        let _d = coder.decodeObject(of: NSData.self, forKey: "data") as? NSData; self.data = _d.map { Data($0) } ?? Data()
        super.init()
    }
}
