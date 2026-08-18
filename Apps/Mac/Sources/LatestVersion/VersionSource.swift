import Foundation
import Domain

public enum VersionSource: Hashable, Sendable {
    case npm(String)
    case pypi(String)
    case github(owner: String, repo: String)
    case homebrewFormula(String)
    case homebrewCask(String)
}

public enum VersionSourceResolver {
    public static func sources(for tool: Tool) -> [VersionSource] {
        switch tool.id {
        case "claude-code":
            return [.npm("@anthropic-ai/claude-code")]
        case "codex":
            return [.npm("@openai/codex")]
        case "gemini-cli":
            return [.npm("@google/gemini-cli")]
        case "grok-build":
            return [.npm("@xai-official/grok")]
        case "opencode":
            return [.npm("opencode-ai"), .github(owner: "anomalyco", repo: "opencode")]
        case "openclaw":
            return [.npm("openclaw")]
        case "hermes":
            return [.pypi("hermes-agent")]
        default:
            return sourcesFromInstallOptions(tool.installOptions)
        }
    }

    public static func normalizeNpmPackage(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            let parts = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return trimmed }
            let name = parts[1].split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? String(parts[1])
            return "@\(parts[0].dropFirst())/\(name)"
        }
        return trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? trimmed
    }

    private static func sourcesFromInstallOptions(_ options: [InstallOption]) -> [VersionSource] {
        var sources: [VersionSource] = []
        for option in options {
            switch option.type {
            case .npmGlobal:
                if let name = option.packageName, !name.isEmpty {
                    sources.append(.npm(normalizeNpmPackage(name)))
                }
            case .homebrewFormula:
                if let name = option.packageName, !name.isEmpty {
                    sources.append(.homebrewFormula(name))
                }
            case .homebrewCask:
                if let name = option.packageName, !name.isEmpty {
                    sources.append(.homebrewCask(name))
                }
            default:
                continue
            }
        }
        return sources
    }
}
