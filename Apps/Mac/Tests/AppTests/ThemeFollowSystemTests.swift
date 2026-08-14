import XCTest
import AppKit
@testable import Theme

@MainActor
final class ThemeFollowSystemTests: XCTestCase {
    private var previousAppearance: NSAppearance?
    private var window: NSWindow!

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        previousAppearance = NSApplication.shared.appearance
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
    }

    override func tearDown() {
        NSApplication.shared.appearance = previousAppearance
        window.appearance = nil
        window = nil
        super.tearDown()
    }

    func testApplySystemAfterDarkClearsAppAndWindowAppearance() {
        let app = NSApplication.shared
        AppearancePreference.apply(.dark, application: app, windows: [window])
        XCTAssertNotNil(app.appearance)
        XCTAssertNotNil(window.appearance)

        AppearancePreference.apply(.system, application: app, windows: [window])
        XCTAssertNil(app.appearance)
        XCTAssertNil(window.appearance)
    }

    func testApplySystemAfterLightClearsAppAndWindowAppearance() {
        let app = NSApplication.shared
        AppearancePreference.apply(.light, application: app, windows: [window])
        XCTAssertNotNil(app.appearance)
        XCTAssertNotNil(window.appearance)

        AppearancePreference.apply(.system, application: app, windows: [window])
        XCTAssertNil(app.appearance)
        XCTAssertNil(window.appearance)
    }

    func testSystemModeReappliedAfterEffectiveAppearanceChangeStaysInherited() {
        let app = NSApplication.shared
        AppearancePreference.apply(.dark, application: app, windows: [window])
        AppearancePreference.apply(.system, application: app, windows: [window])
        XCTAssertNil(app.appearance)

        // Subsequent system-appearance change while still in 跟随系统.
        AppearancePreference.apply(.system, application: app, windows: [window])
        XCTAssertNil(app.appearance)
        XCTAssertNil(window.appearance)
    }

    func testThemeManagerApplySystemClearsPreviousFixedMode() {
        let suite = "ThemeFollowSystemTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let manager = ThemeManager(defaults: defaults)
        let app = NSApplication.shared

        manager.apply(.dark)
        XCTAssertNotNil(app.appearance)

        manager.apply(.system)
        XCTAssertEqual(manager.mode, .system)
        XCTAssertNil(app.appearance)
        defaults.removePersistentDomain(forName: suite)
    }

    func testThemeManagerInitAppliesStoredDarkMode() {
        let suite = "ThemeFollowSystemTests.init.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("dark", forKey: "AppTheme.mode")
        let app = NSApplication.shared
        app.appearance = nil
        let manager = ThemeManager(defaults: defaults)
        XCTAssertEqual(manager.mode, .dark)
        XCTAssertNotNil(app.appearance)
        defaults.removePersistentDomain(forName: suite)
    }
}
