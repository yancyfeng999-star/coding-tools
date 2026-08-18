import Foundation

public struct LoadFailure: Equatable, Sendable {
    public let localizationKey: String
    public let redactedMessage: String

    public init(localizationKey: String, redactedMessage: String) {
        self.localizationKey = localizationKey
        self.redactedMessage = redactedMessage
    }
}

public enum Loadable<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading(previous: Value?)
    case loaded(Value)
    case failed(LoadFailure, previous: Value?)
}

public enum VersionRelationship: Equatable, Sendable {
    case unknown
    case current
    case updateAvailable
    case localAhead
}
