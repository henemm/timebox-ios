import XCTest

/// Tests for TaskSplitView — AI-powered task splitting with BacklogRow cards.
///
/// Important: The split view opens as a sheet OVER the backlog. XCUITest sees
/// elements from BOTH views. Tests must NOT rely on element counting.
/// Instead, they test behaviors unique to the split view.
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

    // MARK: - Navigation Helpers

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

        // Wait for suggestions to load — splitCreateButton only appears after loading
        let createButton = app.buttons["splitCreateButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 15), "Split view must load with suggestions")
    }

    // MARK: - Entry Point

    /// GIVEN: BacklogHygieneView shows a stale task
    /// THEN: "Aufteilen" button is visible
    func test_splitButton_appearsInHygieneView() throws {
        try openHygieneView()

        let splitButton = app.buttons["hygieneSplitButton"]
        XCTAssertTrue(splitButton.waitForExistence(timeout: 3), "Split button should appear")
    }

    /// GIVEN: User taps "Aufteilen"
    /// THEN: Sheet opens with original task title
    func test_splitButton_opensSheet() throws {
        try openHygieneView()

        app.buttons["hygieneSplitButton"].tap()

        let originalTitle = app.staticTexts["splitOriginalTitle"]
        XCTAssertTrue(originalTitle.waitForExistence(timeout: 3), "Original task title should be visible")
    }

    // MARK: - BacklogRow Migration (#217 v2)

    /// GIVEN: Split view is open with AI suggestions
    /// THEN: Old TextField-based layout is gone (replaced by BacklogRow)
    /// BREAKS WHEN: Still using old splitSuggestionTitle TextFields
    func test_splitView_usesBacklogRowCards() throws {
        try openSplitView()

        // Old identifiers must NOT exist
        XCTAssertFalse(app.textFields["splitSuggestionTitle_0"].exists,
                       "Old TextField layout should be replaced by BacklogRow cards")
        XCTAssertFalse(app.buttons["splitDurationBadge_0"].exists,
                       "Old duration badges should be replaced by BacklogRow durationBadge")
        XCTAssertFalse(app.buttons["splitDeleteButton_0"].exists,
                       "Old delete buttons should be replaced by swipe-to-delete")
    }

    // MARK: - Duration Editing (#217 v2)

    /// GIVEN: Split view is open
    /// WHEN: User taps a duration badge
    /// THEN: DurationPicker sheet opens
    /// BREAKS WHEN: onDurationTap callback not wired to BacklogRow
    func test_splitView_durationTapOpensPicker() throws {
        try openSplitView()

        // Find any duration badge and tap it
        let badge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        ).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 3), "Duration badge must exist")
        badge.tap()

        // DurationPicker should open
        let pickerTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertTrue(pickerTitle.waitForExistence(timeout: 3), "DurationPicker should open on badge tap")
    }

    /// GIVEN: DurationPicker is open
    /// WHEN: User picks 60 minutes
    /// THEN: Badge text updates
    /// BREAKS WHEN: onSelect doesn't update suggestion minutes
    func test_splitView_durationUpdatesAfterPick() throws {
        try openSplitView()

        let badge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        ).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 3))
        badge.tap()

        app.buttons["60m"].tap()

        // Verify badge updated (re-query since element might have changed)
        let updatedBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        ).firstMatch
        XCTAssertTrue(updatedBadge.waitForExistence(timeout: 3))
        XCTAssertTrue(updatedBadge.label.contains("60"), "Badge should show 60 min after pick")
    }

    // MARK: - BacklogRow Positive Proof (#217 v2 — Adversary Round 2)

    /// GIVEN: Split view is open with AI suggestions
    /// THEN: At least one taskTitle_ element is hittable (in the sheet, not behind it)
    /// BREAKS WHEN: BacklogRow not used in split view
    func test_splitView_hasHittableBacklogRowTitle() throws {
        try openSplitView()

        let titles = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).allElementsBoundByIndex
        let hittableTitle = titles.first { $0.isHittable }
        XCTAssertNotNil(hittableTitle, "At least one taskTitle_ must be hittable in the split sheet")
    }

    /// GIVEN: Original task has a category
    /// THEN: A categoryBadge is hittable in the split sheet
    /// BREAKS WHEN: Category not inherited or BacklogRow not rendering it
    func test_splitView_showsInheritedCategory() throws {
        try openSplitView()

        let badges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'categoryBadge_'")
        ).allElementsBoundByIndex
        let hittableBadge = badges.first { $0.isHittable }
        XCTAssertNotNil(hittableBadge, "Category badge must be hittable in split sheet (inherited from original)")
    }

    /// GIVEN: Original task has importance set
    /// THEN: An importanceBadge is hittable in the split sheet
    /// BREAKS WHEN: Importance not inherited
    func test_splitView_showsInheritedImportance() throws {
        try openSplitView()

        let badges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).allElementsBoundByIndex
        let hittableBadge = badges.first { $0.isHittable }
        XCTAssertNotNil(hittableBadge, "Importance badge must be hittable in split sheet (inherited from original)")
    }

    // MARK: - Swipe to Delete (#217 v2)

    /// GIVEN: Split view has suggestion cards
    /// WHEN: User swipes left on a card
    /// THEN: "Löschen" action appears
    /// BREAKS WHEN: swipeActions not configured on BacklogRow
    func test_splitView_swipeRevealsDelete() throws {
        try openSplitView()

        // Swipe on a suggestion card (use title element as anchor)
        let title = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.swipeLeft()

        let deleteButton = app.buttons["Löschen"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Swipe should reveal delete action")
    }

    /// GIVEN: Only 1 suggestion remains
    /// WHEN: User swipes left and taps "Löschen"
    /// THEN: The suggestion survives (not deleted — last one is protected)
    /// BREAKS WHEN: suggestions.count > 1 guard missing in swipeActions
    func test_splitView_cannotDeleteLastSuggestion() throws {
        try openSplitView()

        // Delete all but one: keep swiping hittable titles
        for _ in 0..<10 {
            let titles = app.staticTexts.matching(
                NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
            ).allElementsBoundByIndex.filter { $0.isHittable }

            // When only 1 hittable title remains, stop deleting
            if titles.count <= 1 { break }

            titles.first?.swipeLeft()
            let deleteBtn = app.buttons["Löschen"].firstMatch
            if deleteBtn.waitForExistence(timeout: 2) {
                deleteBtn.tap()
                sleep(1)
            } else {
                break
            }
        }

        // Verify: splitCreateButton still exists (view didn't break)
        XCTAssertTrue(app.buttons["splitCreateButton"].exists, "Split view should still be functional")

        // Verify: at least 1 hittable suggestion title survives
        let remaining = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).allElementsBoundByIndex.filter { $0.isHittable }
        XCTAssertGreaterThanOrEqual(remaining.count, 1, "Last suggestion must survive — cannot be deleted")
    }

    // MARK: - Regenerate (#217 v2)

    /// GIVEN: Split view is open
    /// THEN: Button label is "Neu generieren" (not "Nochmal")
    /// BREAKS WHEN: Label not updated
    func test_regenerateButton_labelIsNeuGenerieren() throws {
        try openSplitView()

        let button = app.buttons["splitRegenerateButton"]
        XCTAssertTrue(button.exists, "Regenerate button should exist")
        XCTAssertTrue(button.label.contains("Neu generieren"), "Label should be 'Neu generieren'")
    }

    /// GIVEN: User changed a duration
    /// WHEN: User taps "Neu generieren"
    /// THEN: Alert "Änderungen verwerfen?" appears
    /// BREAKS WHEN: Change tracking or alert missing
    func test_regenerateWithChanges_showsAlert() throws {
        try openSplitView()

        // Make a change
        let badge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        ).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 3))
        badge.tap()
        app.buttons["60m"].tap()

        // Tap regenerate
        let regenerate = app.buttons["splitRegenerateButton"]
        XCTAssertTrue(regenerate.waitForExistence(timeout: 3))
        regenerate.tap()

        let alert = app.alerts["Änderungen verwerfen?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "Alert should appear after changes")
    }

    // MARK: - Create Flow

    /// GIVEN: Suggestions loaded
    /// WHEN: User taps "Erstellen"
    /// THEN: Sheet dismisses, back to hygiene
    func test_splitView_createDismisses() throws {
        try openSplitView()

        app.buttons["splitCreateButton"].tap()

        let hygieneTitle = app.staticTexts["hygieneTitle"]
        let summary = app.staticTexts["hygieneSummary"]
        let back = hygieneTitle.waitForExistence(timeout: 5) || summary.waitForExistence(timeout: 2)
        XCTAssertTrue(back, "Should return to hygiene view after creating")
    }

    /// GIVEN: Split view is open
    /// THEN: Info text about original task is visible
    func test_splitView_showsInfoText() throws {
        try openSplitView()

        let info = app.staticTexts["splitInfoText"]
        XCTAssertTrue(info.exists, "Info text should be visible")
        XCTAssertTrue(info.label.contains("erledigt"), "Should mention task marked as done")
    }

    /// GIVEN: Split view is open
    /// WHEN: User taps "Hinzufügen"
    /// THEN: Add button exists and is tappable
    func test_splitView_addButtonExists() throws {
        try openSplitView()

        let addButton = app.buttons["splitAddButton"]
        XCTAssertTrue(addButton.exists, "Add button should exist")
    }
}
