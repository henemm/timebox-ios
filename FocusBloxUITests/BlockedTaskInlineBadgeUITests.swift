import XCTest

/// BUG_122: Blocked tasks must support inline badge editing (importance, urgency, category, duration).
/// Currently blockedRow() passes no badge callbacks — badges render but taps do nothing.
///
/// TDD RED: All tests should FAIL before implementation.
/// Bricht wenn: BacklogView.swift blockedRow() missing onImportanceCycle/onUrgencyToggle/onCategoryTap/onDurationTap
@MainActor
final class BlockedTaskInlineBadgeUITests: XCTestCase {
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

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab must exist")
        backlogTab.tap()
    }

    /// Find a blocked mock task and return its task ID for badge identification.
    /// Mock blocked tasks contain "Abhaengig" in their title.
    /// Returns (taskTitleElement, taskID) or nil if not found.
    private func findBlockedTaskInfo() -> (element: XCUIElement, id: String)? {
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch

        // Try without scrolling first, then scroll
        for attempt in 0..<6 {
            if attempt > 0 { list.swipeUp() }

            let titles = app.staticTexts.matching(predicate)
            for i in 0..<titles.count {
                let element = titles.element(boundBy: i)
                guard element.isHittable else { continue }
                let label = element.label
                if label.contains("Abhaengig") {
                    // Extract task ID from accessibility identifier: "taskTitle_<uuid>"
                    let identifier = element.identifier
                    let taskID = String(identifier.dropFirst("taskTitle_".count))
                    return (element, taskID)
                }
            }
        }
        return nil
    }

    // MARK: - Importance Badge

    /// GIVEN: A blocked task in the backlog with importance = 2
    /// WHEN: User taps the importance badge
    /// THEN: Importance cycles to next value (badge label changes)
    ///
    /// Bricht wenn: BacklogView.swift:1114 blockedRow() does not pass onImportanceCycle
    func test_blockedTask_importanceBadgeTap_cyclesValue() throws {
        navigateToBacklog()

        guard let info = findBlockedTaskInfo() else {
            throw XCTSkip("No blocked mock task found — ensure mock data includes blocked tasks with 'Abhaengig' title")
        }

        let importanceBadge = app.buttons["importanceBadge_\(info.id)"]
        XCTAssertTrue(importanceBadge.waitForExistence(timeout: 3),
                      "Importance badge must exist on blocked task")

        // Capture label before tap
        let labelBefore = importanceBadge.label

        // Tap to cycle importance
        importanceBadge.tap()

        // Wait briefly for UI update
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", labelBefore),
            object: importanceBadge
        )
        let result = XCTWaiter().wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed,
                       "Importance badge label should change after tap (was: '\(labelBefore)')")
    }

    // MARK: - Urgency Badge

    /// GIVEN: A blocked task in the backlog with urgency = "not_urgent"
    /// WHEN: User taps the urgency badge
    /// THEN: Urgency toggles to next value (badge label changes)
    ///
    /// Bricht wenn: BacklogView.swift:1114 blockedRow() does not pass onUrgencyToggle
    func test_blockedTask_urgencyBadgeTap_togglesValue() throws {
        navigateToBacklog()

        guard let info = findBlockedTaskInfo() else {
            throw XCTSkip("No blocked mock task found")
        }

        let urgencyBadge = app.buttons["urgencyBadge_\(info.id)"]
        XCTAssertTrue(urgencyBadge.waitForExistence(timeout: 3),
                      "Urgency badge must exist on blocked task")

        let labelBefore = urgencyBadge.label

        urgencyBadge.tap()

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", labelBefore),
            object: urgencyBadge
        )
        let result = XCTWaiter().wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed,
                       "Urgency badge label should change after tap (was: '\(labelBefore)')")
    }

    // MARK: - Category Badge

    /// GIVEN: A blocked task in the backlog
    /// WHEN: User taps the category badge
    /// THEN: Category picker sheet opens
    ///
    /// Bricht wenn: BacklogView.swift:1114 blockedRow() does not pass onCategoryTap
    func test_blockedTask_categoryBadgeTap_opensSheet() throws {
        navigateToBacklog()

        guard let info = findBlockedTaskInfo() else {
            throw XCTSkip("No blocked mock task found")
        }

        let categoryBadge = app.buttons["categoryBadge_\(info.id)"]
        XCTAssertTrue(categoryBadge.waitForExistence(timeout: 3),
                      "Category badge must exist on blocked task")

        categoryBadge.tap()

        // CategoryPicker has accessibilityIdentifier "category-picker"
        let picker = app.otherElements["category-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3),
                      "Category picker sheet should open when tapping category badge on blocked task")
    }

    // MARK: - Duration Badge

    /// GIVEN: A blocked task in the backlog
    /// WHEN: User taps the duration badge
    /// THEN: Duration picker sheet opens
    ///
    /// Bricht wenn: BacklogView.swift:1114 blockedRow() does not pass onDurationTap
    func test_blockedTask_durationBadgeTap_opensSheet() throws {
        navigateToBacklog()

        guard let info = findBlockedTaskInfo() else {
            throw XCTSkip("No blocked mock task found")
        }

        let durationBadge = app.buttons["durationBadge_\(info.id)"]
        XCTAssertTrue(durationBadge.waitForExistence(timeout: 3),
                      "Duration badge must exist on blocked task")

        durationBadge.tap()

        // DurationPicker appears as a sheet with "Dauer waehlen" headline
        let durationTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertTrue(durationTitle.waitForExistence(timeout: 3),
                      "Duration picker sheet should open when tapping duration badge on blocked task")
    }

    // MARK: - Checkbox Regression Guard

    /// GIVEN: A blocked task in the backlog
    /// WHEN: Blocked task's checkbox is visible
    /// THEN: Checkbox shows lock icon and is disabled (cannot be tapped to complete)
    ///
    /// Regression guard: Ensures fix does NOT accidentally enable completion on blocked tasks.
    /// Bricht wenn: blockedRow() starts passing onComplete callback
    func test_blockedTask_checkboxRemainsDisabled() throws {
        navigateToBacklog()

        guard let info = findBlockedTaskInfo() else {
            throw XCTSkip("No blocked mock task found")
        }

        let checkbox = app.buttons["completeButton_\(info.id)"]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 3),
                      "Checkbox must exist on blocked task")

        // Verify the checkbox shows the "Blockiert" label (lock icon)
        XCTAssertEqual(checkbox.label, "Blockiert",
                       "Blocked task checkbox should show 'Blockiert' label (lock icon)")

        // Verify it's disabled
        XCTAssertFalse(checkbox.isEnabled,
                       "Blocked task checkbox must remain disabled — blocked tasks cannot be completed")
    }
}
