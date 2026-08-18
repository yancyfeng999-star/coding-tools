import Foundation

public struct CompatibilityReport: Equatable, Sendable {
    public let macOSSupported: Bool
    public let currentMacOS: String
    public let minimumMacOS: String
    public let architecture: String
    public let sparkleKeyPresent: Bool
    public let catalogReady: Bool

    public var isHealthy: Bool {
        macOSSupported && sparkleKeyPresent
    }

    public init(
        macOSSupported: Bool,
        currentMacOS: String,
        minimumMacOS: String,
        architecture: String,
        sparkleKeyPresent: Bool,
        catalogReady: Bool
    ) {
        self.macOSSupported = macOSSupported
        self.currentMacOS = currentMacOS
        self.minimumMacOS = minimumMacOS
        self.architecture = architecture
        self.sparkleKeyPresent = sparkleKeyPresent
        self.catalogReady = catalogReady
    }
}

public enum CompatibilityCheck {
    public static func evaluate(
        majorVersion: Int,
        minimumMajor: Int = 14,
        architecture: String,
        sparklePublicKey: String?,
        catalogReady: Bool
    ) -> CompatibilityReport {
        let key = sparklePublicKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return CompatibilityReport(
            macOSSupported: majorVersion >= minimumMajor,
            currentMacOS: "\(majorVersion)",
            minimumMacOS: "\(minimumMajor).0",
            architecture: architecture,
            sparkleKeyPresent: !key.isEmpty,
            catalogReady: catalogReady
        )
    }

    public static func evaluateCurrent(catalogReady: Bool) -> CompatibilityReport {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let key = Bundle.main.infoDictionary?["SUPublicEDKey"] as? String
        #if arch(arm64)
        let arch = "arm64"
        #elseif arch(x86_64)
        let arch = "x86_64"
        #else
        let arch = "unknown"
        #endif
        return evaluate(
            majorVersion: version.majorVersion,
            minimumMajor: 14,
            architecture: arch,
            sparklePublicKey: key,
            catalogReady: catalogReady
        )
    }
}
