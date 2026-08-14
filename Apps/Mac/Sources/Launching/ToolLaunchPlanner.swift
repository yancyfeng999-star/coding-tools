import Foundation
import AppKit
import Domain

public enum ToolLaunchFailure: Error, Equatable, Sendable {
    case noCapability
    case binaryNotFound(String)
    case appNotFound(String)
    case noURL
    case urlBlocked(String)
}

/// Resolves a catalog tool into the same launch plan used by the menu bar and detail Open.
public enum ToolLaunchPlanner {
    public static let trustedURLHosts: Set<String> = [
        "github.com", "docs.docker.com", "git-scm.com",
        "nodejs.org", "python.org", "go.dev", "rust-lang.org",
        "npmjs.com", "brew.sh", "mise.jdx.dev", "opencode.ai",
        "anthropic.com", "openai.com", "google.dev", "x.ai",
        "hermes-agent.nousresearch.com", "openclaw.ai", "developer.apple.com",
    ]

    public static func makeTarget(
        for tool: Tool,
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> Result<LaunchTarget, ToolLaunchFailure> {
        guard let capability = tool.launchCapability else {
            return .failure(.noCapability)
        }
        switch capability.type {
        case .cli:
            let command = capability.command ?? tool.slug
            guard locateExecutable(
                named: command,
                fileManager: fileManager,
                environment: environment,
                homeDirectory: homeDirectory
            ) != nil else {
                return .failure(.binaryNotFound(command))
            }
            return .success(.cli(
                command: command,
                arguments: capability.arguments,
                openInTerminal: capability.openInTerminal
            ))
        case .app:
            let bundleID = capability.bundleID ?? tool.id
            return .success(.app(bundleID: bundleID))
        case .url:
            return sanitizedURL(capability.url ?? tool.homepageURL)
        case .none:
            return sanitizedURL(tool.homepageURL)
        }
    }

    public static func locateExecutable(
        named command: String,
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL? {
        let candidates = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)",
            "\(homeDirectory)/.local/bin/\(command)",
            "\(homeDirectory)/.cargo/bin/\(command)",
        ]
        let pathEnv = environment["PATH"] ?? ""
        let pathCandidates = pathEnv.split(separator: ":").map { "\($0)/\(command)" }
        guard let path = (candidates + pathCandidates).first(where: {
            fileManager.isExecutableFile(atPath: $0)
        }) else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    public static func sanitizedURL(_ url: URL) -> Result<LaunchTarget, ToolLaunchFailure> {
        guard let host = url.host?.lowercased() else {
            return .failure(.noURL)
        }
        let allowed = trustedURLHosts.contains(host)
            || trustedURLHosts.contains(where: { host.hasSuffix(".\($0)") })
        guard allowed else {
            return .failure(.urlBlocked(host))
        }
        return .success(.url(url))
    }
}
