import XCTest

/// Safety-net UI Tests for TD-02 DueDateBadge extraction.
///
/// TDD RED: These tests expect `dueDateBadge_*` accessibility identifiers
/// which do NOT exist in the current inline code (BacklogRow lines 194-202).
/// After extracting to shared DueDateBadge view with proper identifiers,
/// these tests will turn GREEN.
///
/// Mock data: backlogTask1 has dueDate = Date() (today), so "Heute" should appear.
final class DueDateBadgeExtractionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Navigate to Backlog tab
    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10), "Backlog tab should exist")
        backlogTab.tap()

        // Wait for data to load
        let badge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 8), "Backlog tasks should load")
    }

    // MARK: - Test 1: DueDateBadge has accessibility identifier

    /// TDD RED: BacklogRow's due date display has NO accessibilityIdentifier yet.
    /// After extraction to DueDateBadge, it will have "dueDateBadge_<taskId>".
    func testDueDateBadgeHasAccessibilityIdentifier() throws {
        navigateToBacklog()

        // backlogTask1 has dueDate = Date() (today)
        let dueDateBadge = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'dueDateBadge_'")
        ).firstMatch

        XCTAssertTrue(
            dueDateBadge.waitForExistence(timeout: 5),
            "Due date badge should have identifier 'dueDateBadge_*' — currently missing (TDD RED)"
        )
    }

    // MARK: - Test 2: DueDateBadge shows "Heute" for today's date

    /// TDD RED: After extraction, DueDateBadge should show "Heute" text.
    func testDueDateBadgeShowsHeuteForToday() throws {
        navigateToBacklog()

        let dueDateBadge = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'dueDateBadge_'")
        ).firstMatch

        guard dueDateBadge.waitForExistence(timeout: 5) else {
            XCTFail("Due date badge not found — identifier missing (TDD RED)")
            return
        }

        // backlogTask1.dueDate = Date() → should display "Heute"
        XCTAssertTrue(
            dueDateBadge.label.contains("Heute"),
            "Due date badge for today's date should contain 'Heute', got: '\(dueDateBadge.label)'"
        )
    }
}
