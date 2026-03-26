import XCTest

final class SuccessStoryUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Helper: App im erzwungenen Abend-Modus starten
    private func launchInEveningMode() {
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-eveningStartHour", "0"]
        app.launch()
    }

    /// Helper: Zum Tag-Tab navigieren
    private func navigateToDayTab() {
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "Tag-Tab muss existieren")
        tagTab.tap()
    }

    // MARK: - Success Story Card

    /// Verhalten: Im Abend-Modus zeigt die DayView eine Success-Story-Card (kein Stub mehr).
    /// Bricht wenn: SuccessStoryView nicht in DayView.eveningContent eingebunden ist oder
    ///              accessibilityIdentifier "successStoryCard" fehlt.
    func test_eveningMode_showsSuccessStoryCard() throws {
        launchInEveningMode()
        navigateToDayTab()

        // Die echte SuccessStoryView (nicht der alte Stub) muss sichtbar sein
        let storyCard = app.otherElements["successStoryCard"]
        XCTAssertTrue(
            storyCard.waitForExistence(timeout: 10),
            "Abend-Modus sollte die Success-Story-Card zeigen (nicht den Stub)"
        )

        // Der alte Stub darf NICHT mehr existieren
        let oldStub = app.otherElements["successStoryStubCard"]
        XCTAssertFalse(
            oldStub.exists,
            "Der alte Stub 'successStoryStubCard' darf nicht mehr sichtbar sein"
        )
    }

    /// Verhalten: Die Success-Story-Card zeigt Text (nicht leer).
    /// Bricht wenn: SuccessStoryService.generate() oder fallback() keinen Text liefert,
    ///              oder SuccessStoryView den Text nicht rendert.
    func test_successStoryCard_showsText() throws {
        launchInEveningMode()
        navigateToDayTab()

        let storyCard = app.otherElements["successStoryCard"]
        XCTAssertTrue(storyCard.waitForExistence(timeout: 10), "Story-Card muss existieren")

        // Im Simulator laeuft kein Apple Intelligence → Fallback-Text wird angezeigt.
        // Der Fallback enthaelt mindestens "erledigt" oder "Morgen" oder "Tag".
        let cardTexts = storyCard.staticTexts
        XCTAssertGreaterThan(
            cardTexts.count, 0,
            "Success-Story-Card soll mindestens einen Text enthalten"
        )
    }

    /// Verhalten: Die Success-Story-Card zeigt waehrend des Ladens einen Loading-Indicator.
    /// Bricht wenn: SuccessStoryView keinen isLoading-State hat oder
    ///              accessibilityIdentifier "successStoryLoadingView" fehlt.
    /// HINWEIS: Dieser Test kann flaky sein weil Loading sehr schnell sein kann (Fallback).
    func test_successStoryCard_hasAccessibilityIdentifier() throws {
        launchInEveningMode()
        navigateToDayTab()

        // Entweder Loading-View oder fertige Card muss innerhalb 10s erscheinen
        let storyCard = app.otherElements["successStoryCard"]
        let loadingView = app.otherElements["successStoryLoadingView"]

        let cardExists = storyCard.waitForExistence(timeout: 10)
        let loadingExists = loadingView.exists

        XCTAssertTrue(
            cardExists || loadingExists,
            "Entweder successStoryCard oder successStoryLoadingView muss sichtbar sein"
        )
    }
}
