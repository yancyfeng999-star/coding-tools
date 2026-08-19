import Foundation

/// Settings status copy for Sparkle app updates.
/// Keys stay argument-free so a missing remote version cannot become a raw
/// `settings.update.status.readyToInstall —` lookup.
public struct UpdateStatusPresentation: Equatable, Sendable {
    public let key: String
    public let argument: String?

    public init(key: String, argument: String?) {
        self.key = key
        self.argument = argument
    }

    /// Resolve copy through an injected localizer so in-app language switches
    /// (LanguageManager) apply without relying on `NSLocalizedString` / `.current`.
    public func formattedText(localize: (String) -> String) -> String {
        Self.format(key: key, argument: argument, localize: localize)
    }

    public static func format(
        key: String,
        argument: String?,
        localize: (String) -> String
    ) -> String {
        if key.isEmpty {
            return argument ?? ""
        }
        let template = localize(key)
        guard let argument else { return template }
        return String(format: template, argument)
    }

    public static func settings(for state: UpdateState) -> UpdateStatusPresentation {
        switch state {
        case .idle:
            return UpdateStatusPresentation(key: "settings.update.status.idle", argument: nil)
        case .checking:
            return UpdateStatusPresentation(key: "settings.update.status.checking", argument: nil)
        case .upToDate(let remote):
            return UpdateStatusPresentation(key: "settings.update.status.upToDate", argument: displayVersion(remote))
        case .available(let remote, _, _):
            return UpdateStatusPresentation(key: "settings.update.status.available", argument: displayVersion(remote))
        case .downloading(let progress, _, _):
            return UpdateStatusPresentation(key: "settings.update.status.downloading", argument: "\(Int(progress * 100))")
        case .extracting(let progress):
            return UpdateStatusPresentation(key: "settings.update.status.extracting", argument: "\(Int(progress * 100))")
        case .readyToInstall(let remote):
            return UpdateStatusPresentation(key: "settings.update.status.readyToInstall", argument: displayVersion(remote))
        case .installing:
            return UpdateStatusPresentation(key: "settings.update.status.installing", argument: nil)
        case .installed:
            return UpdateStatusPresentation(key: "settings.update.status.installed", argument: nil)
        case .failed(let reason, _):
            return UpdateStatusPresentation(key: "", argument: reason)
        }
    }

    public static func displayVersion(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    public static func runningVersion(from bundle: Bundle = .main) -> (version: String, build: Int) {
        let version = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let build = Int((bundle.infoDictionary?["CFBundleVersion"] as? String) ?? "") ?? 0
        return (version.isEmpty ? "—" : version, build)
    }
}
