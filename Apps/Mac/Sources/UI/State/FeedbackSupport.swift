import Foundation

/// Safe metadata allowed in a GitHub issue URL. Nothing else is accepted.
public struct IssueReportMetadata: Equatable, Sendable {
    public let version: String
    public let build: String
    public let macOSVersion: String
    public let architecture: String

    public init(version: String, build: String, macOSVersion: String, architecture: String) {
        self.version = IssueURLBuilder.sanitize(version)
        self.build = IssueURLBuilder.sanitize(build)
        self.macOSVersion = IssueURLBuilder.sanitize(macOSVersion)
        self.architecture = IssueURLBuilder.sanitize(architecture)
    }
}

public enum IssueURLBuilder {
    public static let issuesNewURL = "https://github.com/yancyfeng999-star/coding-tools/issues/new"
    public static let discussionsIdeasURL = "https://github.com/yancyfeng999-star/coding-tools/discussions/new?category=ideas"
    public static let homepageURL = "https://github.com/yancyfeng999-star/coding-tools"
    public static let latestReleaseURL = "https://github.com/yancyfeng999-star/coding-tools/releases/latest"
    public static let helpURL = "https://github.com/yancyfeng999-star/coding-tools#readme"
    public static let securityURL = "https://github.com/yancyfeng999-star/coding-tools/security/advisories/new"

    public static func bugReportURL(metadata: IssueReportMetadata) -> URL {
        var components = URLComponents(string: issuesNewURL)!
        components.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "title", value: "[Bug] v\(metadata.version) (\(metadata.build)) · \(metadata.macOSVersion) · \(metadata.architecture)"),
            URLQueryItem(name: "version", value: metadata.version),
            URLQueryItem(name: "build", value: metadata.build),
            URLQueryItem(name: "macos_version", value: metadata.macOSVersion),
            URLQueryItem(name: "architecture", value: issueFormArchitecture(metadata.architecture)),
        ]
        return components.url!
    }

    /// GitHub `bug_report.yml` dropdown only accepts these labels.
    public static func issueFormArchitecture(_ raw: String) -> String {
        switch raw.lowercased() {
        case "arm64", "aarch64", "apple silicon":
            return "Apple Silicon"
        case "x86_64", "x86-64", "amd64", "intel":
            return "Intel"
        default:
            return "Universal / unknown"
        }
    }

    public static func featureIdeaURL() -> URL {
        URL(string: discussionsIdeasURL)!
    }

    public static func currentMetadata(
        version: String,
        build: String,
        processInfo: ProcessInfo = .processInfo
    ) -> IssueReportMetadata {
        let os = processInfo.operatingSystemVersion
        let macOS = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        #if arch(arm64)
        let arch = "arm64"
        #elseif arch(x86_64)
        let arch = "x86_64"
        #else
        let arch = "unknown"
        #endif
        return IssueReportMetadata(
            version: version,
            build: build,
            macOSVersion: macOS,
            architecture: arch
        )
    }

    public static func sanitize(_ raw: String) -> String {
        var value = raw
        value = value.replacingOccurrences(
            of: #"(/Users|/home)/[^/\s]+"#,
            with: "$1/***",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?i)(bearer|token|api[_-]?key|authorization)[=:\s]+[^\s&]+"#,
            with: "$1=***",
            options: .regularExpression
        )
        return String(value.prefix(80))
    }

    public static func containsForbiddenPayload(_ url: URL) -> Bool {
        let text = url.absoluteString
        if text.contains("/Users/") && text.contains("/Users/***") == false { return true }
        if text.range(of: #"(?i)(sk-|ghp_|github_pat_|Bearer )"#, options: .regularExpression) != nil {
            return true
        }
        if text.contains("PATH=") || text.contains("signed-download") { return true }
        return false
    }
}

public struct DiagnosticField: Equatable, Sendable {
    public let key: String
    public let value: String
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public struct DiagnosticSummary: Equatable, Sendable {
    public let fields: [DiagnosticField]

    public var previewText: String {
        fields.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }

    public var includedKeys: [String] { fields.map(\.key) }
}

public enum DiagnosticSummaryBuilder {
    public static func make(
        version: String,
        build: String,
        macOSVersion: String,
        architecture: String,
        theme: String,
        language: String,
        catalogStatus: String,
        appUpdateState: String,
        selectedToolStatus: String?
    ) -> DiagnosticSummary {
        var fields = [
            DiagnosticField(key: "app.version", value: version),
            DiagnosticField(key: "app.build", value: build),
            DiagnosticField(key: "macos.version", value: macOSVersion),
            DiagnosticField(key: "cpu.architecture", value: architecture),
            DiagnosticField(key: "theme", value: theme),
            DiagnosticField(key: "language", value: language),
            DiagnosticField(key: "catalog.status", value: catalogStatus),
            DiagnosticField(key: "app.update.state", value: appUpdateState),
        ]
        if let selectedToolStatus {
            fields.append(DiagnosticField(key: "tool.status", value: selectedToolStatus))
        }
        return DiagnosticSummary(fields: fields)
    }
}
