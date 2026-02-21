import XCTest

/// UI Tests for Recurring Task Template (Mutter/Kind) architecture.
/// Verifies that "Wiederkehrend" view shows ONLY templates (Mutterinstanzen),
/// not child instances. This catches the bug where templates + children
/// were both visible, causing duplicate entries.
///
/// EXPECTED TO FAIL (RED): Seed data doesn't include recurring templates yet.
final class RecurringTemplateUITests: XCTestCase {
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

    // MARK: - Helpers

    /// Navigate to Backlog tab, then open the Wiederkehrend view mode.
    private func navigateToRecurring() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        guard backlogTab.waitForExistence(timeout: 5) else {
            XCTFail("Backlog tab not found")
            return
        }
        backlogTab.tap()
        sleep(1)

        // Open the view mode switcher menu
        let viewModeSwitcher = app.buttons["viewModeSwitcher"].firstMatch
        guard viewModeSwitcher.waitForExistence(timeout: 3) else {
            XCTFail("View mode switcher not found")
            return
        }
        viewModeSwitcher.tap()
        sleep(1)

        // Select "Wiederkehrend" from the context menu.
        // The menu item has the icon identifier, not "Wiederkehrend" as label.
        // Use the CollectionView cell button which is the menu item.
        let menuItem = app.collectionViews.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Wiederkehrend")
        ).firstMatch
        guard menuItem.waitForExistence(timeout: 3) else {
            XCTFail("Wiederkehrend menu option not found")
            return
        }
        menuItem.tap()
        sleep(1)
    }

    // MARK: - Template Visibility Tests

    /// Bricht wenn: seedUITestData() keine Recurring Templates erstellt
    /// oder BacklogView.recurringTasks Filter nicht nach isTemplate filtert
    func test_wiederkehrend_showsTemplates() throws {
        navigateToRecurring()

        // Templates should be visible
        let template1 = app.staticTexts["Taeglich lesen"]
        XCTAssertTrue(
            template1.waitForExistence(timeout: 5),
            "Template 'Taeglich lesen' should be visible in Wiederkehrend view"
        )

        let template2 = app.staticTexts["Wochenreview"]
        XCTAssertTrue(
            template2.waitForExistence(timeout: 3),
            "Template 'Wochenreview' should be visible in Wiederkehrend view"
        )
    }

    /// Bricht wenn: BacklogView.recurringTasks zeigt auch Kinder (isTemplate == false)
    /// Dies war der Bug: Templates UND Kinder wurden angezeigt → Duplikate
    func test_wiederkehrend_doesNotShowDuplicates() throws {
        navigateToRecurring()

        // Wait for content to load
        let template1 = app.staticTexts["Taeglich lesen"]
        guard template1.waitForExistence(timeout: 5) else {
            XCTFail("No recurring templates found — seed data missing?")
            return
        }

        // Count how many times each title appears.
        // If children are also shown, we'd see duplicates.
        let taeglich = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Taeglich lesen")
        )
        XCTAssertEqual(
            taeglich.count, 1,
            "Only ONE 'Taeglich lesen' entry should be visible (template only, no child duplicate)"
        )

        let wochenreview = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Wochenreview")
        )
        XCTAssertEqual(
            wochenreview.count, 1,
            "Only ONE 'Wochenreview' entry should be visible (template only, no child duplicate)"
        )
    }

    /// Bricht wenn: Kinder mit dueDate in Wiederkehrend angezeigt werden statt nur in Backlog
    func test_wiederkehrend_childNotVisibleInRecurringView() throws {
        navigateToRecurring()

        // Wait for view to settle
        sleep(2)

        // The badge overflow task is a non-template recurring task — it should NOT appear
        // in "Wiederkehrend" because it's not a template
        let nonTemplate = app.staticTexts["Badge Overflow Demo"]
        XCTAssertFalse(
            nonTemplate.exists,
            "Non-template recurring tasks should NOT appear in Wiederkehrend view"
        )
    }
}
