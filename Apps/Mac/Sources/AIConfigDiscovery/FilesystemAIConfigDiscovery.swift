import Foundation

// MARK: - FilesystemAIConfigDiscovery
//
// 扫这些 AI CLI 的配置文件：
//   Claude Code    : ~/.claude/settings.json       (JSON)
//   Codex CLI       : ~/.codex/config.toml         (TOML — 简单 k=v)
//   Gemini CLI      : ~/.gemini/settings.json       (JSON)
//   OpenCode        : ~/.config/opencode/config.json (JSON)
//   Grok Build      : ~/.grok-build/config.json     (JSON)
//   Hermes          : ~/.hermes/config.json         (JSON)
//   OpenClaw        : ~/.openclaw/agent.json        (JSON)
//
// 安全：只读顶层字段，不读任何 *_key / *_token / *_secret 字段。
// 损坏 JSON / 文件不存在 → 静默跳过。

public final class FilesystemAIConfigDiscovery: AIConfigDiscovering, @unchecked Sendable {

    public struct ProbeTarget: Sendable {
        public let toolID: String
        public let path: String  // 用 String 而非 URL：`URL(fileURLWithPath: "~/...")` 会直接展开为绝对路径
        public let format: ConfigFormat
        public let apiKeyFieldNames: [String]  // 用于判定 hasAPIKey（仅检测存在性，不读值）
    }

    /// 调试 / 测试 override（默认用 `~/.xxx`）
    public let homeDirectory: URL

    public init(homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.homeDirectory = homeDirectory
    }

    public static let defaultTargets: [ProbeTarget] = [
        ProbeTarget(
            toolID: "claude-code",
            path: "~/.claude/settings.json",
            format: .json,
            apiKeyFieldNames: ["apikey", "anthropicapikey", "api_key"]
        ),
        ProbeTarget(
            toolID: "codex",
            path: "~/.codex/config.toml",
            format: .toml,
            apiKeyFieldNames: ["api_key", "openai_api_key"]
        ),
        ProbeTarget(
            toolID: "gemini-cli",
            path: "~/.gemini/settings.json",
            format: .json,
            apiKeyFieldNames: ["apikey", "googleapikey", "api_key"]
        ),
        ProbeTarget(
            toolID: "opencode",
            path: "~/.config/opencode/config.json",
            format: .json,
            apiKeyFieldNames: ["apikey", "api_key"]
        ),
        ProbeTarget(
            toolID: "grok-build",
            path: "~/.grok-build/config.json",
            format: .json,
            apiKeyFieldNames: ["apikey", "xaiapikey", "api_key"]
        ),
        ProbeTarget(
            toolID: "hermes",
            path: "~/.hermes/config.json",
            format: .json,
            apiKeyFieldNames: ["apikey", "api_key"]
        ),
        ProbeTarget(
            toolID: "openclaw",
            path: "~/.openclaw/agent.json",
            format: .json,
            apiKeyFieldNames: ["apikey", "agentkey", "api_key"]
        ),
    ]

    public func discover() async -> [AIConfig] {
        await Task.detached { [self] in
            await self.scanAll()
        }.value
    }

    private func scanAll() async -> [AIConfig] {
        var results: [AIConfig] = []
        for target in Self.defaultTargets {
            if let cfg = await scanOne(target: target) {
                results.append(cfg)
            }
        }
        return results
    }

    private func scanOne(target: ProbeTarget) async -> AIConfig? {
        let url = expandTilde(target.path, base: homeDirectory)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date,
              let size = attrs[.size] as? Int else {
            return nil
        }
        // 读顶层（不读 secret）
        let parsed = readTopLevel(path: url, format: target.format)
        // hasAPIKey：仅判断 key 字段是否存在，不读值
        let hasKey = parsed.fields.contains(where: { target.apiKeyFieldNames.contains($0.key.lowercased()) })
        return AIConfig(
            toolID: target.toolID,
            configPath: url,
            mtime: mtime,
            sizeBytes: size,
            hasAPIKey: hasKey,
            model: parsed.model,
            detectedFormat: target.format
        )
    }

    // MARK: - Parsers

    private struct ParsedTop {
        let fields: [String: String]
        let model: String?
    }

    private func readTopLevel(path: URL, format: ConfigFormat) -> ParsedTop {
        guard let data = try? Data(contentsOf: path) else { return ParsedTop(fields: [:], model: nil) }
        switch format {
        case .json:
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ParsedTop(fields: [:], model: nil)
            }
            var fields: [String: String] = [:]
            for (k, v) in obj {
                if v is String { fields[k.lowercased()] = v as? String ?? "" }
            }
            let model = (obj["model"] as? String) ?? extractModelDeep(obj)
            return ParsedTop(fields: fields, model: model)
        case .toml:
            // 极简 k=v / [section] 解析（不引第三方）
            guard let text = String(data: data, encoding: .utf8) else {
                return ParsedTop(fields: [:], model: nil)
            }
            var fields: [String: String] = [:]
            var inSection = ""
            var model: String?
            for line in text.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    inSection = String(trimmed.dropFirst().dropLast()).lowercased()
                    continue
                }
                let parts = trimmed.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    let key = (inSection.isEmpty ? parts[0] : "\(inSection).\(parts[0])").lowercased()
                    let val = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
                    fields[key] = val
                    if inSection.isEmpty && parts[0].lowercased() == "model" { model = val }
                }
            }
            return ParsedTop(fields: fields, model: model)
        case .unknown:
            return ParsedTop(fields: [:], model: nil)
        }
    }

    private func extractModelDeep(_ obj: [String: Any]) -> String? {
        if let m = obj["model"] as? String { return m }
        // Claude / Codex 等的嵌套结构
        for (_, v) in obj {
            if let dict = v as? [String: Any] {
                if let m = extractModelDeep(dict) { return m }
            }
        }
        return nil
    }

    // MARK: - Path

    /// `~/foo` → `base/foo`；绝对路径直接返回。
    /// 用 String 入参避免 `URL(fileURLWithPath:)` 误把 `~/` 当成绝对路径前缀。
    private func expandTilde(_ path: String, base: URL) -> URL {
        if path.hasPrefix("~/") {
            return base.appendingPathComponent(String(path.dropFirst(2)))
        }
        return URL(fileURLWithPath: path)
    }
}
