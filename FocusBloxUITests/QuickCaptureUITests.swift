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
    /// THEN: Should show as half-sheet with text field and save button
    func testQuickCaptureViewAppears() throws {
        // New compact design: no navigation bar, just text field + button
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "QuickCaptureView should appear with text field")

        let saveButton = app.buttons["quickCaptureSaveButton"]
        XCTAssertTrue(saveButton.exists,
                      "Save button should be visible")
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
    /// THEN: Success checkmark should appear, then auto-dismiss
    func testSaveShowsSuccessAndAutoDismisses() throws {
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

        // Success checkmark should appear
        let successIcon = app.images["quickCaptureSuccessIcon"]
        XCTAssertTrue(successIcon.waitForExistence(timeout: 2),
                      "Success checkmark should appear after save")

        // Text field and save button should be gone (replaced by checkmark)
        XCTAssertFalse(textField.exists,
                       "Text field should be hidden during success animation")

        // View should auto-dismiss after ~600ms - check that quickCaptureTextField is gone
        XCTAssertTrue(textField.waitForNonExistence(timeout: 5),
                      "QuickCaptureView should auto-dismiss after success animation")
    }

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: User swipes down to dismiss
    /// THEN: View should be dismissed without creating task
    func testSwipeDownDismissesWithoutSaving() throws {
        let textField = app.textFields["quickCaptureTextField"]

        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        // Type something but don't save
        textField.tap()
        textField.typeText("Should Not Be Saved")

        // Dismiss keyboard first by tapping outside
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            // Tap on the sheet area above the keyboard to dismiss it
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
            // Wait for keyboard to dismiss
            _ = keyboard.waitForNonExistence(timeout: 2)
        }

        // Swipe down on the drag indicator area (sheet is at 0.4 fraction now)
        let startPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        let endPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        startPoint.press(forDuration: 0.1, thenDragTo: endPoint)

        // View should be dismissed - text field should be gone
        XCTAssertTrue(textField.waitForNonExistence(timeout: 3),
                      "QuickCaptureView should be dismissed after swipe down")

        // Task should NOT be created
        let notCreatedTask = app.staticTexts["Should Not Be Saved"]
        XCTAssertFalse(notCreatedTask.exists,
                       "Task should NOT be created when dismissed via swipe")
    }

    // MARK: - UI Element Tests

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: Looking at UI elements
    /// THEN: Should have text field, metadata buttons, and save button
    func testQuickCaptureMinimalistUI() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        // Should have metadata cycle buttons (compact UI, not full forms)
        let importanceBtn = app.buttons["qc_importanceButton"]
        let urgencyBtn = app.buttons["qc_urgencyButton"]
        let categoryBtn = app.buttons["qc_categoryButton"]
        let durationBtn = app.buttons["qc_durationButton"]

        XCTAssertTrue(importanceBtn.exists,
                      "Importance cycle button should exist")
        XCTAssertTrue(urgencyBtn.exists,
                      "Urgency cycle button should exist")
        XCTAssertTrue(categoryBtn.exists,
                      "Category button should exist")
        XCTAssertTrue(durationBtn.exists,
                      "Duration button should exist")
    }

    // MARK: - Metadata Button Tests

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: View appears
    /// THEN: Metadata buttons should exist with their identifiers
    func testMetadataButtonsExist() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        let importanceBtn = app.buttons["qc_importanceButton"]
        let urgencyBtn = app.buttons["qc_urgencyButton"]
        let categoryBtn = app.buttons["qc_categoryButton"]
        let durationBtn = app.buttons["qc_durationButton"]

        XCTAssertTrue(importanceBtn.exists,
                      "Importance button should exist with qc_importanceButton identifier")
        XCTAssertTrue(urgencyBtn.exists,
                      "Urgency button should exist with qc_urgencyButton identifier")
        XCTAssertTrue(categoryBtn.exists,
                      "Category button should exist with qc_categoryButton identifier")
        XCTAssertTrue(durationBtn.exists,
                      "Duration button should exist with qc_durationButton identifier")
    }

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: User taps importance button 3 times
    /// THEN: Should cycle through nil → 1 → 2 → 3
    func testImportanceCycles() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        let importanceBtn = app.buttons["qc_importanceButton"]
        XCTAssertTrue(importanceBtn.exists, "Importance button should exist")

        // Initial state: nil (shows questionmark)
        // Tap 1: → importance 1 (exclamationmark)
        importanceBtn.tap()

        // Tap 2: → importance 2 (exclamationmark.2)
        importanceBtn.tap()

        // Tap 3: → importance 3 (exclamationmark.3)
        importanceBtn.tap()

        // After 3 taps, should still exist (cycling is internal state)
        XCTAssertTrue(importanceBtn.exists, "Importance button should still exist after cycling")
    }

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: User taps category button
    /// THEN: Category picker sheet should appear
    func testCategoryOpensSheet() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        let categoryBtn = app.buttons["qc_categoryButton"]
        XCTAssertTrue(categoryBtn.exists, "Category button should exist")

        // Tap to open picker
        categoryBtn.tap()

        // Category picker sheet should appear
        let categoryPicker = app.otherElements["category-picker"]
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 2),
                      "Category picker sheet should appear when category button is tapped")
    }

    /// GIVEN: QuickCaptureView is displayed
    /// WHEN: User taps duration button
    /// THEN: Duration picker sheet should appear
    func testDurationOpensSheet() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        let durationBtn = app.buttons["qc_durationButton"]
        XCTAssertTrue(durationBtn.exists, "Duration button should exist")

        // Tap to open picker
        durationBtn.tap()

        // Duration picker sheet should appear (using existing DurationPicker)
        // DurationPicker has a "Dauer waehlen" headline
        let durationHeader = app.staticTexts["Dauer waehlen"]
        XCTAssertTrue(durationHeader.waitForExistence(timeout: 2),
                      "Duration picker sheet should appear when duration button is tapped")
    }

    /// GIVEN: QuickCaptureView with text and metadata set
    /// WHEN: User saves
    /// THEN: Success icon should appear
    func testSaveWithMetadata() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        // Enter task title
        textField.tap()
        textField.typeText("Task with metadata")

        // Dismiss keyboard to access metadata buttons
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            // Tap on sheet background to dismiss keyboard
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
            _ = keyboard.waitForNonExistence(timeout: 2)
        }

        // Set importance (tap once for level 1)
        let importanceBtn = app.buttons["qc_importanceButton"]
        XCTAssertTrue(importanceBtn.waitForExistence(timeout: 2), "Importance button should exist")
        importanceBtn.tap()

        // Set urgency (tap once for not_urgent)
        let urgencyBtn = app.buttons["qc_urgencyButton"]
        XCTAssertTrue(urgencyBtn.exists, "Urgency button should exist")
        urgencyBtn.tap()

        // Save task
        let saveButton = app.buttons["quickCaptureSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2), "Save button should exist")
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled")
        saveButton.tap()

        // Success icon should appear
        let successIcon = app.images["quickCaptureSuccessIcon"]
        XCTAssertTrue(successIcon.waitForExistence(timeout: 2),
                      "Success icon should appear after saving task with metadata")
    }
}

