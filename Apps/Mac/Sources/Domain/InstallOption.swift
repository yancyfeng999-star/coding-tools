import Foundation

// MARK: - InstallOption (Catalog JSON DTO)
//
// 与 Catalog/schemas/catalog.schema.json 严格对齐。
// 这是从签名目录解码出来的强类型模型；所有变体共享同一 struct，通过
// `type` 字段区分。Adapter 收到后映射到 `Installers.InstallAction`。
//
// **禁止**在 JSON schema 中新增 `command` / `script` / `sudo` /
// `postInstall` 等可执行字段；任何目录出现这些字段应被解码层直接拒绝。

public enum InstallOptionType: String, Hashable, Sendable, Codable, CaseIterable {
    case homebrewFormula = "homebrew-formula"
    case homebrewCask = "homebrew-cask"
    case miseTool = "mise-tool"
    case officialArtifact = "official-artifact"
    case npmGlobal = "npm-global"
}

public struct InstallOption: Hashable, Sendable, Codable {
    public let type: InstallOptionType
    public let packageName: String?
    public let versionRule: String?
    public let toolName: String?
    public let version: String?
    public let url: URL?
    public let sha256: String?
    public let bundleID: String?
    public let teamID: String?
    public let supportedArchitectures: [Architecture]
    public let minimumMacOS: String?
    public let requiresAuthorization: Bool
    public let riskLevel: RiskLevel

    public init(
        type: InstallOptionType,
        packageName: String? = nil,
        versionRule: String? = nil,
        toolName: String? = nil,
        version: String? = nil,
        url: URL? = nil,
        sha256: String? = nil,
        bundleID: String? = nil,
        teamID: String? = nil,
        supportedArchitectures: [Architecture] = [],
        minimumMacOS: String? = nil,
        requiresAuthorization: Bool = false,
        riskLevel: RiskLevel
    ) {
        self.type = type
        self.packageName = packageName
        self.versionRule = versionRule
        self.toolName = toolName
        self.version = version
        self.url = url
        self.sha256 = sha256
        self.bundleID = bundleID
        self.teamID = teamID
        self.supportedArchitectures = supportedArchitectures
        self.minimumMacOS = minimumMacOS
        self.requiresAuthorization = requiresAuthorization
        self.riskLevel = riskLevel
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decode(InstallOptionType.self, forKey: .type)
        self.packageName = try c.decodeIfPresent(String.self, forKey: .packageName)
        self.versionRule = try c.decodeIfPresent(String.self, forKey: .versionRule)
        self.toolName = try c.decodeIfPresent(String.self, forKey: .toolName)
        self.version = try c.decodeIfPresent(String.self, forKey: .version)
        self.url = try c.decodeIfPresent(URL.self, forKey: .url)
        self.sha256 = try c.decodeIfPresent(String.self, forKey: .sha256)
        self.bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID)
        self.teamID = try c.decodeIfPresent(String.self, forKey: .teamID)
        self.supportedArchitectures = try c.decodeIfPresent([Architecture].self, forKey: .supportedArchitectures) ?? []
        self.minimumMacOS = try c.decodeIfPresent(String.self, forKey: .minimumMacOS)
        self.requiresAuthorization = try c.decodeIfPresent(Bool.self, forKey: .requiresAuthorization) ?? false
        self.riskLevel = try c.decode(RiskLevel.self, forKey: .riskLevel)
    }

    /// 适配器层用：把 InstallOption 转成运行时可执行的 InstallAction。
    /// 任何字段缺失 → throw；不静默兜底。
    public func toInstallAction() throws -> InstallActionDescriptor {
        switch type {
        case .homebrewFormula:
            guard let name = packageName, !name.isEmpty else {
                throw DomainError.invalidInstallOption(reason: "homebrew-formula requires packageName")
            }
            return .formula(name: name)
        case .homebrewCask:
            guard let name = packageName, !name.isEmpty else {
                throw DomainError.invalidInstallOption(reason: "homebrew-cask requires packageName")
            }
            return .cask(name: name)
        case .miseTool:
            guard let name = toolName, !name.isEmpty else {
                throw DomainError.invalidInstallOption(reason: "mise-tool requires toolName")
            }
            return .mise(name: name, version: version)
        case .officialArtifact:
            guard let url else {
                throw DomainError.invalidInstallOption(reason: "official-artifact requires url")
            }
            guard let sha = sha256, sha.allSatisfy({ $0.isHexDigit }), sha.count == 64 else {
                throw DomainError.invalidInstallOption(reason: "official-artifact requires 64-char hex sha256")
            }
            return .artifact(url: url, sha256: sha, bundleID: bundleID, teamID: teamID)
        case .npmGlobal:
            // packageName 和 scriptURL 至少需要一个
            guard packageName != nil || url != nil else {
                throw DomainError.invalidInstallOption(reason: "npm-global requires packageName or url (script)")
            }
            if let u = url, u.scheme?.lowercased() != "https" {
                throw DomainError.invalidInstallOption(reason: "npm-global script url must be https://")
            }
            return .npm(packageName: packageName, scriptURL: url, versionRule: versionRule)
        }
    }
}

/// 适配器层使用的中间态枚举（与 Installers.InstallAction 形状一致，
/// 但保留在 Domain 内，避免 Installers 依赖反向循环）。
public enum InstallActionDescriptor: Hashable, Sendable {
    case formula(name: String)
    case cask(name: String)
    case mise(name: String, version: String?)
    case artifact(url: URL, sha256: String, bundleID: String?, teamID: String?)
    case npm(packageName: String?, scriptURL: URL?, versionRule: String?)
}

public enum DomainError: Error, Sendable, Equatable {
    case invalidInstallOption(reason: String)
    case unsupported(installType: InstallOptionType, reason: String)
}
