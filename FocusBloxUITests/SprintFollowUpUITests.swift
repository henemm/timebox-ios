import XCTest

/// UI Tests for FEATURE_024: Sprint Follow-up Action
///
/// Tests verify that the Follow-up button exists in the Sprint view
/// and opens the TaskFormSheet for editing the follow-up copy.
///
/// EXPECTED TO FAIL (TDD RED): Follow-up button doesn't exist yet.
final class SprintFollowUpUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    /// TDD RED: Follow-up button should exist alongside Skip and Complete
    /// Bricht wenn: FocusLiveView — Button mit identifier "taskFollowUpButton" entfernt
    func testFollowUpButtonExists() throws {
        // The existing skip/complete buttons use these identifiers
        let skipButton = app.buttons["taskSkipButton"]
        let completeButton = app.buttons["taskCompleteButton"]

        // Verify sprint view is showing (skip + complete must exist)
        let sprintVisible = skipButton.waitForExistence(timeout: 10)
            || completeButton.waitForExistence(timeout: 3)

        // Even if sprint isn't visible (no active block), the follow-up button
        // should exist when a task is current — fail either way in RED phase
        let followUpButton = app.buttons["taskFollowUpButton"]
        XCTAssertTrue(
            followUpButton.waitForExistence(timeout: 5),
            "Follow-up button should exist in sprint task view (alongside Skip and Complete)"
        )
    }

    /// TDD RED: Follow-up button should show correct label text
    /// Bricht wenn: FocusLiveView — Button-Label geaendert
    func testFollowUpButtonHasCorrectLabel() throws {
        let followUpButton = app.buttons["taskFollowUpButton"]
        guard followUpButton.waitForExistence(timeout: 10) else {
            XCTFail("Follow-up button should exist")
            return
        }

        XCTAssertTrue(
            followUpButton.label.contains("Follow-up"),
            "Button should contain 'Follow-up' label, got: '\(followUpButton.label)'"
        )
    }

    /// TDD RED: Tapping Follow-up should open TaskFormSheet for editing
    /// Bricht wenn: FocusLiveView — Follow-up handler oeffnet kein Sheet
    func testFollowUpOpensEditSheet() throws {
        let followUpButton = app.buttons["taskFollowUpButton"]
        guard followUpButton.waitForExistence(timeout: 10) else {
            XCTFail("Follow-up button should exist")
            return
        }

        followUpButton.tap()

        // TaskFormSheet should appear — look for the save button that exists in the form
        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(
            saveButton.waitForExistence(timeout: 5),
            "TaskFormSheet should appear after tapping Follow-up"
        )
    }
}
