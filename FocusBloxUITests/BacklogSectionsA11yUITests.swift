//
//  BacklogSectionsA11yUITests.swift
//  FocusBloxUITests
//
//  TDD RED — Bug #295: BacklogView List-Sektionen fehlen im Accessibility-Tree.
//  Alle Tests MUESSEN vor dem Fix fehlschlagen.
//

import XCTest

/// UI Tests fuer Bug #295: Accessibility-Tree aller Backlog-Sektionen.
///
/// Testet:
/// 1. Body-Rows der Ueberfaellig-Sektion sind im a11y-Tree erreichbar
/// 2. Stacking-Badge "x3" (Wochenreview) ist im a11y-Tree erreichbar
/// 3. Mehr als 4 taskTitle_-IDs (NextUp=4, plus Tier/Ueberfaellig-Sektionen)
/// 4. NextUp-Rows bleiben nach Fix weiterhin erreichbar (Negativ-Anker)
final class BacklogSectionsA11yUITests: XCTestCase {

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

    // MARK: - Hilfsmethode: Backlog-Tab oeffnen

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    /// Scrollt nach unten bis das gesuchte Element im a11y-Tree erscheint.
    /// Notwendig weil SwiftUI List off-screen Body-Rows lazy-rendert.
    @discardableResult
    private func scrollUntilVisible(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        for _ in 0..<maxSwipes {
            if element.waitForExistence(timeout: 0.5) {
                return true
            }
            app.swipeUp()
        }
        return element.waitForExistence(timeout: 1.0)
    }

    // MARK: - Test 1

    /// Verhalten: Ueberfaellig-Sektion liefert Body-Rows (Task-Titel) in den a11y-Tree.
    /// Bricht wenn: Section ohne .accessibilityElement(children: .contain) bleibt — Body-Rows
    ///              werden von SwiftUI im Tree collapsed und sind fuer XCUITest unsichtbar.
    func test_ueberfaelligSection_bodyRowsAreInA11yTree() {
        navigateToBacklog()

        // Positiv-Anker: Ueberfaellig-Header muss sichtbar sein (zeigt, dass wir auf dem Screen sind)
        let ueberfaelligHeader = app.staticTexts.matching(
            NSPredicate(format: "label == 'Ueberfaellig' OR label == '\u{dc}berf\u{e4}llig'")
        ).firstMatch
        XCTAssertTrue(
            ueberfaelligHeader.waitForExistence(timeout: 5),
            "Bug 295: Ueberfaellig-Section-Header muss im a11y-Tree sichtbar sein"
        )

        // Kern-Assertion: [MOCK] Wochenreview liegt in der Ueberfaellig-Sektion
        // und MUSS im a11y-Tree erreichbar sein — scheitert vor Fix
        // Scroll noetig weil SwiftUI List off-screen Body-Rows lazy-rendert
        let wochenreviewRow = app.staticTexts.matching(
            NSPredicate(format: "label == '[MOCK] Wochenreview'")
        ).firstMatch
        XCTAssertTrue(
            scrollUntilVisible(wochenreviewRow),
            "Bug 295: Wochenreview liegt in Ueberfaellig-Sektion und MUSS im a11y-Tree erreichbar sein"
        )
    }

    // MARK: - Test 2

    /// Verhalten: Stacking-Badge "x3" fuer Wochenreview ist im a11y-Tree sichtbar.
    /// Bricht wenn: stackingBadge_<id>-Elemente in Tier/Ueberfaellig-Sektionen fehlen
    ///              weil ihre Section-Container nicht im a11y-Tree propagiert werden.
    func test_stackingBadgeX3_isInA11yTree() throws {
        navigateToBacklog()

        // Warte bis die Liste geladen ist (NextUp ist immer sichtbar — als Lade-Anker)
        let anyTaskTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch
        XCTAssertTrue(
            anyTaskTitle.waitForExistence(timeout: 5),
            "Bug 295: Mindestens ein taskTitle_-Element muss geladen sein (Lade-Anker)"
        )

        // Kern-Assertion: Stacking-Badge "x3" mit korrektem Identifier
        // Mock-Daten: Series 2 "Wochenreview" hat 3 offene Children → Badge "x3"
        // Scroll noetig weil das Badge in der Ueberfaellig-Sektion liegt (lazy)
        // Predicate auf accessibilityLabel statt sichtbarem 'x3'-Text — Apple SwiftUI ersetzt
        // im a11y-Tree den dargestellten Text durch das gesetzte accessibilityLabel.
        let badgeQuery = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_' AND label CONTAINS '3 aufgelaufene'")
        )
        let badgeX3 = badgeQuery.firstMatch
        XCTAssertTrue(
            scrollUntilVisible(badgeX3),
            "Bug 295: Stacking-Badge 'x3' fuer Wochenreview muss im a11y-Tree erreichbar sein"
        )

