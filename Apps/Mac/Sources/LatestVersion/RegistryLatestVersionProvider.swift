import Foundation

public protocol VersionHTTPClient: Sendable {
    func data(from url: URL, timeout: TimeInterval, maximumBytes: Int) async throws -> Data
}

public enum VersionHTTPClientError: Error, Equatable, Sendable {
    case timedOut
    case responseTooLarge
    case httpStatus(Int)
    case networkUnavailable
    case hostNotAllowlisted
}

public final class AllowlistedURLSessionClient: NSObject, VersionHTTPClient, URLSessionTaskDelegate, @unchecked Sendable {
    public static let allowedHosts: Set<String> = [
        "registry.npmjs.org",
        "pypi.org",
        "api.github.com",
        "formulae.brew.sh",
    ]

    private var session: URLSession!

    public override init() {
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    public func data(from url: URL, timeout: TimeInterval, maximumBytes: Int) async throws -> Data {
        guard let host = url.host, Self.allowedHosts.contains(host) else {
            throw VersionHTTPClientError.hostNotAllowlisted
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("CodingTools/1.5", forHTTPHeaderField: "User-Agent")
        do {
            let (bytes, response) = try await session.bytes(for: request, delegate: self)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw VersionHTTPClientError.httpStatus(http.statusCode)
            }
            if let finalHost = response.url?.host, !Self.allowedHosts.contains(finalHost) {
                throw VersionHTTPClientError.hostNotAllowlisted
            }
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count > maximumBytes {
                    throw VersionHTTPClientError.responseTooLarge
                }
            }
            return data
        } catch let error as VersionHTTPClientError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw VersionHTTPClientError.timedOut
        } catch {
            throw VersionHTTPClientError.networkUnavailable
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        guard let host = request.url?.host, Self.allowedHosts.contains(host) else {
            return nil
        }
        return request
    }
}

public struct RegistryLatestVersionProvider: Sendable {
    public static let requestTimeout: TimeInterval = 5
    public static let maximumBytes = 1_048_576

    private let client: any VersionHTTPClient

    public init(client: any VersionHTTPClient) {
        self.client = client
    }

    public func fetch(source: VersionSource) async -> Result<LatestVersionRecord, LatestVersionFailure> {
        guard let url = Self.url(for: source) else {
            return .failure(.unsupportedSource)
        }
        do {
            let data = try await client.data(
                from: url,
                timeout: Self.requestTimeout,
                maximumBytes: Self.maximumBytes
            )
            guard let version = Self.parse(data: data, source: source) else {
                return .failure(.invalidResponse)
            }
            return .success(LatestVersionRecord(version: version, source: source, fetchedAt: Date()))
        } catch let error as VersionHTTPClientError {
            return .failure(Self.map(error))
        } catch {
            return .failure(.networkUnavailable)
        }
    }

    public static func url(for source: VersionSource) -> URL? {
        switch source {
        case .npm(let package):
            let encoded = package.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? package
            return URL(string: "https://registry.npmjs.org/\(encoded)/latest")
        case .pypi(let name):
            return URL(string: "https://pypi.org/pypi/\(name)/json")
        case .github(let owner, let repo):
            return URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")
        case .homebrewFormula(let name):
            return URL(string: "https://formulae.brew.sh/api/formula/\(name).json")
        case .homebrewCask(let name):
            return URL(string: "https://formulae.brew.sh/api/cask/\(name).json")
        }
    }

    public static func parse(data: Data, source: VersionSource) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        switch source {
        case .npm:
            return (object as? [String: Any])?["version"] as? String
        case .pypi:
            let info = (object as? [String: Any])?["info"] as? [String: Any]
            return info?["version"] as? String
        case .github:
            guard let tag = (object as? [String: Any])?["tag_name"] as? String else { return nil }
            return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        case .homebrewFormula:
            let versions = (object as? [String: Any])?["versions"] as? [String: Any]
            return versions?["stable"] as? String
        case .homebrewCask:
            return (object as? [String: Any])?["version"] as? String
        }
    }

    private static func map(_ error: VersionHTTPClientError) -> LatestVersionFailure {
        switch error {
        case .timedOut: return .timedOut
        case .responseTooLarge: return .responseTooLarge
        case .httpStatus(let code): return .httpStatus(code)
        case .networkUnavailable: return .networkUnavailable
        case .hostNotAllowlisted: return .unsupportedSource
        }
    }
}