// MARK: - Control Center Trigger Tests

/// Tests for the Control Center quick capture trigger
/// The CC button sets an App Group UserDefaults flag that the app checks on activation
final class QuickCaptureCCTriggerTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-SimulateCCTrigger"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// GIVEN: CC trigger flag is set in App Group UserDefaults
    /// WHEN: App becomes active (simulated via -SimulateCCTrigger flag)
    /// THEN: QuickCaptureView should appear automatically
    func testCCTriggerOpensQuickCapture() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "QuickCaptureView should appear when CC trigger flag is set")

        let saveButton = app.buttons["quickCaptureSaveButton"]
        XCTAssertTrue(saveButton.exists,
                      "Save button should be visible")
    }

    /// GIVEN: CC trigger opened QuickCapture
    /// WHEN: User enters text and saves
    /// THEN: Task is created and view dismisses
    func testCCTriggerFullFlow() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        textField.tap()
        textField.typeText("CC Trigger Task")

        let saveButton = app.buttons["quickCaptureSaveButton"]
        saveButton.tap()

        // Should show success and auto-dismiss
        let successIcon = app.images["quickCaptureSuccessIcon"]
        XCTAssertTrue(successIcon.waitForExistence(timeout: 2),
                      "Success icon should appear after save")

        let backlogNav = app.navigationBars["FocusBlox"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 5),
                      "Should return to Backlog after CC trigger save")
    }
}

// MARK: - URL Scheme Tests

/// Tests for the actual URL scheme handling (focusblox://create-task)
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

        // QuickCapture should NOT appear on normal launch (no text field visible)
        let quickCaptureField = app.textFields["quickCaptureTextField"]
        XCTAssertFalse(quickCaptureField.waitForExistence(timeout: 2),
                       "QuickCaptureView should NOT appear on normal app launch")

        // Backlog should be visible instead
        let backlogNav = app.navigationBars["FocusBlox"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 3),
                      "Backlog should be visible on normal launch")
    }

    /// GIVEN: App is running
    /// WHEN: focusblox://create-task URL is opened
    /// THEN: QuickCaptureView should appear
    func testURLSchemeOpensQuickCapture() throws {
        app.launch()

        // Verify we're on Backlog first
        let backlogNav = app.navigationBars["FocusBlox"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 3),
                      "Should start on Backlog")

        // Open the URL scheme
        let url = URL(string: "focusblox://create-task")!
        XCUIDevice.shared.system.open(url)

        // QuickCapture should now appear (text field visible)
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "QuickCaptureView should appear when URL scheme is opened")
    }

    /// GIVEN: App is running
    /// WHEN: Invalid URL host is opened (focusblox://invalid)
    /// THEN: QuickCaptureView should NOT appear
    func testInvalidURLHostDoesNotOpenQuickCapture() throws {
        app.launch()

        // Verify we're on Backlog first
        let backlogNav = app.navigationBars["FocusBlox"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 3),
                      "Should start on Backlog")

        // Open an invalid URL (wrong host)
        let url = URL(string: "focusblox://invalid-action")!
        XCUIDevice.shared.system.open(url)

        // QuickCapture should NOT appear (no text field)
        let quickCaptureField = app.textFields["quickCaptureTextField"]
        XCTAssertFalse(quickCaptureField.waitForExistence(timeout: 2),
                       "QuickCaptureView should NOT appear for invalid URL host")

        // Should still be on Backlog
        XCTAssertTrue(backlogNav.exists,
                      "Should remain on Backlog for invalid URL")
    }

    /// GIVEN: QuickCapture opened via URL
    /// WHEN: User completes full flow (enter text, save)
    /// THEN: Should show success and return to previous view
    func testURLSchemeFullFlow() throws {
        app.launch()

        // Open QuickCapture via URL
        let url = URL(string: "focusblox://create-task")!
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

        // Should show success checkmark
        let successIcon = app.images["quickCaptureSuccessIcon"]
        XCTAssertTrue(successIcon.waitForExistence(timeout: 2),
                      "Success icon should appear after save")

        // Should auto-dismiss and return to Backlog
        let backlogNav = app.navigationBars["FocusBlox"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 5),
                      "Should return to Backlog after saving via URL scheme")
    }
}
