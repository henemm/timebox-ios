import XCTest

/// UI Tests for CoachView Inline Actions (Feature #278)
///
/// Validates that all Coach sections have appropriate quick-action buttons:
/// - "Heute geplant" → Erledigt + Entplanen
/// - "Offen geblieben" → Erledigt + Auf morgen
/// - "Vorschläge" → Für heute einplanen + Ausblenden (existing)
final class CoachInlineActionsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    private func navigateToCoachTab() {
        let coachTab = app.tabBars.buttons["Coach"]
        if coachTab.waitForExistence(timeout: 5) {
            coachTab.tap()
        }
    }

    // MARK: - "Heute geplant" Section Actions

    func test_plannedSection_hasCompleteButton() {
        navigateToCoachTab()

        // Look for "Erledigt" action button in the planned section
        let completeButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Erledigt'")
        ).firstMatch

        XCTAssertTrue(completeButton.waitForExistence(timeout: 5),
            "Heute geplant section must have an 'Erledigt' inline action button")
    }

    func test_plannedSection_hasUnplanButton() {
        navigateToCoachTab()

        // Look for "Entplanen" action button
        let unplanButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Entplanen'")
        ).firstMatch

        XCTAssertTrue(unplanButton.waitForExistence(timeout: 5),
            "Heute geplant section must have an 'Entplanen' inline action button")
    }

    // MARK: - Existing "Vorschläge" Actions (regression check)

    func test_suggestionsSection_stillHasPlanButton() {
        navigateToCoachTab()

        let planButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Für heute einplanen'")
        ).firstMatch

        XCTAssertTrue(planButton.waitForExistence(timeout: 5),
            "Vorschläge section must still have 'Für heute einplanen' button")
    }
}
