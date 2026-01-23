import XCTest

/// UI Tests for Quick Capture Launcher feature - View behavior tests
/// Uses -QuickCaptureTest flag to directly open the view for testing
final class QuickCaptureUITests: XCTestCase {

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

    // MARK: - View Behavior Tests

    /// GIVEN: QuickCaptureView is displayed (via test flag)
    /// WHEN: View appears
    /// THEN: Navigation title should be "Quick Capture"
    func testQuickCaptureViewAppears() throws {
        let quickCaptureTitle = app.navigationBars["Quick Capture"]
        XCTAssertTrue(quickCaptureTitle.waitForExistence(timeout: 3),
                      "QuickCaptureView should appear with correct title")
    }

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: View appears
    /// THEN: Text field should have keyboard focus
    /// EXPECTED TO FAIL: QuickCaptureView doesn't exist yet
    func testQuickCaptureHasKeyboardFocus() throws {
        // Look for the quick capture text field
        let textField = app.textFields["quickCaptureTextField"]

        // This will FAIL because QuickCaptureView doesn't exist
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        // Check if keyboard is visible (indicates focus)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3),
                      "Keyboard should be visible (text field has focus)")
    }

    /// GIVEN: QuickCaptureView with empty text field
    /// WHEN: Looking at Save button
    /// THEN: Save button should be disabled
    /// EXPECTED TO FAIL: QuickCaptureView doesn't exist yet
    func testSaveDisabledWhenEmpty() throws {
        let saveButton = app.buttons["quickCaptureSaveButton"]

        // This will FAIL because QuickCaptureView doesn't exist
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3),
                      "Save button should exist")
        XCTAssertFalse(saveButton.isEnabled,
                       "Save button should be disabled when text field is empty")
    }

    /// GIVEN: QuickCaptureView with text entered
    /// WHEN: User taps Save
    /// THEN: Task should be created and view dismissed
    func testSaveCreatesTaskAndDismisses() throws {
        let textField = app.textFields["quickCaptureTextField"]

        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        // Type a task title
        textField.tap()
        textField.typeText("Quick Test Task")

        // Tap save
        let saveButton = app.buttons["quickCaptureSaveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled after entering text")
        saveButton.tap()

        // View should be dismissed (no more Quick Capture elements)
        XCTAssertFalse(textField.waitForExistence(timeout: 2),
                       "QuickCaptureView should be dismissed after save")

        // Verify we returned to main view (Backlog)
        let backlogNav = app.navigationBars["Backlog"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 3),
                      "Should return to main view after save")

        // Note: Task persistence is verified by unit tests (LocalTaskSourceTests)
        // UI test verifies the flow: enter text -> save -> dismiss
    }

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: User taps Cancel
    /// THEN: View should be dismissed without creating task
    /// EXPECTED TO FAIL: QuickCaptureView doesn't exist yet
    func testCancelDismissesWithoutSaving() throws {
        let textField = app.textFields["quickCaptureTextField"]

        // This will FAIL because QuickCaptureView doesn't exist
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        // Type something but don't save
        textField.tap()
        textField.typeText("Should Not Be Saved")

        // Tap cancel
        let cancelButton = app.buttons["quickCaptureCancelButton"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
        cancelButton.tap()

        // View should be dismissed
        XCTAssertFalse(textField.waitForExistence(timeout: 2),
                       "QuickCaptureView should be dismissed after cancel")

        // Task should NOT be created
        let backlogNav = app.navigationBars["Backlog"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 3),
                      "Should return to main view after cancel")

        let notCreatedTask = app.staticTexts["Should Not Be Saved"]
        XCTAssertFalse(notCreatedTask.exists,
                       "Task should NOT be created when cancelled")
    }

    // MARK: - UI Element Tests

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: Looking at UI elements
    /// THEN: Should have minimal UI (just text field and buttons)
    /// EXPECTED TO FAIL: QuickCaptureView doesn't exist yet
    func testQuickCaptureMinimalistUI() throws {
        // Quick Capture should be minimal - no duration picker, no priority, etc.
        let textField = app.textFields["quickCaptureTextField"]

        // This will FAIL because QuickCaptureView doesn't exist
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        // Should NOT have complex form elements
        let durationSection = app.staticTexts["Dauer"]
        let prioritySection = app.staticTexts["Priorität"]
        let urgencySection = app.staticTexts["Dringlichkeit"]

        XCTAssertFalse(durationSection.exists,
                       "Quick Capture should NOT have duration section")
        XCTAssertFalse(prioritySection.exists,
                       "Quick Capture should NOT have priority section")
        XCTAssertFalse(urgencySection.exists,
                       "Quick Capture should NOT have urgency section")
    }
}

