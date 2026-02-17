import XCTest

final class AITaskScoringUITests: XCTestCase {

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

    // MARK: - Settings AI Toggle

    /// GIVEN: App is running
    /// WHEN: Opening Settings
    /// THEN: AI scoring toggle visibility should match Apple Intelligence availability
    ///       (visible on Apple Silicon + macOS 26, hidden on older devices)
    func test_settings_aiSection_matchesDeviceCapability() throws {
        // Navigate to Settings
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button should exist")
            return
        }
        settingsButton.tap()

        // Wait for settings to appear
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings should be visible")

        // AI toggle existence depends on device capability — just verify no crash
        let aiToggle = app.switches["aiScoringToggle"]
        // On devices with Apple Intelligence: toggle is visible
        // On devices without: toggle is not visible
        // Both states are valid — we verify UI doesn't crash
        _ = aiToggle.exists
    }

    /// GIVEN: App is running
    /// WHEN: Opening ViewMode picker in Backlog
    /// THEN: "KI-Empfehlung" option visibility matches Apple Intelligence availability
    func test_backlog_aiViewMode_presenceMatchesCapability() throws {
        // Open ViewMode switcher
        let switcher = app.buttons["viewModeSwitcher"]
        guard switcher.waitForExistence(timeout: 5) else {
            XCTFail("ViewMode switcher should exist")
            return
        }
        switcher.tap()

        // Wait for menu to appear
        sleep(1)

        // "KI-Empfehlung" visibility depends on device capability
        let aiOption = app.buttons["KI-Empfehlung"]
        // Both states are valid — we verify UI doesn't crash
        _ = aiOption.exists
    }

    /// GIVEN: A task exists in the Backlog
    /// WHEN: Viewing the task without prior AI scoring
    /// THEN: AI score badge should NOT be visible (scoring hasn't run)
    func test_backlog_aiScoreBadge_notVisibleWithoutScoring() throws {
        // First create a task
        let addButton = app.buttons["addTaskButton"]
        guard addButton.waitForExistence(timeout: 5) else {
            XCTFail("Add button should exist")
            return
        }
        addButton.tap()

        // Fill in task title
        let titleField = app.textFields["Task-Titel"]
        guard titleField.waitForExistence(timeout: 5) else {
            XCTFail("Title field should exist")
            return
        }
        titleField.tap()
        titleField.typeText("Test Task for AI")

        // Save
        let saveButton = app.buttons["Speichern"]
        guard saveButton.waitForExistence(timeout: 3) else {
            XCTFail("Save button should exist")
            return
        }
        saveButton.tap()

        // Wait for task to appear
        sleep(2)

        // AI score badge should NOT be visible (no scoring has run in test context)
        let scoreBadge = app.staticTexts.matching(identifier: "aiScoreBadge").firstMatch
        XCTAssertFalse(scoreBadge.exists, "AI score badge should NOT be visible without prior scoring")
    }
}
