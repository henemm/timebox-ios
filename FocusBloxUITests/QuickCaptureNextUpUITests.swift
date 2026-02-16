import XCTest

/// UI Tests for QuickAdd "Next Up" Checkbox feature
/// Tests that all Quick-Add flows have a Next Up toggle button
/// EXPECTED TO FAIL: Next Up toggle doesn't exist yet in any Quick-Add flow
final class QuickCaptureNextUpUITests: XCTestCase {

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

    // MARK: - Next Up Toggle Existence

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: View appears with metadata buttons
    /// THEN: Next Up toggle button should exist alongside other metadata buttons
    /// EXPECTED TO FAIL: qc_nextUpButton doesn't exist yet
    func testNextUpToggleExists() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        let nextUpButton = app.buttons["qc_nextUpButton"]
        XCTAssertTrue(nextUpButton.exists,
                      "Next Up toggle button should exist in metadata row")
    }

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: Next Up toggle is visible
    /// THEN: It should be hittable (not covered by keyboard or other elements)
    /// EXPECTED TO FAIL: qc_nextUpButton doesn't exist yet
    func testNextUpToggleIsHittable() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        let nextUpButton = app.buttons["qc_nextUpButton"]
        XCTAssertTrue(nextUpButton.waitForExistence(timeout: 2),
                      "Next Up button should exist")
        XCTAssertTrue(nextUpButton.isHittable,
                      "Next Up button should be hittable")
    }

    // MARK: - Next Up Toggle Interaction

    /// GIVEN: QuickCaptureView with Next Up toggle inactive
    /// WHEN: User taps the Next Up toggle
    /// THEN: Toggle should activate (visual feedback)
    /// EXPECTED TO FAIL: qc_nextUpButton doesn't exist yet
    func testNextUpToggleTap() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        let nextUpButton = app.buttons["qc_nextUpButton"]
        XCTAssertTrue(nextUpButton.waitForExistence(timeout: 2),
                      "Next Up button should exist")

        // Tap to activate
        nextUpButton.tap()

        // Button should still exist after tap (toggle state changes internally)
        XCTAssertTrue(nextUpButton.exists,
                      "Next Up button should still exist after tapping")
    }

    // MARK: - Full Flow: Save with Next Up

    /// GIVEN: QuickCaptureView with Next Up toggle activated
    /// WHEN: User enters title and saves
    /// THEN: Task should be created successfully (success icon appears)
    /// EXPECTED TO FAIL: qc_nextUpButton doesn't exist yet
    func testSaveTaskWithNextUpToggle() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        // Enter task title
        textField.tap()
        textField.typeText("Next Up Test Task")

        // Activate Next Up toggle
        let nextUpButton = app.buttons["qc_nextUpButton"]
        XCTAssertTrue(nextUpButton.waitForExistence(timeout: 2),
                      "Next Up button should exist")
        nextUpButton.tap()

        // Save
        let saveButton = app.buttons["quickCaptureSaveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled")
        saveButton.tap()

        // Success icon should appear
        let successIcon = app.images["quickCaptureSuccessIcon"]
        XCTAssertTrue(successIcon.waitForExistence(timeout: 2),
                      "Success icon should appear after saving task with Next Up")
    }
}