        // XCTUnwrap haerter als waitForExistence: beweist, dass das Element wirklich
        // im Tree als materialisierter Knoten existiert (nicht nur "predicate-matched ghost").
        let unwrappedBadge = try XCTUnwrap(
            badgeQuery.allElementsBoundByIndex.first,
            "Bug 295: Stacking-Badge x3 muss als unwrappbares Element im a11y-Tree existieren"
        )
        XCTAssertTrue(
            unwrappedBadge.exists,
            "Bug 295: Unwrappped Stacking-Badge muss .exists == true erfuellen"
        )
    }

    // MARK: - Test 3

    /// Bug 295: Beweis dass Dringend- ODER Bald-Tier-Sektion als Container im a11y-Tree
    /// erreichbar ist (nicht nur Ueberfaellig-Sektion).
    /// Anti-Silent-Pass: NextUp initial sichtbar (Lade-Anker), DANN Scroll bis
    /// Section-Header sichtbar UND Section-Container im Tree als Identifier auffindbar.
    /// Spec verlangt explizite Coverage einer Dringend/Bald-Sektion (nicht Ueberfaellig).
    func test_dringendOrBaldSection_bodyRowIsAccessible() {
        navigateToBacklog()

        // Lade-Anker: NextUp initial sichtbar
        let nextUpAnchor = app.staticTexts.matching(
            NSPredicate(format: "label == '[MOCK] Lohnsteuererklaerung einreichen'")
        ).firstMatch
        XCTAssertTrue(
            nextUpAnchor.waitForExistence(timeout: 5),
            "Bug 295: NextUp-Task '[MOCK] Lohnsteuererklaerung einreichen' muss initial sichtbar sein"
        )

        // Erste Assertion: Dringend- oder Bald-Section-Header muss nach Scroll sichtbar sein.
        // Mock-Daten enthalten Tier-Tasks (Bug-Fix Navigation Crash, Backlog Task 1/2 etc.) —
        // mindestens eine der beiden Sektionen MUSS non-empty sein.
        let dringendOrBaldHeader = app.staticTexts.matching(
            NSPredicate(format: "label == 'Dringend' OR label == 'Bald'")
        ).firstMatch
        XCTAssertTrue(
            scrollUntilVisible(dringendOrBaldHeader),
            "Bug 295: Dringend- oder Bald-Section-Header muss nach Scroll im a11y-Tree erreichbar sein"
        )

        // Kern-Assertion: Section-Container muss als Identifier im Tree auffindbar sein.
        // Wenn dringendSection/baldSection als .accessibilityElement(children: .contain)
        // korrekt exposed sind, finden wir den Container — und damit sind seine Body-Rows
        // im a11y-Tree adressierbar (Bug-295-Symptom: ohne children:.contain fehlte das).
        let tierSectionContainer = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'dringendSection' OR identifier == 'baldSection'")
        ).firstMatch
        XCTAssertTrue(
            scrollUntilVisible(tierSectionContainer),
            "Bug 295: Dringend- oder Bald-Sektion muss als Container (children: .contain) " +
            "im a11y-Tree erreichbar sein — beweist dass Tier-Sektionen jenseits Ueberfaellig " +
            "korrekt exposed werden."
        )
    }

    // MARK: - Test 4 (Negativ-Anker)

    /// Verhalten: NextUp-Row "[MOCK] Lohnsteuererklaerung einreichen" bleibt nach Fix erreichbar.
    /// Dieser Test darf im RED-Lauf gruen sein — er sichert, dass der Fix NextUp nicht zerstoert.
    /// Bricht wenn: Accessibility-Fix andere Sektionen repariert aber NextUp kaputt macht.
    func test_nextUpRowStaysAccessible_negativAnker() {
        navigateToBacklog()

        let nextUpRow = app.staticTexts.matching(
            NSPredicate(format: "label == '[MOCK] Lohnsteuererklaerung einreichen'")
        ).firstMatch
        XCTAssertTrue(
            nextUpRow.waitForExistence(timeout: 5),
            "Bug 295: NextUp-Row '[MOCK] Lohnsteuererklaerung einreichen' muss WEITERHIN erreichbar sein " +
            "— Fix darf NextUp nicht zerstoeren"
        )
    }
}
