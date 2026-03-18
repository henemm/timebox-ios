import XCTest

/// UI Tests for FEATURE_015: Tag-Auswahl redesignen
///
/// Verifies that tag suggestions appear ABOVE the input field (prominent),
/// with "Neuer Tag" input at the bottom.
///
/// TDD RED: Tests FAIL because suggestions currently appear BELOW input
/// TDD GREEN: Tests PASS after layout reorder in TagInputView
///
/// Verified identifiers via /inspect-ui:
///   TextField: "taskFormSection_tags" (placeholder "Neuer Tag") at y≈728
///   Suggestions: "tagSuggestion_*" at y≈758
///   Currently: input ABOVE suggestions → tests assert the reverse
final class TagRedesignUITests: XCTestCase {

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
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
    }

    private func openCreateTaskSheet() {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add task button should exist")
        addButton.tap()
    }

    private func scrollToTagsSection() {
        let scrollView = app.scrollViews["taskFormScrollView"]
        if scrollView.waitForExistence(timeout: 3) {
            scrollView.swipeUp()
        }
    }

    // MARK: - Layout Order Tests (RED — currently FAIL)

    /// Verhalten: Suggestion-Chips erscheinen OBERHALB des Input-Felds
    /// Bricht wenn: TagInputView.swift body — Suggestions nach Input statt davor
    /// EXPECTED TO FAIL: Currently suggestions (y≈758) are BELOW input (y≈728)
    func testSuggestionsAppearAboveInput() throws {
        navigateToBacklog()
        openCreateTaskSheet()
        scrollToTagsSection()

        // TextField identifier from /inspect-ui: "taskFormSection_tags"
        let tagInput = app.textFields["taskFormSection_tags"]
        XCTAssertTrue(tagInput.waitForExistence(timeout: 5), "Tag input field should exist")

        // Find any suggestion — mock data seeds tags: learning, planning, maintenance, work, design
        let anySuggestion = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'tagSuggestion_'")
        ).firstMatch

        XCTAssertTrue(
            anySuggestion.waitForExistence(timeout: 5),
            "FEATURE_015: At least one tag suggestion should be visible"
        )

        // KEY ASSERTION: Suggestion must be ABOVE (lower Y value) the input field
        // Currently: input y≈728, suggestions y≈758 → suggestions are BELOW → FAILS
        let suggestionY = anySuggestion.frame.midY
        let inputY = tagInput.frame.midY

        XCTAssertLessThan(
            suggestionY, inputY,
            "FEATURE_015: Suggestions (y=\(suggestionY)) must appear ABOVE input (y=\(inputY)). Layout reorder needed."
        )
    }

    /// Verhalten: Tap auf Suggestion fuegt Tag hinzu
    /// Bricht wenn: TagInputView suggestion button action entfernt/geaendert
    /// Should PASS already (existing behavior) — regression safety
    func testTapSuggestionAddsTag() throws {
        navigateToBacklog()
        openCreateTaskSheet()
        scrollToTagsSection()

        // Use a specific suggestion we know exists from mock data
        let suggestion = app.buttons["tagSuggestion_learning"]
        XCTAssertTrue(
            suggestion.waitForExistence(timeout: 5),
            "FEATURE_015: tagSuggestion_learning should appear (mock data has 'learning' tag)"
        )

        suggestion.tap()

        // After tap: tag should appear as assigned chip with remove button
        let removeButton = app.buttons["removeTag_learning"]
        XCTAssertTrue(
            removeButton.waitForExistence(timeout: 5),
            "FEATURE_015: After tapping suggestion 'learning', removeTag_learning button should appear"
        )

        // Suggestion should disappear (already assigned)
        let suggestionGone = app.buttons["tagSuggestion_learning"]
        XCTAssertFalse(
            suggestionGone.waitForExistence(timeout: 2),
            "FEATURE_015: After assigning 'learning', it should no longer appear as suggestion"
        )
    }

    /// Verhalten: xmark entfernt Tag, Tag erscheint wieder als Suggestion
    /// Bricht wenn: tagChip remove button action geaendert
    /// Should PASS already — regression safety
    func testRemoveTagShowsSuggestionAgain() throws {
        navigateToBacklog()
        openCreateTaskSheet()
        scrollToTagsSection()

        // First add a tag via suggestion
        let suggestion = app.buttons["tagSuggestion_planning"]
        XCTAssertTrue(
            suggestion.waitForExistence(timeout: 5),
            "FEATURE_015: tagSuggestion_planning should exist"
        )
        suggestion.tap()

        // Now remove it
        let removeButton = app.buttons["removeTag_planning"]
        XCTAssertTrue(
            removeButton.waitForExistence(timeout: 5),
            "FEATURE_015: removeTag_planning should exist after adding tag"
        )
        removeButton.tap()

        // Tag should reappear as suggestion
        let suggestionAgain = app.buttons["tagSuggestion_planning"]
        XCTAssertTrue(
            suggestionAgain.waitForExistence(timeout: 5),
            "FEATURE_015: After removing 'planning', it should reappear as suggestion"
        )
    }
}
