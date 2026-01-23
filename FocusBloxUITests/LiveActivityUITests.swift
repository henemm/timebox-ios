import XCTest

/// UI Tests for Live Activity Feature (Sprint 4)
///
/// Note: Live Activity itself runs outside the app (Lock Screen/Dynamic Island)
/// and cannot be directly tested via XCUITest. The FocusLiveView uses its own
/// EventKitRepository instance, so mock data from app launch doesn't work.
///
/// These tests verify basic FocusLiveView behavior which is prerequisite for Live Activity.
final class LiveActivityUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    private func navigateToFokus() {
        let fokusTab = app.tabBars.buttons["Fokus"]
        if fokusTab.waitForExistence(timeout: 5) {
            fokusTab.tap()
        }
    }

    // MARK: - FocusLiveView Basic Tests

    /// GIVEN: App is launched
    /// WHEN: User navigates to Fokus tab
    /// THEN: FocusLiveView should be displayed
    func testFokusViewOpens() throws {
        navigateToFokus()

        // Wait for FocusLiveView to load
        let fokusNav = app.navigationBars["Fokus"]
        XCTAssertTrue(fokusNav.waitForExistence(timeout: 5), "Fokus view should open")
    }

    /// GIVEN: App is launched with no active blocks (default state)
    /// WHEN: FocusLiveView loads
    /// THEN: Should show "Kein aktiver Focus Block" message
    func testNoActiveBlockMessageShown() throws {
        navigateToFokus()

        // Wait for FocusLiveView to load
        let fokusNav = app.navigationBars["Fokus"]
        XCTAssertTrue(fokusNav.waitForExistence(timeout: 5), "Fokus view should open")

        // Since there's no real calendar access in tests, we expect the "no block" state
        // OR an active block if mock data works
        let noBlockText = app.staticTexts["Kein aktiver Focus Block"]
        let blockTitle = app.staticTexts["🎯 Focus Block Test"]

        // One of these should exist
        let hasNoBlock = noBlockText.waitForExistence(timeout: 5)
        let hasActiveBlock = blockTitle.exists

        XCTAssertTrue(
            hasNoBlock || hasActiveBlock,
            "Should show either 'Kein aktiver Focus Block' or an active block title"
        )
    }

    /// GIVEN: FocusLiveView is displayed
    /// WHEN: View shows no active block
    /// THEN: Aktualisieren button should be available
    func testRefreshButtonExistsWhenNoBlock() throws {
        navigateToFokus()

        // Wait for FocusLiveView to load
        let fokusNav = app.navigationBars["Fokus"]
        XCTAssertTrue(fokusNav.waitForExistence(timeout: 5), "Fokus view should open")

        // Check for refresh button (only shown when no block)
        let noBlockText = app.staticTexts["Kein aktiver Focus Block"]
        if noBlockText.waitForExistence(timeout: 3) {
            let refreshButton = app.buttons["Aktualisieren"]
            XCTAssertTrue(
                refreshButton.waitForExistence(timeout: 2),
                "Aktualisieren button should exist when no active block"
            )
        }
    }

    /// GIVEN: FocusLiveView is displayed
    /// WHEN: Settings button is tapped
    /// THEN: Settings should open
    func testSettingsButtonWorks() throws {
        navigateToFokus()

        // Wait for FocusLiveView to load
        let fokusNav = app.navigationBars["Fokus"]
        XCTAssertTrue(fokusNav.waitForExistence(timeout: 5), "Fokus view should open")

        // Tap settings button
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "Settings button should exist")
        settingsButton.tap()

        // Settings should open
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 3),
            "Settings view should open"
        )
    }
}
