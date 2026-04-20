import XCTest

/// UI Tests for Toolbar Consistency (Bug #285)
///
/// Validates that:
/// 1. BacklogView has NO sparkles/hygiene button in toolbar
/// 2. BacklogView has a settings gear icon
/// 3. CoachView has a settings gear icon
final class ToolbarConsistencyUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - BacklogView Toolbar

    func test_backlogView_hasSettingsButton() {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        guard backlogTab.waitForExistence(timeout: 5) else {
            XCTFail("Backlog tab not found")
            return
        }
        backlogTab.tap()

        // Settings button must exist (via .withSettingsToolbar())
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "BacklogView must have a settings gear icon")
    }

    func test_backlogView_noSparklesButton() {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        guard backlogTab.waitForExistence(timeout: 5) else {
            XCTFail("Backlog tab not found")
            return
        }
        backlogTab.tap()

        // Sparkles/hygiene button must NOT exist in toolbar
        let hygieneButton = app.buttons["hygieneToolbarButton"]
        XCTAssertFalse(hygieneButton.exists, "BacklogView must NOT have sparkles/hygiene button in toolbar")
    }

    // MARK: - CoachView Toolbar

    func test_coachView_hasSettingsButton() {
        // Coach tab is typically the first/default tab
        let coachTab = app.tabBars.buttons["Coach"]
        if coachTab.waitForExistence(timeout: 5) {
            coachTab.tap()
        }

        // Settings button must exist (via .withSettingsToolbar())
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "CoachView must have a settings gear icon")
    }
}
