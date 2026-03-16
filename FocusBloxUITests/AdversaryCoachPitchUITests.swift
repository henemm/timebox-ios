import XCTest

/// Adversary Test: Beweist dass Coach Pitch Fix NICHT funktioniert.
/// 
/// Prueft:
/// 1. Coach-Karten sind sichtbar wenn Coach Mode aktiv ist
/// 2. Pitch-Text ist NICHT mit "..." (SwiftUI lineLimit) abgeschnitten
/// 3. "Coach wählen" Button ist sichtbar (nicht off-screen durch zu langen Text)
/// 4. Deterministische Teasers zeigen kein "..." (von Service-Side Truncation)
///
/// ADVERSARY-LOGIK: Test schlaegt fehl wenn Fix NICHT greift.
final class AdversaryCoachPitchUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-coachModeEnabled", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Test 1: Coach-Karten sichtbar

    /// Bricht wenn: MorningIntentionView nicht geladen oder Coach Mode nicht korrekt aktiviert
    func test_adversary_coachSelectionCards_areVisible_withCoachModeEnabled() {
        // Navigate to Mein Tag tab
        let meinTagTab = app.buttons["tab-meintag"]
        guard meinTagTab.waitForExistence(timeout: 10) else {
            // Fallback: versuche Tab Bar
            XCTFail("ADVERSARY: tab-meintag not found — MorningIntentionView not accessible")
            return
        }
        meinTagTab.tap()

        // Warte auf die Coach-Auswahl-Karte
        let intentionCard = app.otherElements["morningIntentionCard"]
        XCTAssertTrue(
            intentionCard.waitForExistence(timeout: 8),
            "ADVERSARY: morningIntentionCard not found — Coach Mode not working or View not loaded"
        )

        // Alle 4 Coach-Karten muessen existieren
        let trollCard = app.buttons["coachSelectionCard_troll"]
        let feuerCard = app.buttons["coachSelectionCard_feuer"]
        let euleCard = app.buttons["coachSelectionCard_eule"]
        let golemCard = app.buttons["coachSelectionCard_golem"]

        XCTAssertTrue(trollCard.waitForExistence(timeout: 5), "ADVERSARY: Troll card missing")
        XCTAssertTrue(feuerCard.waitForExistence(timeout: 5), "ADVERSARY: Feuer card missing")
        XCTAssertTrue(euleCard.waitForExistence(timeout: 5), "ADVERSARY: Eule card missing")
        XCTAssertTrue(golemCard.waitForExistence(timeout: 5), "ADVERSARY: Golem card missing")
    }

    // MARK: - Test 2: Pitch-Text ist NICHT durch SwiftUI lineLimit abgeschnitten

    /// Bricht wenn: .lineLimit(nil) nicht gesetzt — Text endet mit "..."
    /// NOTE: SwiftUI "..." Truncation (via lineLimit) vs. Service-side "…" Truncation
    /// Der Fix behebt NUR SwiftUI-Truncation. Der Teaser vom Service hat "…" (U+2026).
    /// Wir testen hier: kein "..." (3 ASCII-Punkte) am Ende durch SwiftUI.
    func test_adversary_pitchText_noSwiftUITruncation() {
        let meinTagTab = app.buttons["tab-meintag"]
        guard meinTagTab.waitForExistence(timeout: 10) else {
            XCTFail("ADVERSARY: Cannot navigate to Mein Tag tab")
            return
        }
        meinTagTab.tap()

        // Warte auf Troll-Karte
        let trollCard = app.buttons["coachSelectionCard_troll"]
        guard trollCard.waitForExistence(timeout: 8) else {
            XCTFail("ADVERSARY: Troll card not found")
            return
        }

        // Alle Static Texts in der Troll-Karte lesen
        let allTexts = app.staticTexts.allElementsBoundByIndex
        var pitchTexts: [String] = []
        for text in allTexts {
            let label = text.label
            // Suche nach Text der wie ein Pitch aussieht (laenger als 10 Zeichen)
            if label.count > 10 && !label.contains("Wähle deinen Coach") {
                pitchTexts.append(label)
            }
        }

        // Kein Text darf mit "..." (ASCII 3-Punkte = SwiftUI Truncation) enden
        for text in pitchTexts {
            XCTAssertFalse(
                text.hasSuffix("..."),
                "ADVERSARY: Text truncated by SwiftUI lineLimit: '\(text)' — Fix FAILED"
            )
        }

        // Screenshot als Beweis
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AdversaryCoachPitchTest"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - Test 3: "Coach wählen" Button ist sichtbar (nicht durch langen Text versteckt)

    /// Bricht wenn: Text so lang wird dass der Button off-screen verschwindet
    /// Der Fix (fixedSize vertical) koennte dazu fuehren dass die View zu gross wird
    /// und der "Coach wählen" Button aus dem sichtbaren Bereich herausfaellt.
    func test_adversary_setIntentionButton_isHittable() {
        let meinTagTab = app.buttons["tab-meintag"]
        guard meinTagTab.waitForExistence(timeout: 10) else {
            XCTFail("ADVERSARY: Cannot navigate to Mein Tag tab")
            return
        }
        meinTagTab.tap()

        // Warte auf Coach-Karte
        let trollCard = app.buttons["coachSelectionCard_troll"]
        guard trollCard.waitForExistence(timeout: 8) else {
            XCTFail("ADVERSARY: Coach cards not loaded")
            return
        }

        // Tippe eine Karte an um den "Coach wählen" Button zu aktivieren
        trollCard.tap()

        // Scrolle runter um den Button zu finden
        let setButton = app.buttons["setIntentionButton"]
        
        // Versuche zu scrollen falls noetig
        for _ in 0..<5 {
            if setButton.exists && setButton.isHittable { break }
            app.swipeUp()
        }

        XCTAssertTrue(
            setButton.waitForExistence(timeout: 5),
            "ADVERSARY: setIntentionButton not found — may be off-screen due to expanded pitch texts"
        )
        XCTAssertTrue(
            setButton.isHittable,
            "ADVERSARY: setIntentionButton exists but is NOT HITTABLE — off-screen due to long pitch texts"
        )
    }

    // MARK: - Test 4: shouldAcceptPitch Edge Case — Task mit nur kurzen Woertern

    /// ADVERSARY-LOGIK: shouldAcceptPitch filtert Woerter mit count < 4.
    /// Ein Task-Titel der NUR aus kurzen Woertern besteht ("Tax", "Q2", "HP")
    /// wuerde dazu fuehren dass words=[] → keine Matches → Pitch IMMER abgelehnt.
    /// Das ist ein ECHTER BUG im Fix: Tasks mit kurzen Namen fuehren zu endlosem Fallback.
    ///
    /// Dieser Test ist ein UNIT TEST simuliert hier als Logikpruefung.
    /// Er verifiziert den bekannten Edge Case im shouldAcceptPitch-Algorithmus.
    func test_adversary_shouldAcceptPitch_allShortWordTask_edgeCase() {
        // Simuliere: Task heisst "Q2" (2 Zeichen) — alle Woerter gefiltert → words = []
        // In der echten App: shouldAcceptPitch("Die Q2 Planung ist wichtig", taskNames: ["Q2"])
        // Erwartet: true (Task-Name im Pitch vorhanden)
        // Tatsaechlich: false (weil "q2".count = 2 < 4, wird gefiltert → words = [])
        
        // Wir koennen das hier nicht direkt testen ohne @testable import
        // Aber wir koennen die Logik manuell verifizieren:
        let taskName = "Q2"
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let words = taskName.lowercased()
            .components(separatedBy: separators)
            .filter { $0.count >= 4 }
        
        // ADVERSARY: Diese Assertion FAELLT durch wenn words leer ist
        // Das beweist den Edge Case Bug
        XCTAssertFalse(
            words.isEmpty,
            "ADVERSARY: shouldAcceptPitch hat einen Edge Case Bug! " +
            "Task-Titel 'Q2' produziert words=[] weil alle Woerter < 4 Zeichen. " +
            "Das fuehrt dazu dass shouldAcceptPitch IMMER false zurueckgibt " +
            "fuer Tasks mit kurzen Namen, auch wenn der Pitch den Task-Namen enthaelt. " +
            "ECHTER BUG: AI Pitch wird faelschlicherweise abgelehnt."
        )
    }
}
