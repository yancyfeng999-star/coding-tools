import XCTest
@testable import Detection
import Domain

final class CLIExecutableResolverTests: XCTestCase {
    func testFindsAgentSpecificDirectoriesWithoutShell() throws {
        let fixture = try ResolverFixture()
        defer { fixture.tearDown() }
        try fixture.makeExecutable(".local/bin/claude")
        try fixture.makeExecutable(".grok/bin/grok")
        try fixture.makeExecutable(".opencode/bin/opencode")

        XCTAssertEqual(fixture.resolve("claude", toolID: "claude-code").first?.relativePath, ".local/bin/claude")
        XCTAssertEqual(fixture.resolve("grok", toolID: "grok-build").first?.relativePath, ".grok/bin/grok")
        XCTAssertEqual(fixture.resolve("opencode", toolID: "opencode").first?.relativePath, ".opencode/bin/opencode")
    }

    func testDeduplicatesTwoSymlinksToSameBinary() throws {
        let fixture = try ResolverFixture()
        defer { fixture.tearDown() }
        let real = try fixture.makeExecutable(".grok/downloads/grok-1.0.5")
        try fixture.makeSymlink(".grok/bin/grok", destination: real)
        try fixture.makeSymlink(".local/bin/grok", destination: real)
        XCTAssertEqual(fixture.resolve("grok", toolID: "grok-build").count, 1)
    }

    func testPrefersPATHOverAppBundle() throws {
        let fixture = try ResolverFixture()
        defer { fixture.tearDown() }
        try fixture.makeExecutable("bin/codex")
        let app = try fixture.makeExecutable("ChatGPT.app/Contents/Resources/codex")
        let home = fixture.home
        let resolver = CLIExecutableResolver(
            fileManager: .default,
            homeDirectory: home,
            pathEntries: [home.appendingPathComponent("bin").path],
            appURLProvider: { _ in home.appendingPathComponent("ChatGPT.app") }
        )
        let resolved = resolver.resolve(command: "codex", toolID: "codex")
        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved.first?.source, .path)
        XCTAssertTrue(resolved.first?.isPreferred == true)
        XCTAssertEqual(resolved.last?.canonicalPath, app.resolvingSymlinksInPath())
        XCTAssertEqual(resolved.last?.source, .appBundle)
        _ = app
    }
}

private final class ResolverFixture {
    let home: URL
    let fileManager = FileManager.default

    init() throws {
        home = fileManager.temporaryDirectory.appendingPathComponent("ct-resolver-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: home, withIntermediateDirectories: true)
    }

    func makeExecutable(_ relative: String) throws -> URL {
        let url = home.appendingPathComponent(relative)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#".utf8).write(to: url)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    func makeSymlink(_ relative: String, destination: URL) throws {
        let url = home.appendingPathComponent(relative)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: url, withDestinationURL: destination)
    }

    func resolve(_ command: String, toolID: String) -> [ResolvedPath] {
        let resolver = CLIExecutableResolver(
            fileManager: fileManager,
            homeDirectory: home,
            pathEntries: [],
            appURLProvider: { _ in nil }
        )
        return resolver.resolve(command: command, toolID: toolID).map { item in
            let path = item.path.path
            let prefix = home.path.hasSuffix("/") ? home.path : home.path + "/"
            let relative = path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
            return ResolvedPath(relativePath: relative, canonicalPath: item.canonicalPath.path)
        }
    }

    func tearDown() {
        try? fileManager.removeItem(at: home)
    }
}

private struct ResolvedPath {
    let relativePath: String
    let canonicalPath: String
}
