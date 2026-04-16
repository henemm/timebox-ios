import XCTest

final class TaskIdeaSuggestionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-taskIdeaSuggestionsEnabled", "NO"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToSettings() {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
        settingsButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings should be visible")
    }

    private func scrollToToggle(_ identifier: String) -> XCUIElement {
        let toggle = app.switches[identifier]
        if toggle.waitForExistence(timeout: 3) { return toggle }

        // Scroll down to find the toggle
        let form = app.collectionViews.firstMatch
        for _ in 0..<5 {
            form.swipeUp()
            if toggle.waitForExistence(timeout: 1) { return toggle }
        }
        return toggle
    }

    private func navigateToCreateTask() {
        app.tabBars.buttons["Backlog"].tap()
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add task button should exist")
        addButton.tap()
    }

    // MARK: - Settings Toggle

    /// GIVEN: User opens Settings
    /// WHEN: AI Task Ideas section is visible
    /// THEN: Toggle "KI Task-Ideen" exists
    func test_settings_taskIdeasToggleExists() throws {
        navigateToSettings()

        let toggle = scrollToToggle("taskIdeaSuggestionsToggle")
        XCTAssertTrue(toggle.exists, "Task Ideas toggle should exist in Settings")
    }

    /// GIVEN: User opens Settings
    /// WHEN: AI section is visible
    /// THEN: Toggle has a boolean value (0 or 1)
    func test_settings_taskIdeasToggleHasBooleanValue() throws {
        navigateToSettings()

        let toggle = scrollToToggle("taskIdeaSuggestionsToggle")
        XCTAssertTrue(toggle.exists, "Task Ideas toggle should exist")

        let toggleValue = toggle.value as? String
        XCTAssertTrue(toggleValue == "0" || toggleValue == "1", "Toggle should have a boolean value, got: \(toggleValue ?? "nil")")
    }

    // MARK: - CreateTaskView Integration

    /// GIVEN: Task Ideas is disabled (default)
    /// WHEN: User opens CreateTaskView
    /// THEN: No "Vielleicht auch interessant?" section appears
    func test_createTask_noIdeasSectionWhenDisabled() throws {
        navigateToCreateTask()

        let header = app.staticTexts["Vielleicht auch interessant?"]
        XCTAssertFalse(header.waitForExistence(timeout: 3), "Ideas section should not appear when feature is disabled")
    }
}
