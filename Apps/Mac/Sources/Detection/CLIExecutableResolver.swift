import Foundation
import Domain

public struct ResolvedExecutable: Hashable, Sendable {
    public let path: URL
    public let canonicalPath: URL
    public let source: DetectedInstallSource
    public let isPreferred: Bool

    public init(path: URL, canonicalPath: URL, source: DetectedInstallSource, isPreferred: Bool) {
        self.path = path
        self.canonicalPath = canonicalPath
        self.source = source
        self.isPreferred = isPreferred
    }
}

public protocol CLIExecutableResolving: Sendable {
    func resolve(command: String, toolID: String) -> [ResolvedExecutable]
}

public struct CLIExecutableResolver: CLIExecutableResolving, @unchecked Sendable {
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let pathEntries: [String]
    private let appURLProvider: @Sendable (String) -> URL?

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        pathEntries: [String] = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init),
        appURLProvider: (@Sendable (String) -> URL?)? = nil
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory.standardizedFileURL
        self.pathEntries = pathEntries
        self.appURLProvider = appURLProvider ?? { bundleID in
            NSWorkspaceAppLookup.url(forBundleID: bundleID)
        }
    }

    public func resolve(command: String, toolID: String) -> [ResolvedExecutable] {
        let profile = AgentToolProfiles.profile(for: toolID)
        var seen: Set<String> = []
        var found: [ResolvedExecutable] = []

        func append(url: URL, source: DetectedInstallSource) {
            guard fileManager.isExecutableFile(atPath: url.path) else { return }
            let canonical = url.resolvingSymlinksInPath().standardizedFileURL
            let key = canonical.path
            guard !seen.contains(key) else { return }
            seen.insert(key)
            found.append(
                ResolvedExecutable(
                    path: url.standardizedFileURL,
                    canonicalPath: canonical,
                    source: source,
                    isPreferred: found.isEmpty
                )
            )
        }

        for entry in pathEntries {
            let trimmed = entry.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            append(
                url: URL(fileURLWithPath: trimmed, isDirectory: true).appendingPathComponent(command),
                source: .path
            )
        }

        for relative in profile?.relativeSearchDirectories ?? [] {
            append(
                url: homeDirectory.appendingPathComponent(relative).appendingPathComponent(command),
                source: Self.source(for: relative)
            )
        }

        for relative in Self.commonUserDirectories {
            append(
                url: homeDirectory.appendingPathComponent(relative).appendingPathComponent(command),
                source: Self.source(for: relative)
            )
        }

        for directory in Self.expandedWildcardDirectories(home: homeDirectory, fileManager: fileManager) {
            append(
                url: directory.appendingPathComponent(command),
                source: Self.source(for: directory.path)
            )
        }

        for systemDir in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"] {
            append(
                url: URL(fileURLWithPath: systemDir, isDirectory: true).appendingPathComponent(command),
                source: systemDir.contains("homebrew") || systemDir.contains("/usr/local") ? .homebrew : .path
            )
        }

        if let bundle = profile?.appBundle, let appURL = appURLProvider(bundle.bundleID) {
            let executable = appURL.appendingPathComponent(bundle.relativeExecutable)
            if fileManager.isExecutableFile(atPath: executable.path) {
                append(url: executable, source: .appBundle)
            }
        }

        return found
    }

    private static let commonUserDirectories = [
        ".local/bin",
        ".cargo/bin",
        ".local/share/mise/shims",
        ".mise/shims",
    ]

    private static func expandedWildcardDirectories(home: URL, fileManager: FileManager) -> [URL] {
        var directories: [URL] = []
        directories.append(contentsOf: globChildren(
            of: home.appendingPathComponent(".nvm/versions/node"),
            suffix: "bin",
            fileManager: fileManager
        ))
        directories.append(contentsOf: globChildren(
            of: home.appendingPathComponent("Library/Application Support/fnm/node-versions"),
            suffix: "installation/bin",
            fileManager: fileManager
        ))
        directories.append(contentsOf: globChildren(
            of: home.appendingPathComponent(".local/share/mise/installs/node"),
            suffix: "bin",
            fileManager: fileManager
        ))
        directories.append(contentsOf: globChildren(
            of: home.appendingPathComponent("Library/Python"),
            suffix: "bin",
            fileManager: fileManager
        ))
        return directories
    }

    private static func globChildren(of parent: URL, suffix: String, fileManager: FileManager) -> [URL] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: parent.path) else { return [] }
        return names.map { parent.appendingPathComponent($0).appendingPathComponent(suffix) }
    }

    public static func source(for path: String) -> DetectedInstallSource {
        let lowered = path.lowercased()
        if lowered.contains(".app/") || lowered.hasSuffix(".app") { return .appBundle }
        if lowered.contains("homebrew") || lowered.contains("/opt/homebrew") { return .homebrew }
        if lowered.contains(".npm-global") { return .npm }
        if lowered.contains(".volta") { return .volta }
        if lowered.contains(".nvm") { return .nvm }
        if lowered.contains("/fnm/") || lowered.contains(".fnm") { return .fnm }
        if lowered.contains("mise") { return .mise }
        if lowered.contains(".bun") { return .bun }
        if lowered.contains("library/python") { return .python }
        if lowered.contains(".grok") || lowered.contains(".opencode") { return .nativeInstaller }
        if lowered.contains(".local/bin") { return .nativeInstaller }
        return .unknown
    }
}

enum NSWorkspaceAppLookup {
    static func url(forBundleID bundleID: String) -> URL? {
        #if canImport(AppKit)
        return AppKitLookup.url(forBundleID: bundleID)
        #else
        return nil
        #endif
    }
}

#if canImport(AppKit)
import AppKit

private enum AppKitLookup {
    static func url(forBundleID bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }
}
#endif
