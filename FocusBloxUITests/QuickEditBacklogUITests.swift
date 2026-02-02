import XCTest

/// UI Tests for Quick Edit Backlog - Inline editing of task metadata
///
/// Tests verify that users can edit Importance, Category, and Duration
/// directly from BacklogRow via tappable badges and context menu,
/// without navigating through Detail Sheet → Edit Sheet (3-step flow).
///
/// TDD RED: These tests WILL FAIL because inline badges/pickers don't exist yet.
final class QuickEditBacklogUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Navigate to Backlog tab and wait for tasks to load
    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(2)
    }

    // MARK: - Feature A: Tappable Importance Badge

    /// Test: Importance badge exists in BacklogRow and is tappable
    /// EXPECTED TO FAIL: importance-badge identifier doesn't exist yet
    func testImportanceBadgeExists() throws {
        navigateToBacklog()

        // Look for any importance badge in the backlog
        let importanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importance-badge-'")
        ).firstMatch

        XCTAssertTrue(
            importanceBadge.waitForExistence(timeout: 5),
            "Backlog should show tappable importance badges on tasks"
        )
    }

    /// Test: Tapping importance badge opens ImportancePicker
    /// WITH SCREENSHOTS for visual verification
    func testImportanceBadgeTapOpensPicker() throws {
        navigateToBacklog()

        // Screenshot 1: Backlog before tap
        let screenshot1 = XCTAttachment(screenshot: app.screenshot())
        screenshot1.name = "1_Backlog_Before_Tap"
        screenshot1.lifetime = .keepAlways
        add(screenshot1)

        let importanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importance-badge-'")
        ).firstMatch

        guard importanceBadge.waitForExistence(timeout: 5) else {
            XCTFail("Importance badge not found")
            return
        }

        // Screenshot 2: Badge found
        let screenshot2 = XCTAttachment(screenshot: app.screenshot())
        screenshot2.name = "2_Badge_Found"
        screenshot2.lifetime = .keepAlways
        add(screenshot2)

        importanceBadge.tap()
        sleep(2)

        // Screenshot 3: After tap - picker should be open
        let screenshot3 = XCTAttachment(screenshot: app.screenshot())
        screenshot3.name = "3_After_Tap_Picker_Should_Be_Open"
        screenshot3.lifetime = .keepAlways
        add(screenshot3)

        // ImportancePicker should appear
        let picker = app.otherElements["importance-picker"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            "ImportancePicker should open after tapping importance badge"
        )
    }

    /// Test: Selecting "Hoch" in ImportancePicker updates the badge
    /// EXPECTED TO FAIL: ImportancePicker doesn't exist yet
    func testImportancePickerSelectionUpdates() throws {
        navigateToBacklog()

        let importanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importance-badge-'")
        ).firstMatch

        guard importanceBadge.waitForExistence(timeout: 5) else {
            XCTFail("Importance badge not found")
            return
        }

        importanceBadge.tap()
        sleep(1)

        // Tap "Hoch" button in the picker
        let hochButton = app.buttons["importance-high"]
        XCTAssertTrue(
            hochButton.waitForExistence(timeout: 3),
            "ImportancePicker should show 'Hoch' button"
        )
        hochButton.tap()
        sleep(1)

        // Picker should dismiss and badge should reflect the change
        let picker = app.otherElements["importance-picker"]
        XCTAssertFalse(picker.exists, "ImportancePicker should dismiss after selection")
    }

    // MARK: - Feature A: Tappable Category Badge

    /// Test: Category badge exists in BacklogRow and is tappable
    /// EXPECTED TO FAIL: category-badge identifier doesn't exist yet
    func testCategoryBadgeExists() throws {
        navigateToBacklog()

        let categoryBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'category-badge-'")
        ).firstMatch

        XCTAssertTrue(
            categoryBadge.waitForExistence(timeout: 5),
            "Backlog should show tappable category badges on tasks"
        )
    }

    /// Test: Tapping category badge opens CategoryPicker
    /// EXPECTED TO FAIL: CategoryPicker doesn't exist yet
    func testCategoryBadgeTapOpensPicker() throws {
        navigateToBacklog()

        let categoryBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'category-badge-'")
        ).firstMatch

        guard categoryBadge.waitForExistence(timeout: 5) else {
            XCTFail("Category badge not found")
            return
        }

        categoryBadge.tap()
        sleep(1)

        let picker = app.otherElements["category-picker"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            "CategoryPicker should open after tapping category badge"
        )
    }

    /// Test: Selecting a category in CategoryPicker updates the badge
    /// EXPECTED TO FAIL: CategoryPicker doesn't exist yet
    func testCategoryPickerSelectionUpdates() throws {
        navigateToBacklog()

        let categoryBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'category-badge-'")
        ).firstMatch

        guard categoryBadge.waitForExistence(timeout: 5) else {
            XCTFail("Category badge not found")
            return
        }

        categoryBadge.tap()
        sleep(1)

        // Tap "Recharge" button in the picker
        let rechargeButton = app.buttons["category-recharge"]
        XCTAssertTrue(
            rechargeButton.waitForExistence(timeout: 3),
            "CategoryPicker should show 'Recharge' button"
        )
        rechargeButton.tap()
        sleep(1)

        // Picker should dismiss
        let picker = app.otherElements["category-picker"]
        XCTAssertFalse(picker.exists, "CategoryPicker should dismiss after selection")
    }

    // MARK: - Feature B: View Mode Callback Tests (TDD RED - Bug Reproduction)

    /// Test: Importance badge tap works in TBD view mode
    /// TDD RED: This test will FAIL because callbacks are missing in tbdView
    func testImportanceBadgeTapWorksInTbdViewMode() throws {
        navigateToBacklog()

        // Switch to TBD view mode
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(viewModeSwitcher.waitForExistence(timeout: 5), "View mode switcher should exist")
        viewModeSwitcher.tap()
        sleep(1)

        // Select TBD from menu
        let tbdOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'TBD'")).firstMatch
        if tbdOption.waitForExistence(timeout: 3) {
            tbdOption.tap()
            sleep(2)
        } else {
            // Fallback: try staticTexts
            let tbdText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'TBD'")).firstMatch
            guard tbdText.waitForExistence(timeout: 3) else {
                XCTFail("TBD option not found in view mode menu")
                return
            }
            tbdText.tap()
            sleep(2)
        }

        // Screenshot: TBD view mode
        let screenshot1 = XCTAttachment(screenshot: app.screenshot())
        screenshot1.name = "TBD_ViewMode_Before_Tap"
        screenshot1.lifetime = .keepAlways
        add(screenshot1)

        // Find importance badge in TBD view
        let importanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importance-badge-'")
        ).firstMatch

        guard importanceBadge.waitForExistence(timeout: 5) else {
            // No TBD tasks exist - this is acceptable, skip test
            XCTSkip("No TBD tasks available to test importance badge in TBD view mode")
            return
        }

        importanceBadge.tap()
        sleep(2)

        // Screenshot: After tap
        let screenshot2 = XCTAttachment(screenshot: app.screenshot())
        screenshot2.name = "TBD_ViewMode_After_Tap"
        screenshot2.lifetime = .keepAlways
        add(screenshot2)

        // ImportancePicker should appear - THIS WILL FAIL because callback is missing
        let picker = app.otherElements["importance-picker"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            "ImportancePicker should open after tapping importance badge in TBD view mode"
        )
    }

    /// Test: Category badge tap works in Category view mode
    /// TDD RED: This test will FAIL because callbacks are missing in categoryView
    func testCategoryBadgeTapWorksInCategoryViewMode() throws {
        navigateToBacklog()

        // Switch to Category view mode
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(viewModeSwitcher.waitForExistence(timeout: 5), "View mode switcher should exist")
        viewModeSwitcher.tap()
        sleep(1)

        // Select Kategorie from menu
        let categoryOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Kategorie'")).firstMatch
        if categoryOption.waitForExistence(timeout: 3) {
            categoryOption.tap()
            sleep(2)
        } else {
            let categoryText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Kategorie'")).firstMatch
            guard categoryText.waitForExistence(timeout: 3) else {
                XCTFail("Kategorie option not found in view mode menu")
                return
            }
            categoryText.tap()
            sleep(2)
        }

        // Screenshot: Category view mode
        let screenshot1 = XCTAttachment(screenshot: app.screenshot())
        screenshot1.name = "Category_ViewMode_Before_Tap"
        screenshot1.lifetime = .keepAlways
        add(screenshot1)

        // Find category badge
        let categoryBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'category-badge-'")
        ).firstMatch

        guard categoryBadge.waitForExistence(timeout: 5) else {
            XCTSkip("No tasks available to test category badge in Category view mode")
            return
        }

        categoryBadge.tap()
        sleep(2)

        // Screenshot: After tap
        let screenshot2 = XCTAttachment(screenshot: app.screenshot())
        screenshot2.name = "Category_ViewMode_After_Tap"
        screenshot2.lifetime = .keepAlways
        add(screenshot2)

        // CategoryPicker should appear - THIS WILL FAIL because callback is missing
        let picker = app.otherElements["category-picker"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            "CategoryPicker should open after tapping category badge in Category view mode"
        )
    }

    /// Test: Context menu "Bearbeiten" works in Duration view mode
    /// TDD RED: This test will FAIL because onEditTap callback is missing in durationView
    func testContextMenuEditWorksInDurationViewMode() throws {
        navigateToBacklog()

        // Switch to Duration view mode
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(viewModeSwitcher.waitForExistence(timeout: 5), "View mode switcher should exist")
        viewModeSwitcher.tap()
        sleep(1)

        // Select Dauer from menu
        let durationOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Dauer'")).firstMatch
        if durationOption.waitForExistence(timeout: 3) {
            durationOption.tap()
            sleep(2)
        } else {
            let durationText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Dauer'")).firstMatch
            guard durationText.waitForExistence(timeout: 3) else {
                XCTFail("Dauer option not found in view mode menu")
                return
            }
            durationText.tap()
            sleep(2)
        }

        // Screenshot: Duration view mode
        let screenshot1 = XCTAttachment(screenshot: app.screenshot())
        screenshot1.name = "Duration_ViewMode_Before_LongPress"
        screenshot1.lifetime = .keepAlways
        add(screenshot1)

        // Find importance badge to use as anchor for long press
        let importanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importance-badge-'")
        ).firstMatch

        guard importanceBadge.waitForExistence(timeout: 5) else {
            XCTSkip("No tasks available to test context menu in Duration view mode")
            return
        }

        // Long press on title area (offset from badge)
        let titleArea = importanceBadge.coordinate(withNormalizedOffset: CGVector(dx: 4.0, dy: 0.5))
        titleArea.press(forDuration: 1.5)
        sleep(1)

        // Screenshot: Context menu
        let screenshot2 = XCTAttachment(screenshot: app.screenshot())
        screenshot2.name = "Duration_ViewMode_ContextMenu"
        screenshot2.lifetime = .keepAlways
        add(screenshot2)

        // Find and tap Bearbeiten
        let editAction = app.buttons["Bearbeiten"]
        guard editAction.waitForExistence(timeout: 5) else {
            XCTFail("Context menu 'Bearbeiten' not found in Duration view mode")
            return
        }

        editAction.tap()
        sleep(2)

        // Screenshot: After tapping Bearbeiten
        let screenshot3 = XCTAttachment(screenshot: app.screenshot())
        screenshot3.name = "Duration_ViewMode_After_Bearbeiten"
        screenshot3.lifetime = .keepAlways
        add(screenshot3)

        // TaskFormSheet should open - THIS WILL FAIL because onEditTap callback is missing
        let titleField = app.textFields["taskTitle"]
        XCTAssertTrue(
            titleField.waitForExistence(timeout: 3),
            "TaskFormSheet should open from context menu in Duration view mode"
        )
    }

    // MARK: - Feature C: Context Menu (Long-Press)

    /// Find a backlog row's non-interactive area (title text) by using
    /// the importance badge as anchor, then offsetting to the right.
    /// This avoids pressing on Button elements or the NextUp section.
    private func longPressBacklogRow() -> Bool {
        let importanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importance-badge-'")
        ).firstMatch

        guard importanceBadge.waitForExistence(timeout: 5) else {
            return false
        }

        // Offset to the right of the badge to land on the title text area
        // (non-interactive, so the long press triggers the parent's context menu)
        let titleArea = importanceBadge.coordinate(
            withNormalizedOffset: CGVector(dx: 4.0, dy: 0.5)
        )
        titleArea.press(forDuration: 1.5)
        return true
    }

    /// Test: Long-press on BacklogRow shows context menu with "Bearbeiten"
    /// EXPECTED TO FAIL: Context menu doesn't exist yet
    func testLongPressShowsContextMenu() throws {
        navigateToBacklog()

        // Long-press on a backlog row's title area (not a button, not NextUp section)
        guard longPressBacklogRow() else {
            XCTFail("No backlog task with importance badge found")
            return
        }

        // Context menu items are found by their label text in SwiftUI
        let editAction = app.buttons["Bearbeiten"]
        XCTAssertTrue(
            editAction.waitForExistence(timeout: 5),
            "Context menu should show 'Bearbeiten' option after long-press"
        )
    }

    /// Test: Context menu "Bearbeiten" opens TaskFormSheet directly
    func testContextMenuEditOpensFormSheet() throws {
        navigateToBacklog()

        guard longPressBacklogRow() else {
            XCTFail("No backlog task found")
            return
        }

        let editAction = app.buttons["Bearbeiten"]
        guard editAction.waitForExistence(timeout: 5) else {
            XCTFail("Context menu 'Bearbeiten' not found")
            return
        }

        editAction.tap()
        sleep(1)

        // TaskFormSheet should open directly (not TaskDetailSheet)
        let titleField = app.textFields["taskTitle"]
        XCTAssertTrue(
            titleField.waitForExistence(timeout: 3),
            "TaskFormSheet should open directly from context menu (skip detail sheet)"
        )
    }
}
