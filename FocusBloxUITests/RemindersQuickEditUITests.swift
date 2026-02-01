import XCTest

/// UI Tests for Bug: Reminders tasks - Quick Edit importance/urgency not persisted
/// Root Cause: After saving, loadTasks() triggers importFromReminders() which overwrites importance
/// Also: isLoading=true causes scroll position to jump to top
///
/// NOTE: The actual bug only affects tasks from Apple Reminders.
/// In simulator testing, we verify that Quick Edit buttons work without crashing
/// and that the scroll position is preserved (no loading indicator shown).
final class RemindersQuickEditUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Test: Importance badge tap doesn't crash

    /// Test: Tapping importance badge should work without crashing
    func testImportanceBadgeTapWorks() throws {
        // Navigate to Backlog tab
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        // Wait for tasks to load
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "ScrollView should exist")

        // Find an importance badge (any task)
        let importanceBadge = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")).firstMatch
        guard importanceBadge.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks in backlog - cannot test importance badge")
        }

        // Tap to set importance - should not crash
        importanceBadge.tap()

        // Verify app is still responsive
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(backlogTab.exists, "App should still be responsive after importance tap")
    }

    // MARK: - Test: Urgency badge tap doesn't crash

    /// Test: Tapping urgency badge should work without crashing
    func testUrgencyBadgeTapWorks() throws {
        // Navigate to Backlog tab
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        // Wait for tasks to load
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "ScrollView should exist")

        // Find an urgency badge (any task)
        let urgencyBadge = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'urgencyBadge_'")).firstMatch
        guard urgencyBadge.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks in backlog - cannot test urgency badge")
        }

        // Tap to set urgency - should not crash
        urgencyBadge.tap()

        // Verify app is still responsive
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(backlogTab.exists, "App should still be responsive after urgency tap")
    }

    // MARK: - Test: No loading indicator on Quick Edit

    /// Test: After tapping importance/urgency, loading indicator should NOT appear
    /// This preserves scroll position
    func testNoLoadingIndicatorOnQuickEdit() throws {
        // Navigate to Backlog tab
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        // Wait for initial load to complete
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "ScrollView should exist")

        // Find an importance badge
        let importanceBadge = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")).firstMatch
        guard importanceBadge.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks in backlog")
        }

        // Tap the badge
        importanceBadge.tap()

        // Immediately check for loading indicator - it should NOT exist
        let loadingIndicator = app.staticTexts["Lade Tasks..."]
        let loadingExists = loadingIndicator.waitForExistence(timeout: 0.5)

        XCTAssertFalse(loadingExists, "Loading indicator should NOT appear on Quick Edit - this would reset scroll position")
    }

    // MARK: - Test: Full Edit works for any task

    /// Test: Opening Full Edit sheet should work for any task
    func testFullEditSheetOpens() throws {
        // Navigate to Backlog tab
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        // Wait for tasks to load
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "ScrollView should exist")

        // Find actions menu for any task
        let actionsMenu = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'actionsMenu_'")).firstMatch
        guard actionsMenu.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks in backlog")
        }

        // Open menu and tap Edit
        actionsMenu.tap()

        let editButton = app.buttons["Bearbeiten"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit button should appear in menu")
        editButton.tap()

        // Verify edit sheet opened
        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should exist in edit sheet")

        // Close the sheet
        let cancelButton = app.buttons["Abbrechen"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }
}
