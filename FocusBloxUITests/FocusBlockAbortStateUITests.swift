import XCTest

/// UI Tests for Bug #211: FocusBlox abbrechen — State wird nicht zurückgesetzt
/// Prüft dass nach dem Abbrechen eines FocusBlox der aktive Block verschwindet.
final class FocusBlockAbortStateUITests: XCTestCase {
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

    // MARK: - Helpers

    private func navigateToFocusTab() {
        let focusTab = app.tabBars.buttons["Focus"]
        if focusTab.waitForExistence(timeout: 5) {
            focusTab.tap()
        }
    }

    // MARK: - Bug #211: Abort setzt State zurück

    /// Verhalten: Nach Abbrechen + Sprint Review "Fertig" verschwindet der aktive Block.
    /// Bricht wenn: FocusLiveView Abort-Button endActivity()/State-Reset fehlt.
    func test_abortBlock_thenDismissReview_blockDisappears() throws {
        navigateToFocusTab()

        // Precondition: Abort-Button existiert (aktiver Block vorhanden)
        let abortButton = app.buttons["abortBlockButton"]
        guard abortButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Abort button not found — kein aktiver Mock-Block")
        }

        // Act: Block abbrechen
        abortButton.tap()

        // Sprint Review muss erscheinen
        let reviewNav = app.navigationBars["Sprint Review"]
        XCTAssertTrue(
            reviewNav.waitForExistence(timeout: 5),
            "Sprint Review muss nach Abort erscheinen"
        )

        // Sprint Review schließen via "Fertig"
        let fertigButton = app.buttons["Fertig"]
        guard fertigButton.waitForExistence(timeout: 3) else {
            XCTFail("Fertig-Button muss in Sprint Review existieren")
            return
        }
        fertigButton.tap()

        // Assert: Abort-Button darf NICHT mehr existieren (kein aktiver Block)
        let abortAfterDismiss = app.buttons["abortBlockButton"]
        XCTAssertFalse(
            abortAfterDismiss.waitForExistence(timeout: 3),
            "Bug #211: Abort-Button darf nach Abbrechen nicht mehr sichtbar sein"
        )

        // Assert: currentTaskView darf nicht mehr existieren
        let taskView = app.otherElements["currentTaskView"]
        XCTAssertFalse(
            taskView.exists,
            "Bug #211: Aktive Task-Anzeige darf nach Abbrechen nicht mehr sichtbar sein"
        )
    }

    /// Verhalten: Nach Abbrechen zeigt Sprint Review den korrekten "Abgebrochen"-Kontext.
    /// Bricht wenn: isAborted-Flag nicht korrekt an SprintReviewSheet übergeben wird.
    func test_abortBlock_sprintReviewShowsAbortContext() throws {
        navigateToFocusTab()

        let abortButton = app.buttons["abortBlockButton"]
        guard abortButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Abort button not found — kein aktiver Mock-Block")
        }

        abortButton.tap()

        // Sprint Review muss erscheinen
        let reviewNav = app.navigationBars["Sprint Review"]
        XCTAssertTrue(
            reviewNav.waitForExistence(timeout: 5),
            "Sprint Review muss nach Abort erscheinen"
        )

        // Follow-up UI sollte sichtbar sein (Abort-Kontext)
        let followUpButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'createFollowUpButton_'")
        ).firstMatch
        XCTAssertTrue(
            followUpButton.waitForExistence(timeout: 3),
            "Follow-up Button muss bei Abort sichtbar sein"
        )
    }

    // MARK: - Adversary Befund #3: Swipe-Down Dismiss

    /// Verhalten: Nach Abort + Swipe-Down des Sprint Review Sheets verschwindet der aktive Block.
    /// Bricht wenn: .sheet(onDismiss:) Cleanup für isAbortingBlock fehlt.
    func test_abortBlock_swipeDownDismiss_blockDisappears() throws {
        navigateToFocusTab()

        let abortButton = app.buttons["abortBlockButton"]
        guard abortButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Abort button not found — kein aktiver Mock-Block")
        }

        // Abort
        abortButton.tap()

        let reviewNav = app.navigationBars["Sprint Review"]
        guard reviewNav.waitForExistence(timeout: 5) else {
            XCTFail("Sprint Review muss nach Abort erscheinen")
            return
        }

        // Swipe-Down statt "Fertig" drücken
        let sheet = app.otherElements.firstMatch
        sheet.swipeDown(velocity: .fast)

        // Kurz warten bis Sheet dismissed
        let dismissed = reviewNav.waitForNonExistence(timeout: 5)
        if !dismissed {
            // Fallback: nochmal versuchen
            sheet.swipeDown(velocity: .fast)
            _ = reviewNav.waitForNonExistence(timeout: 3)
        }

        // Assert: Abort-Button darf nach Swipe-Down nicht mehr existieren
        let abortAfterSwipe = app.buttons["abortBlockButton"]
        XCTAssertFalse(
            abortAfterSwipe.waitForExistence(timeout: 3),
            "Bug #211: Abort-Button darf nach Swipe-Down-Dismiss nicht mehr sichtbar sein"
        )
    }

    // Adversary Befund #4 (Timer/Content nach Abort): Bereits abgedeckt durch
    // test_abortBlock_thenDismissReview_blockDisappears — prüft abortBlockButton + currentTaskView.
    // Mock-Block hat keine SwiftData-Tasks, daher sind taskCompleteButton/taskSkipButton nicht testbar.
}
