import XCTest

/// UI Tests for RW_1.1: Quick Capture creates tasks with lifecycleStatus "raw"
/// that do NOT appear in the backlog.
final class LifecycleStatusUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-QuickCaptureTest"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Quick Capture → Backlog Visibility

    /// GIVEN: Quick Capture is open
    /// WHEN: User creates a task via Quick Capture
    /// THEN: Task should NOT appear in the Backlog (lifecycleStatus = "raw")
    ///
    /// EXPECTED TO FAIL: Currently Quick Capture creates tasks without lifecycleStatus,
    /// so they appear in the backlog. After implementation, raw tasks are filtered.
    func testQuickCaptureTask_notVisibleInBacklog() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "Quick Capture text field should appear")

        // Create a task with a unique title
        let uniqueTitle = "RawLifecycleTestTask_\(Int.random(in: 1000...9999))"
        textField.tap()
        textField.typeText(uniqueTitle)

        // Save the task
        let saveButton = app.buttons["quickCaptureSaveButton"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        // Wait for sheet to dismiss
        XCTAssertTrue(textField.waitForNonExistence(timeout: 5),
                      "Quick Capture sheet should dismiss after save")

        // Navigate to Backlog tab — wait for tab bar to appear after sheet dismissal
        let backlogTab = app.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5),
                      "Backlog tab should be visible after sheet dismissal")
        backlogTab.tap()

        // Wait for search field to confirm backlog is loaded
        let searchField = app.searchFields.firstMatch
        _ = searchField.waitForExistence(timeout: 3)

        // The task should NOT appear in the backlog (lifecycleStatus = "raw")
        let taskInBacklog = app.staticTexts[uniqueTitle]
        XCTAssertFalse(taskInBacklog.exists,
                       "Quick Capture task should NOT appear in Backlog — lifecycleStatus must be 'raw'")
    }
}
