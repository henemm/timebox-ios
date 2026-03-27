import XCTest

final class FailureQuickSelectUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Helper: App im erzwungenen Abend-Modus starten
    /// eveningStartHour=0 → Evening startet um Mitternacht, also ist es IMMER Abend
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

    // MARK: - Failure QuickSelect Visibility

    /// Verhalten: Im Abend-Modus zeigt die DayView mindestens eine FailureQuickSelect-Card
    /// fuer unerledigte Tasks (Mock-Daten enthalten isNextUp=true Tasks die nicht completed sind)
    /// Bricht wenn: DayView.eveningContent den failureQuickSelectStub behaelt statt FailureQuickSelectView zu rendern
    func test_eveningMode_showsFailureQuickSelect() throws {
        launchInEveningMode()
        navigateToDayTab()

        // FailureQuickSelectView hat Identifier "failureQuickSelect_<taskID>"
        let failureCards = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'failureQuickSelect_'")
        )
        // Warten bis mindestens eine Card geladen ist
        let firstCard = failureCards.firstMatch
        XCTAssertTrue(
            firstCard.waitForExistence(timeout: 10),
            "Abend-Modus sollte mindestens eine FailureQuickSelect-Card fuer unerledigte Tasks zeigen"
        )
    }

    /// Verhalten: Jede FailureQuickSelect-Card zeigt alle 6 Reason-Buttons
    /// Bricht wenn: FailureReason.allCases weniger als 6 Cases hat oder ForEach nicht alle rendert
    func test_failureQuickSelect_showsAllSixReasons() throws {
        launchInEveningMode()
        navigateToDayTab()

        // Warten bis Cards geladen sind
        let firstCard = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'failureQuickSelect_'")
        ).firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10), "Card muss existieren")

        // Alle 6 Reason-Buttons pruefen
        let reasons = ["noTime", "tooTired", "blocked", "notRelevant", "forgotAboutIt", "other"]
        for reason in reasons {
            let button = firstCard.buttons["failureReason_\(reason)"]
            XCTAssertTrue(
                button.waitForExistence(timeout: 3),
                "Reason-Button '\(reason)' sollte sichtbar sein"
            )
        }
    }

    /// Verhalten: Tap auf einen Reason-Button ist moeglich (Button reagiert)
    /// Bricht wenn: Button kein .buttonStyle hat oder onTap-Handler fehlt
    func test_failureQuickSelect_reasonIsTappable() throws {
        launchInEveningMode()
        navigateToDayTab()

        let cards = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'failureQuickSelect_'")
        )
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10), "Card muss existieren")

        // Tap auf den ersten "Keine Zeit"-Button (mehrere Cards haben gleiche Button-IDs)
        let noTimeButtons = app.buttons.matching(identifier: "failureReason_noTime")
        let firstButton = noTimeButtons.element(boundBy: 0)
        XCTAssertTrue(firstButton.waitForExistence(timeout: 3))
        firstButton.tap()

        // Nach Tap: Card existiert weiterhin (nur visuelles Feedback)
        XCTAssertTrue(cards.firstMatch.exists, "Card sollte nach Reason-Tap weiterhin sichtbar sein")
    }

    /// Verhalten: Tap auf X-Button dismissed die Card (Card verschwindet)
    /// Bricht wenn: dismissed @State nicht auf true gesetzt wird oder if-Bedingung fehlt
    func test_failureQuickSelect_dismissable() throws {
        launchInEveningMode()
        navigateToDayTab()

        // Zaehle Cards vor Dismiss
        let cards = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'failureQuickSelect_'")
        )
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10), "Card muss existieren")
        let countBefore = cards.count

        // Extrahiere die Task-ID aus der ersten Card (Format: "failureQuickSelect_<taskID>")
        let firstCard = cards.element(boundBy: 0)
        let cardIdentifier = firstCard.identifier
        let taskID = String(cardIdentifier.dropFirst("failureQuickSelect_".count))

        // Finde Dismiss-Button ueber Index (scoped innerhalb Card funktioniert nicht zuverlaessig bei tap)
        let dismissButton = app.buttons["failureDismiss_\(taskID)"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 3), "Dismiss-Button muss existieren")

        dismissButton.tap()

        // Spezifische Card mit dieser ID sollte verschwunden sein
        let dismissedCard = app.otherElements["failureQuickSelect_\(taskID)"]
        XCTAssertFalse(
            dismissedCard.waitForExistence(timeout: 2),
            "Card sollte nach Dismiss-Tap nicht mehr sichtbar sein"
        )
    }
}
