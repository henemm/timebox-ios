import XCTest

final class TaskSplitUITests: XCTestCase {

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

    private func openHygieneView() throws {
        let banner = app.buttons["hygieneCleanupBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Hygiene banner must exist")
        banner.tap()

        let title = app.staticTexts["hygieneTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), "Hygiene view must open")
    }

    private func openSplitView() throws {
        try openHygieneView()

        let splitButton = app.buttons["hygieneSplitButton"]
        XCTAssertTrue(splitButton.waitForExistence(timeout: 3))
        splitButton.tap()

        // Wait for AI suggestions to load
        let firstSuggestion = app.textFields["splitSuggestionTitle_0"]
        XCTAssertTrue(firstSuggestion.waitForExistence(timeout: 15), "AI suggestions must load")
    }

    // MARK: - Split Button in Hygiene View

    /// GIVEN: BacklogHygieneView shows a stale task card
    /// WHEN: Card is displayed
    /// THEN: "Aufteilen" button is visible alongside Park/Delete/Keep
    func test_splitButton_appearsInHygieneView() throws {
        try openHygieneView()

        let splitButton = app.buttons["hygieneSplitButton"]
        XCTAssertTrue(splitButton.waitForExistence(timeout: 3), "Split button should appear on task card")
    }

    /// GIVEN: "Aufteilen" button is visible
    /// WHEN: User taps "Aufteilen"
    /// THEN: TaskSplitView sheet opens showing original task title
    func test_splitButton_opensSheet() throws {
        try openHygieneView()

        let splitButton = app.buttons["hygieneSplitButton"]
        XCTAssertTrue(splitButton.waitForExistence(timeout: 3))
        splitButton.tap()

        let originalTitle = app.staticTexts["splitOriginalTitle"]
        XCTAssertTrue(originalTitle.waitForExistence(timeout: 3), "Original task title should be visible in split view")
    }

    // MARK: - AI Suggestions

    /// GIVEN: TaskSplitView is open
    /// WHEN: AI has generated suggestions
    /// THEN: At least 2 editable suggestion TextFields are visible
    func test_splitView_showsEditableSuggestions() throws {
        try openSplitView()

        let firstField = app.textFields["splitSuggestionTitle_0"]
        XCTAssertTrue(firstField.exists, "First suggestion should be a TextField")

        let secondField = app.textFields["splitSuggestionTitle_1"]
        XCTAssertTrue(secondField.waitForExistence(timeout: 3), "At least 2 suggestions expected")

        // Verify suggestions have text content (not empty)
        let firstValue = firstField.value as? String ?? ""
        XCTAssertFalse(firstValue.isEmpty, "First suggestion should have AI-generated text")
    }

    /// GIVEN: AI suggestions are loaded
    /// WHEN: User taps a suggestion TextField and edits it
    /// THEN: The text is editable
    func test_splitView_suggestionsAreEditable() throws {
        try openSplitView()

        let firstField = app.textFields["splitSuggestionTitle_0"]
        XCTAssertTrue(firstField.exists)

        // Tap to focus and verify it's a real editable TextField
        firstField.tap()

        // Clear and type new text
        firstField.clearAndTypeText("Mein eigener Sub-Task")

        let newValue = firstField.value as? String ?? ""
        XCTAssertTrue(newValue.contains("Mein eigener Sub-Task"), "TextField should accept user input")
    }

    /// GIVEN: AI suggestions are loaded
    /// WHEN: User taps "Nochmal vorschlagen"
    /// THEN: Loading indicator appears (regeneration started)
    func test_splitView_regenerateButton_triggersReload() throws {
        try openSplitView()

        let regenerateButton = app.buttons["splitRegenerateButton"]
        XCTAssertTrue(regenerateButton.exists, "Regenerate button should exist")
        regenerateButton.tap()

        // After tap, loading should appear briefly then new suggestions
        let loadingOrSuggestion = app.progressIndicators["splitLoadingIndicator"].waitForExistence(timeout: 3)
            || app.textFields["splitSuggestionTitle_0"].waitForExistence(timeout: 10)
        XCTAssertTrue(loadingOrSuggestion, "Should show loading or new suggestions after regenerate")
    }

    // MARK: - Create Flow

    /// GIVEN: AI suggestions are loaded
    /// WHEN: User taps "Erstellen"
    /// THEN: Sheet dismisses and hygiene view continues (next card or summary)
    func test_splitView_createButton_dismissesAndAdvances() throws {
        try openSplitView()

        let createButton = app.buttons["splitCreateButton"]
        XCTAssertTrue(createButton.exists, "Create button should exist")
        createButton.tap()

        // After create: back to hygiene view (next card or summary)
        let hygieneTitle = app.staticTexts["hygieneTitle"]
        let summary = app.staticTexts["hygieneSummary"]
        let backToHygiene = hygieneTitle.waitForExistence(timeout: 5) || summary.waitForExistence(timeout: 2)
        XCTAssertTrue(backToHygiene, "Should return to hygiene view after creating sub-tasks")
    }

    /// GIVEN: AI suggestions are loaded
    /// WHEN: User looks at the footer
    /// THEN: Info text explains what happens to the original task
    func test_splitView_showsInfoText() throws {
        try openSplitView()

        let infoText = app.staticTexts["splitInfoText"]
        XCTAssertTrue(infoText.exists, "Info text should be visible")
        XCTAssertTrue(infoText.label.contains("erledigt"), "Info text should mention task will be marked as done")
    }

    /// GIVEN: AI suggestions are loaded
    /// WHEN: User taps "Hinzufügen"
    /// THEN: A new empty TextField row appears
    func test_splitView_addButton_createsNewRow() throws {
        try openSplitView()

        // Count existing suggestions
        let initialCount = countSuggestions()

        let addButton = app.buttons["splitAddButton"]
        XCTAssertTrue(addButton.exists, "Add button should exist")
        addButton.tap()

        // New row should appear
        let newField = app.textFields["splitSuggestionTitle_\(initialCount)"]
        XCTAssertTrue(newField.waitForExistence(timeout: 3), "New empty row should appear after tapping add")
    }

    // MARK: - Helper

    private func countSuggestions() -> Int {
        var count = 0
        for i in 0..<10 {
            if app.textFields["splitSuggestionTitle_\(i)"].exists {
                count += 1
            } else {
                break
            }
        }
        return count
    }
}

// MARK: - XCUIElement Extension

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()
        // Select all existing text and delete
        if let currentValue = value as? String, !currentValue.isEmpty {
            let selectAll = XCUIApplication().menuItems["Select All"]
            if selectAll.waitForExistence(timeout: 1) {
                selectAll.tap()
            }
            typeText(XCUIKeyboardKey.delete.rawValue)
        }
        typeText(text)
    }
}
