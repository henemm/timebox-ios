import XCTest

/// UI Tests for Bug 17: TaskFormSheet Glass Card Design
///
/// Tests verify the form uses modern Glass Card styling with proper structure
///
/// TDD RED: Tests FAIL because old Form design exists
/// TDD GREEN: Tests PASS after Glass Card redesign
final class TaskFormGlassCardUITests: XCTestCase {

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

    // MARK: - Helper

    private func navigateToBacklog() {
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(1)
    }

    private func openCreateTaskSheet() {
        let addButton = app.buttons["addTaskButton"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        } else {
            let navAddButton = app.navigationBars.buttons.matching(
                NSPredicate(format: "label CONTAINS 'Hinzufügen' OR label CONTAINS 'plus'")
            ).firstMatch
            if navAddButton.waitForExistence(timeout: 3) {
                navAddButton.tap()
            }
        }
        sleep(1)
    }

    // MARK: - Glass Card Structure Tests

    /// Test: Form should use ScrollView (not default Form)
    func testFormUsesScrollView() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Screenshot for visual verification
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bug17-TaskForm-GlassCard"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Check for custom scroll view container
        let customContainer = app.scrollViews["taskFormScrollView"]

        XCTAssertTrue(
            customContainer.waitForExistence(timeout: 3),
            "Bug 17: TaskFormSheet should use custom ScrollView container, not default Form."
        )
    }

    /// Test: Form should have title text field (inside scrollview)
    func testFormHasTitleField() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Look for title field within the sheet/scrollview
        let titleField = app.textFields.matching(
            NSPredicate(format: "identifier == 'taskTitle' OR placeholderValue CONTAINS 'Titel'")
        ).firstMatch

        XCTAssertTrue(
            titleField.waitForExistence(timeout: 3),
            "Bug 17: TaskFormSheet should have title text field."
        )
    }

    /// Test: Form should have importance section (Wichtigkeit header visible)
    func testFormHasImportanceSection() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Wait for sheet to fully load
        sleep(1)

        // Check for "Wichtigkeit" label text
        let wichtigkeitLabel = app.staticTexts["Wichtigkeit"]
        let hasSection = wichtigkeitLabel.waitForExistence(timeout: 3)

        // Take screenshot to verify visually
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bug17-ImportanceSection"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(
            hasSection,
            "Bug 17: TaskFormSheet should have 'Wichtigkeit' section header visible."
        )
    }
}
