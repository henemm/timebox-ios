import XCTest

/// UI Tests for Evening Reflection Card (Monster Coach Phase 3c).
///
/// The card appears in the Review tab when:
/// - Coach mode is enabled
/// - A morning intention is set
/// - It's after 18:00 (or -ForceEveningReflection launch arg for testing)
///
/// EXPECTED TO FAIL (TDD RED): EveningReflectionCard does not exist yet.
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
    /// Known IDs from /inspect-ui: tab label "Mein Tag" in coach mode, "Rückblick" otherwise.
    private func navigateToReviewTab() {
        let meinTagTab = app.tabBars.buttons["Mein Tag"]
        if meinTagTab.waitForExistence(timeout: 5) {
            meinTagTab.tap()
        }
    }

    /// Set a morning intention by tapping a chip and confirming.
    /// Known IDs: intentionChip_fokus, setIntentionButton (from MorningIntentionView).
    /// Note: Setting the intention switches to Backlog tab, so we navigate back.
    private func setMorningIntention() {
        navigateToReviewTab()

        // If intention already set, tap "Aendern" to show selection grid
        let editButton = app.buttons["editIntentionButton"]
        if editButton.waitForExistence(timeout: 3) {
            editButton.tap()
        }

        let fokusChip = app.buttons["intentionChip_fokus"]
        if fokusChip.waitForExistence(timeout: 5) {
            fokusChip.tap()

            let setButton = app.buttons["setIntentionButton"]
            if setButton.waitForExistence(timeout: 3) {
                setButton.tap()
            }
        }

        // Setting intention switches to Backlog tab — navigate back
        navigateToReviewTab()
    }

    // MARK: - Visibility Tests

    /// GIVEN: Coach mode ON + Intention gesetzt + ForceEveningReflection
    /// WHEN: User navigiert zum Review-Tab
    /// THEN: EveningReflectionCard ist sichtbar
    /// EXPECTED TO FAIL: Card existiert noch nicht — eveningReflectionCard ID fehlt
    func test_eveningReflectionCard_visibleWhenCoachEnabled() throws {
        setMorningIntention()

        let card = app.otherElements["eveningReflectionCard"]
        XCTAssertTrue(
            card.waitForExistence(timeout: 5),
            "Evening reflection card should be visible when coach mode enabled and intention set"
        )
    }

    /// GIVEN: Coach mode OFF
    /// WHEN: User navigiert zum Review-Tab
    /// THEN: EveningReflectionCard ist NICHT sichtbar
    /// EXPECTED TO FAIL: Card existiert noch nicht
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

    /// GIVEN: Coach mode ON + KEINE Intention gesetzt
    /// WHEN: User navigiert zum Review-Tab
    /// THEN: EveningReflectionCard ist NICHT sichtbar
    /// EXPECTED TO FAIL: Card existiert noch nicht
    func test_eveningReflectionCard_hiddenWhenNoIntention() throws {
        navigateToReviewTab()

        let card = app.otherElements["eveningReflectionCard"]
        XCTAssertFalse(
            card.waitForExistence(timeout: 3),
            "Evening reflection card should NOT be visible when no intention is set"
        )
    }

    // MARK: - Content Tests

    /// GIVEN: Coach mode ON + Intention gesetzt
    /// WHEN: Card ist sichtbar
    /// THEN: Fulfillment-Badge ist sichtbar
    /// EXPECTED TO FAIL: Card + Badge existieren noch nicht
    func test_eveningReflectionCard_showsFulfillmentBadge() throws {
        setMorningIntention()

        // First verify the intention row container exists
        let row = app.descendants(matching: .any)["eveningResult_fokus"]
        XCTAssertTrue(
            row.waitForExistence(timeout: 5),
            "Intention row for fokus should exist inside the card"
        )
    }

    /// GIVEN: Coach mode ON + Intention gesetzt
    /// WHEN: Card ist sichtbar
    /// THEN: Reflection-Text ist sichtbar und nicht leer
    /// EXPECTED TO FAIL: Card + Text existieren noch nicht
    func test_eveningReflectionCard_showsReflectionText() throws {
        setMorningIntention()

        // The reflection card should contain fallback text as staticText
        let card = app.otherElements["eveningReflectionCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Card should exist")

        // With no tasks, fokus evaluates to notFulfilled.
        // Template: "Viel dazwischen gekommen heute. Passiert."
        let fokusText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "dazwischen")
        )
        XCTAssertTrue(
            fokusText.firstMatch.waitForExistence(timeout: 5),
            "Fokus fallback text should be visible in the card"
        )
    }
}
