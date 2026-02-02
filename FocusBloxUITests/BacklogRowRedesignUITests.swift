import XCTest

/// UI Tests for BacklogRow Redesign
///
/// Tests against mock data seeded in FocusBloxApp.seedUITestData():
/// - backlogTask1: importance=2, urgency="urgent", tags=["work","urgent"], taskType="deep_work"
/// - backlogTask2: importance=1, urgency="not_urgent", taskType="shallow_work"
///
/// Verifies:
/// - Importance badge (exclamationmark.X symbols) in metadata row
/// - Urgency badge (flame.fill) when urgent
/// - Next Up button as separate button (not in menu)
/// - Category badge with icon
/// - Actions menu (ellipsis)
/// - No TBD badge (only italic title)
/// - Glass card container
final class BacklogRowRedesignUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Navigate to Backlog tab and switch to Liste view
    private func navigateToBacklogList() {
        // App uses custom floating tab bar with accessibility identifier "tab-backlog"
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10), "Backlog tab should exist")
        backlogTab.tap()

        // Wait for tab switch
        sleep(1)

        // Switch to Liste view (BacklogRow only visible in Liste mode)
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        guard viewModeSwitcher.waitForExistence(timeout: 5) else {
            XCTFail("viewModeSwitcher should exist")
            return
        }
        viewModeSwitcher.tap()
        sleep(1)

        // Select "Liste" - use firstMatch to avoid "multiple elements" error
        let listeOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Liste'")
        ).firstMatch

        guard listeOption.waitForExistence(timeout: 3) else {
            XCTFail("Liste option should exist in view mode picker")
            return
        }
        listeOption.tap()

        // Wait for data to load
        sleep(2)
    }

    // MARK: - Test 1: BacklogRow Shows Tasks

    /// Test: Backlog Liste shows task elements
    /// Mock data: backlogTask1, backlogTask2 both have isNextUp=false
    func testBacklogRowShowsTasks() throws {
        navigateToBacklogList()

        // Screenshot for documentation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "1_BacklogRowTasks"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Task title should exist (proves BacklogRow is rendered)
        let taskTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch

        XCTAssertTrue(
            taskTitle.waitForExistence(timeout: 5),
            "BacklogRow should show task titles with identifier 'taskTitle_*'"
        )
    }

    // MARK: - Test 2: Importance Badge Exists and is Tappable

    /// Test: Importance badge (exclamationmark symbols) exists and is tappable (cycles importance)
    /// Mock data: backlogTask1 has importance=2, backlogTask2 has importance=1
    func testImportanceBadgeExistsAndIsTappable() throws {
        navigateToBacklogList()

        // Screenshot for documentation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "2_ImportanceBadge"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Importance badge is now a Button (tappable to cycle)
        let importanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).firstMatch

        XCTAssertTrue(
            importanceBadge.waitForExistence(timeout: 5),
            "Importance badge with identifier 'importanceBadge_*' should exist"
        )

        // Verify badge is tappable
        XCTAssertTrue(
            importanceBadge.isHittable,
            "Importance badge should be tappable (isHittable)"
        )
    }

    // MARK: - Test 3: Urgency Badge Exists and is Tappable

    /// Test: Urgency badge (flame) exists and is tappable (toggles urgency)
    /// Now always visible - filled flame when urgent, outline when not
    func testUrgencyBadgeExistsAndIsTappable() throws {
        navigateToBacklogList()

        // Screenshot for documentation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "3_UrgencyBadge"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Urgency badge is now a Button (tappable to toggle)
        let urgencyBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'urgencyBadge_'")
        ).firstMatch

        XCTAssertTrue(
            urgencyBadge.waitForExistence(timeout: 5),
            "Urgency badge with identifier 'urgencyBadge_*' should exist"
        )

        // Verify badge is tappable
        XCTAssertTrue(
            urgencyBadge.isHittable,
            "Urgency badge should be tappable (isHittable)"
        )
    }

    // MARK: - Test 4: Next Up Button Exists and is Tappable

    /// Test: Next Up button (arrow.up.circle) exists as standalone button and is tappable
    /// Mock data: Both backlog tasks have isNextUp=false, so button should show
    func testNextUpButtonExistsAndIsTappable() throws {
        navigateToBacklogList()

        // Screenshot for documentation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "4_NextUpButton"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Next Up button should have accessibilityIdentifier "nextUpButton_<id>"
        let nextUpButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'nextUpButton_'")
        ).firstMatch

        XCTAssertTrue(
            nextUpButton.waitForExistence(timeout: 5),
            "Next Up button with identifier 'nextUpButton_*' should exist"
        )

        // Verify button is tappable
        XCTAssertTrue(
            nextUpButton.isHittable,
            "Next Up button should be tappable (isHittable)"
        )
    }

    // MARK: - Test 5: Actions Menu Exists and is Tappable

    /// Test: Actions menu (ellipsis) exists in right column and is tappable
    func testActionsMenuExistsAndIsTappable() throws {
        navigateToBacklogList()

        // Screenshot for documentation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "5_ActionsMenu"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Actions menu should have accessibilityIdentifier "actionsMenu_<id>"
        let actionsMenu = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'actionsMenu_'")
        ).firstMatch

        XCTAssertTrue(
            actionsMenu.waitForExistence(timeout: 5),
            "Actions menu with identifier 'actionsMenu_*' should exist"
        )

        // Verify menu is tappable
        XCTAssertTrue(
            actionsMenu.isHittable,
            "Actions menu should be tappable (isHittable)"
        )
    }

    // MARK: - Test 6: Category Badge Exists and is Tappable

    /// Test: Category badge with icon exists in metadata row and is tappable
    /// Mock data: backlogTask1 has taskType="deep_work", backlogTask2 has taskType="shallow_work"
    func testCategoryBadgeExistsAndIsTappable() throws {
        navigateToBacklogList()

        // Screenshot for documentation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "6_CategoryBadge"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Category badge should have accessibilityIdentifier "categoryBadge_<id>"
        let categoryBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'categoryBadge_'")
        ).firstMatch

        XCTAssertTrue(
            categoryBadge.waitForExistence(timeout: 5),
            "Category badge with identifier 'categoryBadge_*' should exist"
        )

        // Verify badge is tappable
        XCTAssertTrue(
            categoryBadge.isHittable,
            "Category badge should be tappable (isHittable)"
        )
    }

    // MARK: - Test 7: Duration Badge Exists and is Tappable

    /// Test: Duration badge exists in metadata row and is tappable
    /// Mock data: backlogTask1 has estimatedDuration=25, backlogTask2 has estimatedDuration=15
    func testDurationBadgeExistsAndIsTappable() throws {
        navigateToBacklogList()

        // Screenshot for documentation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "7_DurationBadge"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Duration badge should have accessibilityIdentifier "durationBadge_<id>"
        let durationBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        ).firstMatch

        XCTAssertTrue(
            durationBadge.waitForExistence(timeout: 5),
            "Duration badge with identifier 'durationBadge_*' should exist"
        )

        // Verify badge is tappable
        XCTAssertTrue(
            durationBadge.isHittable,
            "Duration badge should be tappable (isHittable)"
        )
    }

    // MARK: - Test 8: No TBD Badge

    /// Test: TBD badge does NOT exist (removed from design)
    /// Only italic title should indicate TBD status
    func testNoTbdBadge() throws {
        navigateToBacklogList()

        // Screenshot for documentation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "8_NoTbdBadge"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // TBD badge should NOT exist
        let tbdBadge = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'tbdBadge_'")
        ).firstMatch

        // Give UI time to settle
        sleep(1)

        XCTAssertFalse(
            tbdBadge.exists,
            "TBD badge should NOT exist - only italic title indicates TBD status"
        )
    }

    // MARK: - Test 9: Task Title Exists

    /// Test: Task title is displayed
    /// Mock data: "Backlog Task 1", "Backlog Task 2"
    func testTaskTitleExists() throws {
        navigateToBacklogList()

        // Screenshot for documentation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "9_TaskTitle"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Task title should have accessibilityIdentifier "taskTitle_<id>"
        let taskTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch

        XCTAssertTrue(
            taskTitle.waitForExistence(timeout: 5),
            "Task title with identifier 'taskTitle_*' should exist"
        )
    }

    // MARK: - Test 10: Actions Menu Opens

    /// Test: Tapping actions menu opens menu with Edit and Delete options
    func testActionsMenuOpens() throws {
        navigateToBacklogList()

        // Find and tap actions menu
        let actionsMenu = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'actionsMenu_'")
        ).firstMatch

        guard actionsMenu.waitForExistence(timeout: 5) else {
            XCTFail("Actions menu should exist")
            return
        }

        actionsMenu.tap()
        sleep(1)

        // Screenshot of open menu
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "10_ActionsMenuOpen"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Menu should show "Bearbeiten" option
        let editOption = app.buttons["Bearbeiten"]
        XCTAssertTrue(
            editOption.waitForExistence(timeout: 3),
            "Actions menu should contain 'Bearbeiten' option"
        )

        // Menu should show "Löschen" option
        let deleteOption = app.buttons["Löschen"]
        XCTAssertTrue(
            deleteOption.exists,
            "Actions menu should contain 'Löschen' option"
        )
    }
}
