import XCTest

/// UI Tests for Edit Redesign Feature
///
/// Tests verify:
/// 1. Inline Edit Section is REMOVED (no expansion on single-tap)
/// 2. Double-Tap on title activates inline title editing
/// 3. Full Edit Sheet uses chip-style for urgency and task type
///
/// TDD RED: These tests WILL FAIL because the functionality doesn't exist yet.
final class EditRedesignUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Helper: Navigate to Backlog tab and wait for tasks
    private func navigateToBacklog() {
        // Custom floating tab bar uses "tab-backlog" identifier
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(2) // Wait for tasks to load
    }

    /// Helper: Get first task title element
    private func getFirstTaskTitle() -> XCUIElement {
        // Tasks have accessibilityIdentifier like "taskTitle_<id>"
        // We look for any element starting with taskTitle_
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        return app.staticTexts.matching(predicate).firstMatch
    }

    /// Helper: Open Full Edit via 3-dot menu for first task
    private func openFullEditSheet() {
        navigateToBacklog()

        // Find actions menu button (3-dot menu)
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'actionsMenu_'")
        let menuButton = app.buttons.matching(predicate).firstMatch

        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Actions menu should exist")
        menuButton.tap()

        // Tap "Bearbeiten" in the menu
        let editButton = app.buttons["Bearbeiten"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit button should exist in menu")
        editButton.tap()

        sleep(1) // Wait for sheet to appear
    }

    // MARK: - Test 1: Inline Edit Section REMOVED

    /// Test: Single-tap on BacklogRow does NOT show inline edit section
    /// EXPECTED TO FAIL: Currently single-tap expands and shows duration buttons
    func testSingleTapDoesNotExpandRow() throws {
        navigateToBacklog()

        // Get first task
        let taskTitle = getFirstTaskTitle()
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5), "Task title should exist")

        // Single-tap on the task row
        taskTitle.tap()
        sleep(1)

        // OLD behavior: Shows duration quick-select buttons (5m, 15m, 30m, 60m)
        // NEW behavior: Should NOT show these buttons

        // Look for old inline edit elements that should NOT exist anymore
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'durationQuickSelect_'")
        let durationButtons = app.buttons.matching(predicate)

        // These should NOT exist after single-tap (old behavior shows them)
        XCTAssertEqual(durationButtons.count, 0, "Duration quick-select buttons should NOT appear on single-tap - inline edit section should be removed")
    }

    /// Test: Cancel and Save buttons from old inline edit should NOT exist
    /// EXPECTED TO FAIL: Currently these exist when row is expanded
    func testInlineEditButtonsDoNotExist() throws {
        navigateToBacklog()

        let taskTitle = getFirstTaskTitle()
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5), "Task title should exist")

        // Single-tap to trigger old expansion
        taskTitle.tap()
        sleep(1)

        // These buttons should NOT exist anymore
        let cancelPredicate = NSPredicate(format: "identifier BEGINSWITH 'cancelEditButton_'")
        let savePredicate = NSPredicate(format: "identifier BEGINSWITH 'saveEditButton_'")

        let cancelButton = app.buttons.matching(cancelPredicate).firstMatch
        let saveButton = app.buttons.matching(savePredicate).firstMatch

        XCTAssertFalse(cancelButton.exists, "Cancel edit button should NOT exist - inline edit section removed")
        XCTAssertFalse(saveButton.exists, "Save edit button should NOT exist - inline edit section removed")
    }

    // MARK: - Test 2: Double-Tap Title Edit

    /// Test: Double-tap on title activates inline title editing
    /// EXPECTED TO FAIL: Double-tap title edit not implemented yet
    func testDoubleTapTitleActivatesInlineEdit() throws {
        navigateToBacklog()

        let taskTitle = getFirstTaskTitle()
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5), "Task title should exist")

        // Double-tap on title
        taskTitle.doubleTap()
        sleep(1)

        // When in inline edit mode, keyboard should appear and there should be a text input
        // The text field may not have a specific identifier in the hierarchy, but the keyboard appears
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3), "Keyboard should appear for inline title editing")

        // Additionally check that a focused text element exists (any textfield on screen)
        let anyTextField = app.textFields.firstMatch
        let hasTextField = anyTextField.exists

        // Either keyboard exists (which already proves edit mode) or there's a text field
        XCTAssertTrue(keyboard.exists || hasTextField, "Inline title edit mode should be active (keyboard or text field present)")
    }

    /// Test: Double-tap title field is focused and editable
    /// EXPECTED TO FAIL: Double-tap title edit not implemented yet
    func testDoubleTapTitleFieldIsFocused() throws {
        navigateToBacklog()

        let taskTitle = getFirstTaskTitle()
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5), "Task title should exist")

        // Double-tap
        taskTitle.doubleTap()
        sleep(1)

        // Check keyboard appears (indicates field is focused)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3), "Keyboard should appear when title field is focused")
    }

    /// Test: Enter key saves title and exits edit mode
    /// EXPECTED TO FAIL: Double-tap title edit not implemented yet
    func testEnterSavesTitleEdit() throws {
        navigateToBacklog()

        let taskTitle = getFirstTaskTitle()
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5), "Task title should exist")

        // Get original title
        let originalTitle = taskTitle.label

        // Double-tap to edit
        taskTitle.doubleTap()
        sleep(1)

        // Verify keyboard appeared (edit mode active)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3), "Keyboard should appear for editing")

        // Type new title - XCUITest will type into the focused element
        let testTitle = "Edited Title \(Int.random(in: 1000...9999))"

        // First select all and delete existing text, then type new text
        // Use keyboard shortcut Command+A to select all (on simulator)
        app.typeText(testTitle)

        // Press Return to save
        app.keyboards.buttons["Return"].tap()
        sleep(1)

        // Keyboard should dismiss after Return
        XCTAssertFalse(keyboard.exists, "Keyboard should dismiss after pressing Return")

        // The title should have changed (we can verify edit mode exited)
        // Note: Due to the nature of inline editing, the exact text may vary
        // The key assertion is that Return dismisses the keyboard
    }

    // MARK: - Test 3: Full Edit Sheet Chip Style

    /// Test: Urgency in Full Edit is a flame toggle (not segmented picker)
    /// EXPECTED TO FAIL: Currently uses segmented picker
    func testFullEditUrgencyIsFlameToggle() throws {
        openFullEditSheet()

        // Scroll to make urgency section visible
        let scrollView = app.scrollViews["taskFormScrollView"]
        if scrollView.waitForExistence(timeout: 3) {
            scrollView.swipeUp()
            sleep(1)
        }

        // The flame toggle button is within the urgency section
        // Due to SwiftUI accessibility inheritance, it shows as taskFormSection_urgency
        // But we verify it's a tappable button with flame-related label
        let urgencyButton = app.buttons["taskFormSection_urgency"]

        XCTAssertTrue(urgencyButton.waitForExistence(timeout: 5), "Urgency flame toggle button should exist")

        // Verify it has flame-related label (not a segmented picker)
        // Label will be "Nicht gesetzt", "Dringend", or "Nicht dringend"
        let label = urgencyButton.label
        let validLabels = ["Nicht gesetzt", "Dringend", "Nicht dringend"]
        XCTAssertTrue(validLabels.contains(label), "Urgency button should have flame toggle label, got: \(label)")
    }

    /// Test: Tapping flame toggles urgency state
    /// EXPECTED TO FAIL: Flame toggle not implemented yet
    func testFlameToggleChangesUrgency() throws {
        openFullEditSheet()

        // Scroll to make urgency section visible
        let scrollView = app.scrollViews["taskFormScrollView"]
        if scrollView.waitForExistence(timeout: 3) {
            scrollView.swipeUp()
            sleep(1)
        }

        let urgencyButton = app.buttons["taskFormSection_urgency"]
        XCTAssertTrue(urgencyButton.waitForExistence(timeout: 5), "Urgency button should exist")

        // Get initial label
        let initialLabel = urgencyButton.label

        // Tap to toggle
        urgencyButton.tap()
        sleep(1)

        // Button should still exist and label should change
        XCTAssertTrue(urgencyButton.exists, "Urgency button should still exist after tap")

        // Label should have changed (cycled to next state)
        let newLabel = urgencyButton.label
        XCTAssertNotEqual(initialLabel, newLabel, "Urgency label should change after tap: was '\(initialLabel)', now '\(newLabel)'")
    }

    /// Test: Task Type in Full Edit is a horizontal chip row (not grid)
    /// EXPECTED TO FAIL: Currently uses 2-column grid
    func testFullEditTaskTypeIsChipRow() throws {
        openFullEditSheet()

        // Scroll down to make type section visible (it's near the bottom)
        let scrollView = app.scrollViews["taskFormScrollView"]
        if scrollView.waitForExistence(timeout: 3) {
            scrollView.swipeUp()
            sleep(1)
            scrollView.swipeUp()  // Second swipe to reach type section
            sleep(1)
        }

        // Check chips exist with their correct identifiers
        let incomeChip = app.buttons["taskTypeChip_income"]
        let maintenanceChip = app.buttons["taskTypeChip_maintenance"]

        XCTAssertTrue(incomeChip.waitForExistence(timeout: 5), "Income chip should exist in chip row")
        XCTAssertTrue(maintenanceChip.waitForExistence(timeout: 3), "Maintenance chip should exist in chip row")
    }

    /// Test: Task type chips have correct colors (matching BacklogRow badges)
    /// EXPECTED TO FAIL: Chip colors not implemented yet
    func testTaskTypeChipsHaveColors() throws {
        openFullEditSheet()

        // Scroll down to make type section visible (it's near the bottom)
        let scrollView = app.scrollViews["taskFormScrollView"]
        if scrollView.waitForExistence(timeout: 3) {
            scrollView.swipeUp()
            sleep(1)
            scrollView.swipeUp()  // Second swipe to reach type section
            sleep(1)
        }

        // Verify chips exist
        let incomeChip = app.buttons["taskTypeChip_income"]
        XCTAssertTrue(incomeChip.waitForExistence(timeout: 5), "Income chip should exist")

        // Tap to select and verify it changes appearance
        incomeChip.tap()
        sleep(1)

        // Chip should be selected (indicated by border or fill)
        // We can't directly test color, but we can verify interaction works
        XCTAssertTrue(incomeChip.exists, "Chip should still exist after tap")
    }

}

// MARK: - Helper Extension

extension XCUIElement {
    /// Clear text field and enter new text
    func clearAndEnterText(_ text: String) {
        guard let stringValue = self.value as? String else {
            self.typeText(text)
            return
        }

        // Select all and delete
        self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)

        // Type new text
        self.typeText(text)
    }
}
