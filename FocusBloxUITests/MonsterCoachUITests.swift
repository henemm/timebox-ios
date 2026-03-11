import XCTest

final class MonsterCoachUITests: XCTestCase {

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

    // MARK: - Helpers

    /// Navigate to Settings and scroll to find coachModeToggle
    private func navigateToCoachToggle() -> XCUIElement? {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button should exist")
            return nil
        }
        settingsButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        guard settingsNav.waitForExistence(timeout: 5) else {
            XCTFail("Settings should be visible")
            return nil
        }

        let coachToggle = app.switches["coachModeToggle"]
        if coachToggle.waitForExistence(timeout: 2) {
            return coachToggle
        }

        // Scroll down to find the toggle
        for _ in 0..<3 {
            app.swipeUp()
            if coachToggle.waitForExistence(timeout: 1) {
                return coachToggle
            }
        }

        return coachToggle.exists ? coachToggle : nil
    }

    // MARK: - Settings Toggle

    /// GIVEN: App is running
    /// WHEN: Opening Settings
    /// THEN: Coach mode toggle should be visible
    func test_settings_showsCoachModeToggle() throws {
        let toggle = navigateToCoachToggle()
        XCTAssertNotNil(toggle, "Coach mode toggle should exist in Settings")
    }

    // MARK: - Review Tab Integration

    /// GIVEN: Coach mode is enabled via launch argument
    /// WHEN: Navigating to Review tab
    /// THEN: MonsterStatusView should be visible
    func test_review_showsMonsterStatus_whenCoachEnabled() throws {
        // Relaunch with coachModeEnabled = true
        app.terminate()
        app.launchArguments = ["-UITesting", "-coachModeEnabled", "YES"]
        app.launch()

        // Navigate to Review tab
        let reviewTab = app.tabBars.buttons["Review"]
        guard reviewTab.waitForExistence(timeout: 5) else {
            XCTFail("Review tab should exist")
            return
        }
        reviewTab.tap()

        // Wait for review content to load
        sleep(2)

        // Monster status card should be visible
        let monsterCard = app.descendants(matching: .any)["monsterStatusCard"]
        XCTAssertTrue(monsterCard.waitForExistence(timeout: 5), "Monster status card should be visible when coach mode is enabled")
    }

    /// GIVEN: Coach mode is disabled
    /// WHEN: Navigating to Review tab
    /// THEN: MonsterStatusView should NOT be visible
    func test_review_hidesMonsterStatus_whenCoachDisabled() throws {
        guard let coachToggle = navigateToCoachToggle() else {
            XCTFail("Coach mode toggle should exist")
            return
        }

        // Disable if currently on
        if coachToggle.value as? String == "1" {
            coachToggle.tap()
        }

        // Dismiss settings
        let fertigButton = app.buttons["Fertig"]
        if fertigButton.waitForExistence(timeout: 2) {
            fertigButton.tap()
        }

        // Navigate to Review tab
        let reviewTab = app.tabBars.buttons["Review"]
        guard reviewTab.waitForExistence(timeout: 3) else {
            XCTFail("Review tab should exist")
            return
        }
        reviewTab.tap()

        // Monster status card should NOT be visible
        let monsterCard = app.otherElements["monsterStatusCard"]
        XCTAssertFalse(monsterCard.waitForExistence(timeout: 2), "Monster status card should NOT be visible when coach mode is disabled")
    }
}
