import XCTest
@testable import Domain

final class ToolTests: XCTestCase {
    func testToolIdentity() {
        let tool = Tool(id: "git", slug: "git", name: "Git", category: .gitCollaboration)
        XCTAssertEqual(tool.id, "git")
        XCTAssertEqual(tool.category, .gitCollaboration)
    }

    func testToolCategoryAllCases() {
        XCTAssertGreaterThan(ToolCategory.allCases.count, 5)
    }
}

final class OperationLogTests: XCTestCase {
    func testOperationLogSuccess() {
        let log = OperationLog(
            id: "log-1",
            operationType: "install",
            toolID: "git",
            startedAt: Date(),
            result: .success,
            exitCode: 0
        )
        XCTAssertEqual(log.result, .success)
        XCTAssertEqual(log.exitCode, 0)
    }
}
