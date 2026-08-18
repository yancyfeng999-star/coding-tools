import Foundation

public struct AgentToolProfile: Hashable, Sendable {
    public let toolID: String
    public let command: String
    public let versionArguments: [String]
    public let relativeSearchDirectories: [String]
    public let appBundle: (bundleID: String, relativeExecutable: String)?

    public init(
        toolID: String,
        command: String,
        versionArguments: [String],
        relativeSearchDirectories: [String],
        appBundle: (bundleID: String, relativeExecutable: String)?
    ) {
        self.toolID = toolID
        self.command = command
        self.versionArguments = versionArguments
        self.relativeSearchDirectories = relativeSearchDirectories
        self.appBundle = appBundle
    }

    public static func == (lhs: AgentToolProfile, rhs: AgentToolProfile) -> Bool {
        lhs.toolID == rhs.toolID
            && lhs.command == rhs.command
            && lhs.versionArguments == rhs.versionArguments
            && lhs.relativeSearchDirectories == rhs.relativeSearchDirectories
            && lhs.appBundle?.bundleID == rhs.appBundle?.bundleID
            && lhs.appBundle?.relativeExecutable == rhs.appBundle?.relativeExecutable
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(toolID)
        hasher.combine(command)
        hasher.combine(versionArguments)
        hasher.combine(relativeSearchDirectories)
        hasher.combine(appBundle?.bundleID)
        hasher.combine(appBundle?.relativeExecutable)
    }
}

public enum AgentToolProfiles {
    public static let all: [String: AgentToolProfile] = [
        "claude-code": .init(
            toolID: "claude-code",
            command: "claude",
            versionArguments: ["--version"],
            relativeSearchDirectories: [".local/bin", ".npm-global/bin", ".volta/bin"],
            appBundle: nil
        ),
        "codex": .init(
            toolID: "codex",
            command: "codex",
            versionArguments: ["--version"],
            relativeSearchDirectories: [".local/bin", ".npm-global/bin", ".volta/bin"],
            appBundle: ("com.openai.chat", "Contents/Resources/codex")
        ),
        "gemini-cli": .init(
            toolID: "gemini-cli",
            command: "gemini",
            versionArguments: ["--version"],
            relativeSearchDirectories: [".local/bin", ".npm-global/bin", ".volta/bin"],
            appBundle: nil
        ),
        "grok-build": .init(
            toolID: "grok-build",
            command: "grok",
            versionArguments: ["--version"],
            relativeSearchDirectories: [".grok/bin", ".local/bin"],
            appBundle: nil
        ),
        "opencode": .init(
            toolID: "opencode",
            command: "opencode",
            versionArguments: ["--version"],
            relativeSearchDirectories: [".opencode/bin", ".bun/bin", ".local/bin", "go/bin"],
            appBundle: nil
        ),
        "openclaw": .init(
            toolID: "openclaw",
            command: "openclaw",
            versionArguments: ["--version"],
            relativeSearchDirectories: [".local/bin", ".npm-global/bin", ".volta/bin", ".bun/bin"],
            appBundle: nil
        ),
        "hermes": .init(
            toolID: "hermes",
            command: "hermes",
            versionArguments: ["--version"],
            relativeSearchDirectories: [".local/bin"],
            appBundle: nil
        ),
    ]

    public static func profile(for toolID: String) -> AgentToolProfile? {
        all[toolID]
    }
}
