//
//  MacBacklogSectionsA11yUITests.swift
//  FocusBloxMacUITests
//
//  TDD RED — Bug #295: BacklogView List-Sektionen fehlen im Accessibility-Tree (macOS).
//  Alle Tests MUESSEN vor dem Fix fehlschlagen (Tests 1-3); Test 4 (Negativ-Anker) ist gruen.
//

import XCTest

/// macOS UI Tests fuer Bug #295: Accessibility-Tree aller Backlog-Sektionen.
///
/// **Mac-Mockdaten-Setup** (FocusBloxMac/FocusBloxMacApp.swift Z. 722+):
/// - NextUp (4 Tasks, alle mit isNextUp=true): "Task 1 #30min", "Task 2 #15min",
///   "Task 3 #45min", "Startups anschreiben wegen Kapitalerhoehung"
/// - Tier-Section (Backlog): "[MOCK] Lohnsteuererklaerung einreichen", "[MOCK] Backlog Task 2"
/// - Stacking-Badge x3: Daily-lesen-Serie (3 Children mit dueDate=heute)
/// - Stacking-Badge x2: Wochenreview-Serie (2 Children mit dueDate=heute)
/// - KEINE Ueberfaellig-Sektion auf macOS (alle Mock-Tasks haben dueDate=heute, NICHT vor heute)
///
/// Pruefungen (Bug #295):
/// 1. Body-Rows einer Tier-Sektion sind im a11y-Tree erreichbar (z.B. Wochenreview)
/// 2. Stacking-Badge "x3" (Daily lesen) ist im a11y-Tree erreichbar
/// 3. Mehr als 4 taskTitle_-IDs (NextUp=4, plus Tier-Sektionen)
/// 4. NextUp-Rows bleiben nach Fix weiterhin erreichbar (Negativ-Anker)
final class MacBacklogSectionsA11yUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        // macOS XCUITest braucht expliziten activate-Call nach launch, sonst bleibt
        // die App im Hintergrund ("Running Background") und Tests scheitern an Activation.
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "App-Window muss existieren")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Hilfsmethode

    /// Wartet auf einen bekannten NextUp-Task als Lade-Anker (App ist geladen + Backlog sichtbar).
    /// Verwendet "[MOCK] Task 1 #30min" — kurzer Titel, kein Truncation-Risiko, isNextUp=true.
    private func waitForBacklogLoaded() {
        let nextUpAnchor = app.staticTexts["[MOCK] Task 1 #30min"]
        XCTAssertTrue(
            nextUpAnchor.waitForExistence(timeout: 5),
            "Bug 295 (macOS): NextUp-Anker '[MOCK] Task 1 #30min' muss als Lade-Anker sichtbar sein"
        )
    }

    // MARK: - Test 1

    /// Verhalten: Tier-Sektionen liefern Body-Rows (Task-Titel) in den a11y-Tree.
    /// Mac-Variante: Wochenreview liegt in einer Tier-Section (alle Mac-Children haben dueDate=heute,
    /// daher KEINE Ueberfaellig-Sektion). Bricht wenn Tier-Sections collapsed bleiben — Bug #295 Symptom.
    func test_tierSection_wochenreviewBodyRowIsInA11yTree() {
        waitForBacklogLoaded()

        // Kern-Assertion: [MOCK] Wochenreview liegt in einer Tier-Sektion (NICHT NextUp)
        // und MUSS im a11y-Tree erreichbar sein — scheitert vor Fix.
        // macOS-Hinweis: Key-Lookup (`app.staticTexts[label]`) ist der robuste Weg auf Mac;
        // strict-predicate `label == X` matcht im Mac-Tree teilweise nicht (anders als iOS).
        let wochenreviewRow = app.staticTexts["[MOCK] Wochenreview"]
        XCTAssertTrue(
            wochenreviewRow.waitForExistence(timeout: 5),
            "Bug 295 (macOS): '[MOCK] Wochenreview' liegt in einer Tier-Sektion und MUSS im a11y-Tree erreichbar sein"
        )
    }

    // MARK: - Test 2

    /// Verhalten: Stacking-Badge "x3" fuer Daily-lesen-Serie ist im a11y-Tree sichtbar.
    /// Mac-Variante: Daily-lesen-Serie hat 3 Children → Badge "x3". Bricht wenn
    /// stackingBadge_<id>-Elemente in Tier-Sektionen fehlen weil ihre Section-Container
    /// nicht im a11y-Tree propagiert werden.
    func test_stackingBadgeX3_isInA11yTree() throws {
        waitForBacklogLoaded()

        // Kern-Assertion: Stacking-Badge mit accessibilityLabel "3 aufgelaufene Instanzen"
        // (Apple SwiftUI ersetzt im a11y-Tree den dargestellten Text durch das gesetzte
        // accessibilityLabel — siehe StackingBadge in TaskBadges.swift:202)
        let badgeQuery = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_' AND label CONTAINS '3 aufgelaufene'")
        )
        let badgeX3 = badgeQuery.firstMatch
        XCTAssertTrue(
            badgeX3.waitForExistence(timeout: 5),
            "Bug 295 (macOS): Stacking-Badge fuer Daily-lesen-Serie (3 Instanzen) muss im a11y-Tree erreichbar sein"
        )

        // XCTUnwrap haerter als waitForExistence: beweist, dass das Element wirklich
        // im Tree als materialisierter Knoten existiert (nicht nur predicate-matched ghost).
        let unwrappedBadge = try XCTUnwrap(
            badgeQuery.allElementsBoundByIndex.first,
            "Bug 295 (macOS): Stacking-Badge x3 muss als unwrappbares Element im a11y-Tree existieren"
        )
        XCTAssertTrue(
            unwrappedBadge.exists,
            "Bug 295 (macOS): Unwrappped Stacking-Badge muss .exists == true erfuellen"
        )
    }

    // MARK: - Test 3

    /// Verhalten: ALLE getesteten Tier-Sektion-Titel sind als StaticTexts im a11y-Tree erreichbar.
    /// Bug #295 Symptom (mac): Stacked Recurring-Rows (Wochenreview, Daily lesen) sind unsichtbar
    /// im a11y-Tree, obwohl regulaere Tier-Tasks (Lohnsteuer, Backlog Task 2) erreichbar sind.
    /// Test ist RED solange mindestens einer der 4 Titel fehlt; GREEN nur wenn alle 4 sichtbar.
    func test_allTierSectionTitlesAreReachable() {
        waitForBacklogLoaded()

        let tierTitles = [
            "[MOCK] Lohnsteuererklaerung einreichen",
            "[MOCK] Backlog Task 2",
            "[MOCK] Taeglich lesen",
            "[MOCK] Wochenreview"
        ]
        // Anti-Silent-Pass: waitForExistence statt .exists — gibt SwiftUI Zeit zum
        // Lazy-Rendern der Section-Body-Rows. .exists ohne Wait wuerde unmittelbar
        // false zurueckgeben fuer noch nicht materialisierte Knoten und den Test
        // unzuverlaessig falsch-rot machen (oder schlimmer: falsch-gruen wenn Mock
        // anders sortiert).
        let missing = tierTitles.filter { title in
            !app.staticTexts[title].waitForExistence(timeout: 2)
        }
        XCTAssertEqual(
            missing.count, 0,
            "Bug 295 (macOS): Alle Tier-Sektion-Titel muessen im a11y-Tree erreichbar sein. " +
            "Fehlend: \(missing)"
        )
    }

    // MARK: - Test 4 (Negativ-Anker)

    /// Verhalten: NextUp-Row "[MOCK] Task 1 #30min" bleibt erreichbar.
    /// Dieser Test darf im RED-Lauf gruen sein — er sichert, dass der Fix NextUp nicht zerstoert.
    /// Bricht wenn: Accessibility-Fix andere Sektionen repariert aber NextUp kaputt macht.
    func test_nextUpRowStaysAccessible_negativAnker() {
        waitForBacklogLoaded()

        let nextUpRow = app.staticTexts["[MOCK] Task 1 #30min"]
        XCTAssertTrue(
            nextUpRow.waitForExistence(timeout: 5),
            "Bug 295 (macOS): NextUp-Row '[MOCK] Task 1 #30min' muss WEITERHIN erreichbar sein " +
            "— Fix darf NextUp nicht zerstoeren"
        )
    }
}
