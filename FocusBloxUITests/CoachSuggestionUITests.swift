import XCTest

/// UI Tests fuer Bug #226: Vorschlaege nicht sinnvoll
/// Prueft dass der Coach-Tab Vorschlaege korrekt anzeigt und Aktionen funktionieren.
final class CoachSuggestionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--uitesting", "--mock-data"]
        app.launch()
    }

    /// Navigiert zum Coach-Tab und oeffnet den Morning-Drawer.
    private func navigateToCoachMorning() {
        let coachTab = app.tabBars.buttons["Coach"]
        XCTAssertTrue(coachTab.waitForExistence(timeout: 5), "Coach-Tab muss existieren")
        coachTab.tap()

        let coachView = app.otherElements["coachView"]
        XCTAssertTrue(coachView.waitForExistence(timeout: 5), "CoachView muss laden")
    }

    // MARK: - Bug #226: Einplanen → Vorschlag verschwindet

    /// Verhalten: Nach "Fuer heute einplanen" verschwindet der Task sofort aus den Vorschlaegen.
    /// Bricht wenn: Cache nicht invalidiert wird (RC-1) oder View nicht refreshed.
    func test_addToToday_removesTaskFromSuggestions() {
        navigateToCoachMorning()

        // Morning-Drawer oeffnen
        let morningDrawer = app.otherElements["coachDrawer_morgen"]
        if morningDrawer.waitForExistence(timeout: 3) {
            morningDrawer.tap()
        }

        // Ersten "Fuer heute einplanen" Button finden
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'einplanen'")).firstMatch
        guard addButton.waitForExistence(timeout: 5) else {
            XCTFail("Kein 'Fuer heute einplanen' Button gefunden — keine Vorschlaege sichtbar")
            return
        }

        // Task-Titel merken (accessibilityIdentifier des Buttons enthaelt Task-ID)
        let addButtonID = addButton.identifier
        addButton.tap()

        // Nach Tap: Button mit gleicher ID darf nicht mehr existieren
        let sameButton = app.buttons[addButtonID]
        XCTAssertFalse(sameButton.waitForExistence(timeout: 2),
                       "Task muss nach 'Fuer heute einplanen' sofort aus Vorschlaegen verschwinden")
    }

    // MARK: - Bug #226: Ausblenden → Vorschlag verschwindet

    /// Verhalten: Nach "Ausblenden" verschwindet der Task aus den Vorschlaegen.
    /// Bricht wenn: dismissedTaskIDs nicht persistent ist (RC-2).
    func test_dismiss_removesTaskFromSuggestions() {
        navigateToCoachMorning()

        let morningDrawer = app.otherElements["coachDrawer_morgen"]
        if morningDrawer.waitForExistence(timeout: 3) {
            morningDrawer.tap()
        }

        let dismissButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ausblenden'")).firstMatch
        guard dismissButton.waitForExistence(timeout: 5) else {
            XCTFail("Kein 'Ausblenden' Button gefunden — keine Vorschlaege sichtbar")
            return
        }

        let dismissButtonID = dismissButton.identifier
        dismissButton.tap()

        let sameButton = app.buttons[dismissButtonID]
        XCTAssertFalse(sameButton.waitForExistence(timeout: 2),
                       "Task muss nach 'Ausblenden' sofort aus Vorschlaegen verschwinden")
    }
}
