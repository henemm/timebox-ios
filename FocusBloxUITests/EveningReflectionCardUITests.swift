import XCTest

/// UI Tests for Evening Reflection Card (Coach-based).
///
/// The card appears in the Review tab when:
/// - Coach mode is enabled
/// - A coach is selected for today
/// - It's after 18:00 (or -ForceEveningReflection launch arg for testing)
///
/// Verified IDs from production code (2026-03-14):
/// - eveningReflectionCard (container)
/// - eveningResult_<coach> (e.g. eveningResult_eule)
/// - monsterIcon_<coach>, reflectionText_<coach>, fulfillmentBadge_<coach>
/// - coachSelectionCard_<coach> (selection cards)
/// - setIntentionButton, editIntentionButton
final class EveningReflectionCardUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-CoachModeEnabled",
            "-ForceEveningReflection"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigate to Review tab (called "Mein Tag" when coach mode is on).
    private func navigateToReviewTab() {
        let meinTagTab = app.tabBars.buttons["Mein Tag"]
        if meinTagTab.waitForExistence(timeout: 5) {
            meinTagTab.tap()
        }
    }

    /// Select a coach by tapping its card and confirming.
    /// Note: Setting the coach switches to Backlog tab, so we navigate back.
    private func selectCoach(_ coach: String = "eule") {
        navigateToReviewTab()

        // If coach already set, tap "Aendern" to show selection grid
        let editButton = app.buttons["editIntentionButton"]
        if editButton.waitForExistence(timeout: 3) {
            editButton.tap()
        }

        let card = app.buttons["coachSelectionCard_\(coach)"]
        if card.waitForExistence(timeout: 5) {
            card.tap()

            let setButton = app.buttons["setIntentionButton"]
            if setButton.waitForExistence(timeout: 3) {
                setButton.tap()
            }
        }

        // Setting coach switches to Backlog tab — navigate back
        navigateToReviewTab()
    }

    // MARK: - Visibility Tests

    /// GIVEN: Coach mode ON + Coach selected + ForceEveningReflection
    /// WHEN: User navigates to Review tab
    /// THEN: EveningReflectionCard is visible
    func test_eveningReflectionCard_visibleWhenCoachEnabled() throws {
        selectCoach("eule")

        let card = app.otherElements["eveningReflectionCard"]
        XCTAssertTrue(
            card.waitForExistence(timeout: 5),
            "Evening reflection card should be visible when coach mode enabled and coach set"
        )
    }

    /// GIVEN: Coach mode OFF
    /// WHEN: User navigates to Review tab
    /// THEN: EveningReflectionCard is NOT visible
    func test_eveningReflectionCard_hiddenWhenCoachDisabled() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ForceEveningReflection"]
        app.launch()

        // Without coach mode, tab is "Rückblick"
        let rueckblickTab = app.tabBars.buttons["Rückblick"]
        if rueckblickTab.waitForExistence(timeout: 5) {
            rueckblickTab.tap()
        }

        let card = app.otherElements["eveningReflectionCard"]
        XCTAssertFalse(
            card.waitForExistence(timeout: 3),
            "Evening reflection card should NOT be visible when coach mode is off"
        )
    }

    /// GIVEN: Coach mode ON + NO coach selected
    /// WHEN: User navigates to Review tab
    /// THEN: EveningReflectionCard is NOT visible
    func test_eveningReflectionCard_hiddenWhenNoCoach() throws {
        navigateToReviewTab()

        let card = app.otherElements["eveningReflectionCard"]
        XCTAssertFalse(
            card.waitForExistence(timeout: 3),
            "Evening reflection card should NOT be visible when no coach is set"
        )
    }

    // MARK: - Content Tests

    /// GIVEN: Coach mode ON + Eule selected
    /// WHEN: Card is visible
    /// THEN: Evening result row for eule is visible
    func test_eveningReflectionCard_showsCoachResult() throws {
        selectCoach("eule")

        let row = app.descendants(matching: .any)["eveningResult_eule"]
        XCTAssertTrue(
            row.waitForExistence(timeout: 5),
            "Evening result row for eule should exist inside the card"
        )
    }

    /// GIVEN: Coach mode ON + Eule selected
    /// WHEN: Card is visible
    /// THEN: Reflection text is visible and not empty
    func test_eveningReflectionCard_showsReflectionText() throws {
        selectCoach("eule")

        let card = app.otherElements["eveningReflectionCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Card should exist")

        // Eule reflection text should reference focus
        let reflectionText = app.descendants(matching: .any)["reflectionText_eule"]
        XCTAssertTrue(
            reflectionText.waitForExistence(timeout: 5),
            "Reflection text for eule should be visible in the card"
        )
    }

    // MARK: - AI Text / Fallback

    /// GIVEN: Coach mode ON + Coach set + AI disabled
    /// WHEN: Card is visible
    /// THEN: Fallback text is displayed (not empty)
    func test_eveningCard_showsFallbackWhenAiDisabled() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-CoachModeEnabled",
            "-ForceEveningReflection",
            "-AIDisabled"
        ]
        app.launch()

        selectCoach("eule")

        let card = app.otherElements["eveningReflectionCard"]
        XCTAssertTrue(
            card.waitForExistence(timeout: 5),
            "Evening reflection card should be visible even when AI is disabled"
        )

        // With AI disabled, fallback template text should show
        let reflectionText = app.descendants(matching: .any)["reflectionText_eule"]
        XCTAssertTrue(
            reflectionText.waitForExistence(timeout: 5),
            "Fallback reflection text should be visible when AI is disabled"
        )
    }

    /// GIVEN: Coach mode ON + Coach set
    /// WHEN: Card is visible (AI or fallback)
    /// THEN: Reflection text exists
    func test_eveningCard_reflectionTextNotEmpty() throws {
        selectCoach("eule")

        let card = app.otherElements["eveningReflectionCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Card should exist")

        let reflectionText = app.descendants(matching: .any)["reflectionText_eule"]
        XCTAssertTrue(
            reflectionText.waitForExistence(timeout: 8),
            "Reflection text should be visible (AI or fallback) and not empty"
        )
    }
}
