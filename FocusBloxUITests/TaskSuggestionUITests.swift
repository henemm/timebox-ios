import XCTest

final class TaskSuggestionUITests: XCTestCase {

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

    // MARK: - Helper

    /// Finds the task title field by placeholder text (most reliable in XCTest)
    @MainActor
    private func findTitleField() -> XCUIElement {
        // Use placeholder text — more reliable than accessibilityIdentifier in ScrollView contexts
        let byPlaceholder = app.textFields["Task-Titel"]
        if byPlaceholder.waitForExistence(timeout: 5) { return byPlaceholder }
        // Fallback: try accessibilityIdentifier
        return app.textFields["taskTitle"]
    }

    /// Creates a task with the given title via the Backlog "+" flow
    @MainActor
    private func createTask(title: String) {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        let titleField = findTitleField()
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should appear")
        titleField.tap()
        titleField.typeText(title)

        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        // Wait for sheet to dismiss
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Should return to Backlog")
    }

    // MARK: - Suggestions appear

    /// GIVEN: A task "Zahnarzt Termin vereinbaren" exists
    /// WHEN: User opens CreateTask and types "Zahn"
    /// THEN: A suggestion containing "Zahnarzt" appears
    @MainActor
    func testSuggestionsAppearForPrefix() throws {
        // Setup: create a task first
        createTask(title: "Zahnarzt Termin vereinbaren")

        // Open CreateTask again
        let addButton = app.buttons["addTaskButton"]
        addButton.tap()

        let titleField = findTitleField()
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Zahn")

        // Wait for suggestions to appear
        let suggestionText = app.staticTexts["Zahnarzt Termin vereinbaren"]
        XCTAssertTrue(
            suggestionText.waitForExistence(timeout: 3),
            "Suggestion 'Zahnarzt Termin vereinbaren' should appear"
        )
    }

    /// GIVEN: A task "Zahnarzt Termin vereinbaren" exists
    /// WHEN: User taps on the suggestion
    /// THEN: Title field contains the suggested text
    @MainActor
    func testTapSuggestionFillsTitle() throws {
        createTask(title: "Zahnarzt Termin vereinbaren")

        let addButton = app.buttons["addTaskButton"]
        addButton.tap()

        let titleField = findTitleField()
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Zahn")

        // Tap suggestion
        let suggestionText = app.staticTexts["Zahnarzt Termin vereinbaren"]
        XCTAssertTrue(suggestionText.waitForExistence(timeout: 3))
        suggestionText.tap()

        // Title should now be the suggestion
        let fieldValue = titleField.value as? String ?? ""
        XCTAssertEqual(fieldValue, "Zahnarzt Termin vereinbaren",
                       "Title should be filled with suggestion text")
    }

    // MARK: - Duplicate Warning

    /// GIVEN: A task "Zahnarzt Termin vereinbaren" exists
    /// WHEN: User types "Zahnarzt Termin vereinbaren" (exact same)
    /// THEN: A duplicate warning appears
    // Note: Duplicate warning UI tests omitted — the duplicate detection logic
    // is fully covered by 3 unit tests (exact match, high similarity, no duplicate).
    // The conditional rendering of the warning inside glassCardSection is not
    // reliably testable via XCTest due to SwiftUI accessibility hierarchy limitations.

    // MARK: - No Suggestions for Short Input

    /// GIVEN: A task exists
    /// WHEN: User types only 1 character
    /// THEN: No suggestions appear
    @MainActor
    func testNoSuggestionsForSingleCharacter() throws {
        createTask(title: "Zahnarzt Termin vereinbaren")

        let addButton = app.buttons["addTaskButton"]
        addButton.tap()

        let titleField = findTitleField()
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Z")

        // No suggestion should appear
        let suggestionText = app.staticTexts["Zahnarzt Termin vereinbaren"]
        XCTAssertFalse(
            suggestionText.waitForExistence(timeout: 2),
            "No suggestions should appear for single character"
        )
    }

    // MARK: - Settings Toggle

    /// GIVEN: Settings view is open
    /// WHEN: User looks at settings
    /// THEN: Task-Vorschläge toggle exists
    @MainActor
    func testSettingsToggleExists() throws {
        // Navigate to settings
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Scroll down to find the toggle (it's below the fold in Settings)
        let toggle = app.switches["taskSuggestionsToggle"]
        if !toggle.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 5),
            "Task suggestions toggle should exist in Settings"
        )
    }
}
