import Foundation
import AppKit
import Domain

// MARK: - Launching
//
// 工具启动：CLI / App / URL / 项目。阶段 3-4 由子代理 A/B 实现。

public enum LaunchTarget: Hashable, Sendable {
    case cli(command: String, arguments: [String], openInTerminal: Bool)
    case app(bundleID: String)
    case url(URL)
    case project(path: URL)
}

public protocol Launching: Sendable {
    func launch(_ target: LaunchTarget) async throws
}

public actor MacLauncher: Launching {
    public init() {}

    public func launch(_ target: LaunchTarget) async throws {
        switch target {
        case .cli(let command, let arguments, let openInTerminal):
            try await launchCLI(command: command, arguments: arguments, openInTerminal: openInTerminal)
        case .app(let bundleID):
            try await launchApp(bundleID: bundleID)
        case .url(let url):
            try await launchURL(url)
        case .project(let path):
            try await launchProject(path: path)
        }
    }

    private func launchCLI(command: String, arguments: [String], openInTerminal: Bool) async throws {
        guard let exe = ToolLaunchPlanner.locateExecutable(named: command) else {
            throw LaunchError.appNotFound(command)
        }
        if openInTerminal {
            let invocation = TerminalLaunchCommand.processInvocation(executable: exe, arguments: arguments)
            let process = Process()
            process.executableURL = invocation.executableURL
            process.arguments = invocation.arguments
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try process.run()
            return
        }
        let process = Process()
        process.executableURL = exe
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
    }

    private func launchApp(bundleID: String) async throws {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw LaunchError.appNotFound(bundleID)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func launchURL(_ url: URL) async throws {
        // 必须 https
        guard url.scheme == "https" else {
            throw LaunchError.unsafeScheme(url.scheme ?? "nil")
        }
        let success = await NSWorkspace.shared.open(url)
        if !success {
            throw LaunchError.urlOpenFailed(url)
        }
    }

    private func launchProject(path: URL) async throws {
        let success = await NSWorkspace.shared.open(path)
        if !success {
            throw LaunchError.pathNotFound(path)
        }
    }
}

public enum LaunchError: Error, Sendable, Equatable {
    case notImplemented
    case appNotFound(String)
    case urlOpenFailed(URL)
    case pathNotFound(URL)
    case unsafeScheme(String)
}
