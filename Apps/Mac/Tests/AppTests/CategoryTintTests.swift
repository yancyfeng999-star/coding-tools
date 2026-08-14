import XCTest
import Domain
import Theme
@testable import UI

final class CategoryTintTests: XCTestCase {
    func testGitUsesWarningTokenNotRawOrange() {
        XCTAssertEqual(
            CategoryTint.color(for: .gitCollaboration),
            DesignTokens.Palette.warning
        )
        XCTAssertEqual(
            CategoryTint.color(toolID: "git", category: .gitCollaboration),
            DesignTokens.Palette.warning
        )
    }

    func testPythonUsesAccentTokenNotRawBlue() {
        XCTAssertEqual(
            CategoryTint.color(for: .python),
            DesignTokens.Palette.accent
        )
    }
}
