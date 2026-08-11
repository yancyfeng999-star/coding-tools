import XCTest
import SwiftUI
@testable import UI

@MainActor
final class ToastCenterTests: XCTestCase {
    private var center: ToastCenter!

    override func setUp() {
        super.setUp()
        center = ToastCenter()
    }

    override func tearDown() {
        center.dismiss()
        center = nil
        super.tearDown()
    }

    func testShowSetsCurrentToast() {
        XCTAssertNil(center.current)
        let toast = Toast(kind: .info, messageKey: "test.info")
        center.show(toast, autoDismissAfter: 60)
        XCTAssertNotNil(center.current)
        XCTAssertEqual(center.current?.id, toast.id)
    }

    func testShowOverwritesPreviousToast() {
        let first = Toast(kind: .info, messageKey: "first")
        let second = Toast(kind: .error, messageKey: "second")
        center.show(first, autoDismissAfter: 60)
        center.show(second, autoDismissAfter: 60)
        XCTAssertEqual(center.current?.id, second.id)
    }

    func testDismissClearsCurrent() {
        center.show(Toast(kind: .warning, messageKey: "warn"), autoDismissAfter: 60)
        XCTAssertNotNil(center.current)
        center.dismiss()
        XCTAssertNil(center.current)
    }

    func testToastEqualityByID() {
        let t1 = Toast(kind: .info, messageKey: "x")
        let t2 = Toast(kind: .error, messageKey: "x")
        XCTAssertNotEqual(t1, t2, "Different IDs → not equal")
        // 同实例的 id 在 Toast 创建后稳定
        XCTAssertEqual(t1.id, t1.id)
    }

    func testAutoDismissClearsAfterDelay() async throws {
        center.show(Toast(kind: .success, messageKey: "ok"), autoDismissAfter: 0.1)
        XCTAssertNotNil(center.current)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNil(center.current)
    }

    func testNewerToastNotDismissedByOldAutoTask() async throws {
        let first = Toast(kind: .info, messageKey: "first")
        let second = Toast(kind: .info, messageKey: "second")
        center.show(first, autoDismissAfter: 0.1)
        center.show(second, autoDismissAfter: 60)
        try await Task.sleep(nanoseconds: 250_000_000)
        // first 的 auto-dismiss task 不应清掉 second
        XCTAssertEqual(center.current?.id, second.id)
    }

    func testKindRawValues() {
        XCTAssertEqual(Toast.Kind.info.rawValue, "info")
        XCTAssertEqual(Toast.Kind.success.rawValue, "success")
        XCTAssertEqual(Toast.Kind.warning.rawValue, "warning")
        XCTAssertEqual(Toast.Kind.error.rawValue, "error")
    }

    func testRetryClosureStored() {
        var retryCount = 0
        let toast = Toast(kind: .error, messageKey: "x", retry: { retryCount += 1 })
        center.show(toast, autoDismissAfter: 60)
        XCTAssertNotNil(center.current?.retry)
        center.current?.retry?()
        XCTAssertEqual(retryCount, 1)
    }
}