// MARK: - URL Scheme Tests

/// Tests for the actual URL scheme handling (timebox://create-task)
/// These tests verify the deep link integration works correctly
final class QuickCaptureURLSchemeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // NO -QuickCaptureTest flag - we want to test the real URL handling
        app.launchArguments = ["-UITesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// GIVEN: App launched normally (without QuickCaptureTest flag)
    /// WHEN: App starts
    /// THEN: QuickCaptureView should NOT appear automatically
    func testAppLaunchDoesNotShowQuickCapture() throws {
        app.launch()

        // QuickCapture should NOT appear on normal launch
        let quickCaptureTitle = app.navigationBars["Quick Capture"]
        XCTAssertFalse(quickCaptureTitle.waitForExistence(timeout: 2),
                       "QuickCaptureView should NOT appear on normal app launch")

        // Backlog should be visible instead
        let backlogNav = app.navigationBars["Backlog"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 3),
                      "Backlog should be visible on normal launch")
    }

    /// GIVEN: App is running
    /// WHEN: timebox://create-task URL is opened
    /// THEN: QuickCaptureView should appear
    func testURLSchemeOpensQuickCapture() throws {
        app.launch()

        // Verify we're on Backlog first
        let backlogNav = app.navigationBars["Backlog"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 3),
                      "Should start on Backlog")

        // Open the URL scheme
        let url = URL(string: "timebox://create-task")!
        XCUIDevice.shared.system.open(url)

        // QuickCapture should now appear
        let quickCaptureTitle = app.navigationBars["Quick Capture"]
        XCTAssertTrue(quickCaptureTitle.waitForExistence(timeout: 5),
                      "QuickCaptureView should appear when URL scheme is opened")

        // Text field should be present
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist after URL open")
    }

    /// GIVEN: App is running
    /// WHEN: Invalid URL host is opened (timebox://invalid)
    /// THEN: QuickCaptureView should NOT appear
    func testInvalidURLHostDoesNotOpenQuickCapture() throws {
        app.launch()

        // Verify we're on Backlog first
        let backlogNav = app.navigationBars["Backlog"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 3),
                      "Should start on Backlog")

        // Open an invalid URL (wrong host)
        let url = URL(string: "timebox://invalid-action")!
        XCUIDevice.shared.system.open(url)

        // QuickCapture should NOT appear
        let quickCaptureTitle = app.navigationBars["Quick Capture"]
        XCTAssertFalse(quickCaptureTitle.waitForExistence(timeout: 2),
                       "QuickCaptureView should NOT appear for invalid URL host")

        // Should still be on Backlog
        XCTAssertTrue(backlogNav.exists,
                      "Should remain on Backlog for invalid URL")
    }

    /// GIVEN: QuickCapture opened via URL
    /// WHEN: User completes full flow (enter text, save)
    /// THEN: Should return to previous view
    func testURLSchemeFullFlow() throws {
        app.launch()

        // Open QuickCapture via URL
        let url = URL(string: "timebox://create-task")!
        XCUIDevice.shared.system.open(url)

        // Wait for QuickCapture
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "Quick capture text field should exist")

        // Enter task and save
        textField.tap()
        textField.typeText("URL Scheme Test Task")

        let saveButton = app.buttons["quickCaptureSaveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Save should be enabled")
        saveButton.tap()

        // Should return to Backlog
        let backlogNav = app.navigationBars["Backlog"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 3),
                      "Should return to Backlog after saving via URL scheme")
    }
}
