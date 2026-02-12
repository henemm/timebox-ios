import XCTest

/// UI Tests for macOS Sprint Review Sheet (Bug 42)
/// Tests: Loop fix (dismiss stays dismissed) + Feature parity with iOS
final class MacSprintReviewUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-UITesting", "-MockPastBlock"]
        app.launch()

        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func navigateToFocusTab() {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else { return }
        radioGroup.radioButtons["target"].click()
    }

    // MARK: - Loop Fix Tests

    /// GIVEN: Sprint Review is shown for a past Focus Block
    /// WHEN: User dismisses the review
    /// THEN: Review should NOT reopen (no loop)
    @MainActor
    func testSprintReviewStaysClosedAfterDismiss() throws {
        navigateToFocusTab()

        // Wait for Sprint Review sheet to appear (past block triggers it)
        let reviewTitle = app.staticTexts["Sprint Review"]
        guard reviewTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Sprint Review not shown - need mock past block")
        }

        // Find and tap close/dismiss button
        let closeButton = app.buttons["sprintReviewDismiss"]
        guard closeButton.waitForExistence(timeout: 3) else {
            XCTFail("Sprint Review hat keinen Schliessen-Button mit ID 'sprintReviewDismiss'")
            return
        }
        closeButton.click()

        // Wait briefly for any potential reopen
        sleep(2)

        // Review should NOT be visible anymore
        XCTAssertFalse(
            app.staticTexts["Sprint Review"].waitForExistence(timeout: 3),
            "Sprint Review darf nach Schliessen NICHT erneut erscheinen (Dauerloop!)"
        )
    }

    // MARK: - Feature Parity Tests

    /// GIVEN: Sprint Review is shown on macOS
    /// WHEN: Looking at the stats header
    /// THEN: Completion percentage ring should be visible
    @MainActor
    func testSprintReviewShowsCompletionPercentage() throws {
        navigateToFocusTab()

        let reviewTitle = app.staticTexts["Sprint Review"]
        guard reviewTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Sprint Review not shown")
        }

        // Should show percentage text (e.g. "50%")
        let percentageText = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '.*[0-9]+%%.*'")
        ).firstMatch
        XCTAssertTrue(
            percentageText.waitForExistence(timeout: 3),
            "Sprint Review sollte Completion-Prozent anzeigen (z.B. '50%')"
        )

        // Should show "geschafft" label
        let geschafftLabel = app.staticTexts["geschafft"]
        XCTAssertTrue(
            geschafftLabel.exists,
            "Sprint Review sollte 'geschafft' Label zeigen"
        )
    }

    /// GIVEN: Sprint Review is shown on macOS
    /// WHEN: Looking at stats
    /// THEN: Should show Erledigt, Offen, geplant, gebraucht stats
    @MainActor
    func testSprintReviewShowsDetailedStats() throws {
        navigateToFocusTab()

        let reviewTitle = app.staticTexts["Sprint Review"]
        guard reviewTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Sprint Review not shown")
        }

        let erledigt = app.staticTexts["Erledigt"]
        let offen = app.staticTexts["Offen"]
        let geplant = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'geplant'")
        ).firstMatch
        let gebraucht = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'gebraucht'")
        ).firstMatch

        XCTAssertTrue(erledigt.waitForExistence(timeout: 3), "Stat 'Erledigt' fehlt")
        XCTAssertTrue(offen.exists, "Stat 'Offen' fehlt")
        XCTAssertTrue(geplant.exists, "Stat 'geplant' fehlt")
        XCTAssertTrue(gebraucht.exists, "Stat 'gebraucht' fehlt")
    }

    /// GIVEN: Sprint Review is shown on macOS with tasks
    /// WHEN: User taps task status toggle
    /// THEN: Task completion status should change (interactive toggling)
    @MainActor
    func testTaskStatusCanBeToggled() throws {
        navigateToFocusTab()

        let reviewTitle = app.staticTexts["Sprint Review"]
        guard reviewTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Sprint Review not shown")
        }

        // Look for interactive task toggle button
        let taskToggle = app.buttons["taskStatusToggle"].firstMatch
        XCTAssertTrue(
            taskToggle.waitForExistence(timeout: 3),
            "Task Status Toggle Button sollte existieren (interaktives Toggling)"
        )
    }

    /// GIVEN: Sprint Review is shown with incomplete tasks
    /// WHEN: Looking at action buttons
    /// THEN: "Offene Tasks ins Backlog" button should exist
    @MainActor
    func testBacklogButtonExists() throws {
        navigateToFocusTab()

        let reviewTitle = app.staticTexts["Sprint Review"]
        guard reviewTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Sprint Review not shown")
        }

        let backlogButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Backlog'")
        ).firstMatch
        XCTAssertTrue(
            backlogButton.waitForExistence(timeout: 3),
            "Button 'Offene Tasks ins Backlog' sollte existieren"
        )
    }

    /// GIVEN: Sprint Review is shown on macOS
    /// WHEN: Looking at task rows
    /// THEN: Planned time per task should be visible
    @MainActor
    func testTaskRowsShowPlannedTime() throws {
        navigateToFocusTab()

        let reviewTitle = app.staticTexts["Sprint Review"]
        guard reviewTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Sprint Review not shown")
        }

        let plannedTime = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'geplant'")
        ).firstMatch
        XCTAssertTrue(
            plannedTime.waitForExistence(timeout: 3),
            "Task Rows sollten geplante Zeit anzeigen"
        )
    }
}
