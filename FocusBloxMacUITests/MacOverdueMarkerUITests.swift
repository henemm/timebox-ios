import XCTest

/// macOS UI Tests für das Overdue-Marker-Rework (Issues #288, #294, #296).
///
/// macOS hatte VORHER keinen roten Punkt in MacBacklogRow — der ist mit diesem Feature NEU.
///
/// TDD RED: Tests SCHLAGEN FEHL weil:
/// - 'overdueMarker_<uuid>' in MacBacklogRow noch nicht existiert
/// - '--overdue-uitesting' Seed für macOS noch nicht implementiert
/// - macOS Sidebar-Badge noch Score-basiert zählt (oder fehlt ganz)
///
/// Pattern aus bestehenden MacUITests (MacBacklogSectionsA11yUITests.swift):
/// - launchArguments: ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
/// - app.activate() nach launch (sonst bleibt App im Hintergrund)
/// - waitForExistence(timeout: 10) konsequent
final class MacOverdueMarkerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // --overdue-uitesting: Seed mit 3 überfälligen, 2 nicht-überfälligen, 1 ohne Datum
        // -UITesting: In-memory Store
        app.launchArguments = ["-UITesting", "--overdue-uitesting", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: 10),
            "macOS App-Window muss existieren"
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    /// Wartet bis der Backlog geladen ist (anhand eines bekannten Task-Titles).
    private func waitForBacklogLoaded() {
        // Der --overdue-uitesting Seed enthält '[OVERDUE-MOCK] Überfällig 1'
        let loadAnchor = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[OVERDUE-MOCK]'")
        ).firstMatch
        _ = loadAnchor.waitForExistence(timeout: 10)
    }

    // MARK: - AC-12: macOS MacBacklogRow zeigt überfälligen Task mit rotem Punkt

    /// Verhalten: Überfälliger Task in MacBacklogRow zeigt overdueMarker.
    /// Bricht wenn: MacBacklogRow keinen roten Punkt hat (fehlt bisher komplett).
    func test_macOverdueTask_hasOverdueMarker() throws {
        waitForBacklogLoaded()

        // Nach Refactor: overdueMarker_<uuid> in MacBacklogRow
        let firstMarker = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).firstMatch
        XCTAssertTrue(
            firstMarker.waitForExistence(timeout: 10),
            "macOS: MacBacklogRow muss 'overdueMarker_<uuid>' für überfällige Tasks zeigen. "
            + "Bisher fehlt der rote Punkt in MacBacklogRow komplett."
        )
    }

    // MARK: - AC-12 + Kern-Invariante: Genau 3 rote Punkte auf macOS

    /// Verhalten: 3 überfällige Tasks → 3 overdueMarker in macOS Backlog sichtbar.
    /// Bricht wenn: MacBacklogRow Punkt-Logik nicht übereinstimmt mit iOS.
    func test_threeOverdueTasks_threeMarkersVisibleOnMac() throws {
        waitForBacklogLoaded()

        let firstMarker = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).firstMatch
        XCTAssertTrue(
            firstMarker.waitForExistence(timeout: 10),
            "macOS: Mindestens ein overdueMarker_ muss existieren"
        )

        let totalMarkers = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).count
        XCTAssertEqual(
            totalMarkers, 3,
            "macOS Kern-Invariante: Genau 3 rote Punkte für 3 überfällige Tasks"
        )
    }

    // MARK: - AC-11: macOS Sidebar-Badge = iOS Tab-Badge (Plattform-Parität)

    /// Verhalten: macOS Sidebar-Badge zeigt denselben Wert wie iOS Tab-Badge für identische Datenlage.
    /// Bricht wenn: macOS Counter Score-basiert zählt, iOS zeitbasiert — oder einer fehlt ganz.
    ///
    /// Hinweis: macOS Sidebar zeigt Badge-Count als StaticText in der Sidebar-Navigation.
    /// Identifier aus ContentView.swift: 'geparktBadgeCount' existiert für Parkdeck.
    /// Das neue Overdue-Badge für macOS bekommt identifier 'overdueCountBadge' (nach Spec).
    func test_macSidebarBadge_showsThree() throws {
        waitForBacklogLoaded()

        // macOS Sidebar-Badge für überfällige Tasks
        // Nach Refactor: StaticText oder andere Element mit identifier 'overdueCountBadge'
        // oder als Badge im Sidebar-Eintrag (wie 'geparktBadgeCount' für Parkdeck)
        let sidebarBadge = app.staticTexts["overdueCountBadge"]
        XCTAssertTrue(
            sidebarBadge.waitForExistence(timeout: 10),
            "macOS: 'overdueCountBadge' muss in der Sidebar existieren. "
            + "Counter fehlt auf macOS aktuell."
        )

        let badgeText = try XCTUnwrap(
            sidebarBadge.label as String?,
            "overdueCountBadge label muss einen Wert haben"
        )
        XCTAssertEqual(
            badgeText, "3",
            "macOS Sidebar-Badge muss '3' zeigen für 3 überfällige Tasks — Plattform-Parität mit iOS"
        )
    }

    // MARK: - macOS: kein Marker für Tasks ohne dueDate

    /// Verhalten: Tasks ohne dueDate haben keinen roten Punkt auf macOS.
    /// Bricht wenn: MacBacklogRow Punkt falsch rendert.
    func test_macTaskWithoutDueDate_hasNoMarker() throws {
        waitForBacklogLoaded()

        // Gesamt-Anzahl prüfen: nur 3 der 6 Tasks sind überfällig
        let firstMarker = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).firstMatch
        // Falls noch kein Marker existiert, ist dieser Test bereits RED (Feature fehlt)
        // Falls Marker existieren, prüfen wir die Anzahl
        if firstMarker.waitForExistence(timeout: 5) {
            let totalMarkers = app.otherElements.matching(
                NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
            ).count
            XCTAssertEqual(
                totalMarkers, 3,
                "macOS: Nur 3 Marker — Task ohne dueDate und zukünftige Tasks haben KEINEN Marker"
            )
        } else {
            XCTFail(
                "macOS: Kein overdueMarker_ gefunden — MacBacklogRow hat noch keinen roten Punkt. "
                + "Feature muss implementiert werden."
            )
        }
    }
}
