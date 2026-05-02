import XCTest

/// iOS UI Tests für das Overdue-Marker-Rework (Issues #288, #294, #296).
///
/// Kern-Invariante: Counter-Zahl = Anzahl roter Punkte im Backlog. Immer. Ohne Ausnahme.
///
/// /inspect-ui Output (2026-05-01, Backlog-Screen):
/// - Roter Punkt aktuell: identifier 'doNowMarker_<uuid>'
///   → Nach Refactor: 'overdueMarker_<uuid>' (Tests prüfen auf NEU)
/// - Complete-Button: 'completeButton_<uuid>'
/// - Task-Titel: 'taskTitle_<uuid>'
/// - Tab-Navigation: label-basiert (kein identifier), z.B. app.tabBars.buttons["Backlog"]
/// - CollectionView: identifier 'backlogTaskList'
///
/// TDD RED: Tests SCHLAGEN FEHL weil:
/// - 'overdueMarker_<uuid>' noch nicht existiert (aktuell 'doNowMarker_<uuid>')
/// - '--overdue-uitesting' Seed noch nicht implementiert ist
/// - Tab-Badge noch Score-basiert zählt, nicht zeitbasiert
final class OverdueMarkerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // --overdue-uitesting: Seed mit kontrollierten Overdue-Tasks
        //   3 Tasks mit dueDate gestern (überfällig, kein Score)
        //   2 Tasks mit dueDate morgen (nicht überfällig)
        //   1 Task ohne dueDate
        // -UITesting: In-memory Store (kein CloudKit)
        app.launchArguments = ["-UITesting", "--overdue-uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation Helper

    private func navigateToBacklog() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(
            backlogTab.waitForExistence(timeout: 10),
            "Backlog-Tab muss existieren"
        )
        backlogTab.tap()

        let backlogList = app.collectionViews["backlogTaskList"]
        XCTAssertTrue(
            backlogList.waitForExistence(timeout: 10),
            "Backlog-Liste ('backlogTaskList') muss nach Navigation geladen sein"
        )
    }

    // MARK: - AC-6 + Kern-Invariante: Genau 3 rote Punkte sichtbar

    /// Verhalten: 3 Tasks mit dueDate gestern → 3 overdueMarker sichtbar im Backlog.
    /// Bricht wenn:
    ///   (a) overdueMarker_<uuid> nicht existiert (aktuell noch doNowMarker_)
    ///   (b) Marker Score-basiert gezeigt wird statt zeitbasiert
    ///   (c) --overdue-uitesting Seed nicht implementiert
    func test_threeOverdueTasks_threeMarkersVisible() throws {
        try navigateToBacklog()

        // Warte auf ersten overdueMarker (nach Refactor: 'overdueMarker_*')
        let firstMarker = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).firstMatch
        XCTAssertTrue(
            firstMarker.waitForExistence(timeout: 10),
            "Mindestens ein 'overdueMarker_' muss sichtbar sein. "
            + "Aktuell existiert nur 'doNowMarker_' — Refactor fehlt."
        )

        // Kern-Invariante: Exakt 3 Marker für 3 überfällige Tasks
        let allMarkers = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        )
        XCTAssertEqual(
            allMarkers.count, 3,
            "Genau 3 rote Punkte müssen sichtbar sein (3 Tasks mit dueDate gestern)"
        )
    }

    // MARK: - AC-6 + Kern-Invariante: Tab-Badge = 3

    /// Verhalten: iOS Tab-Badge zeigt "3" wenn 3 Tasks überfällig.
    /// Bricht wenn: Tab-Badge Score-basiert zählt statt zeitbasiert
    ///   (ein überfälliger Task ohne Eisenhower-Bewertung würde im alten System nicht gezählt).
    func test_threeOverdueTasks_tabBadgeShowsThree() throws {
        // iOS 26: TabBar.badge wird nicht ueber .value/.label exposed. Stattdessen
        // spiegelt MainTabView den Counter ueber den unsichtbaren StaticText
        // 'iosOverdueCountBadge' (siehe MainTabView.swift). Das ist der gleiche Wert.
        let badge = app.staticTexts["iosOverdueCountBadge"]
        XCTAssertTrue(
            badge.waitForExistence(timeout: 10),
            "iosOverdueCountBadge muss als XCUITest-Mirror des Tab-Badges existieren"
        )

        XCTAssertEqual(
            badge.label, "3",
            "Tab-Badge muss '3' zeigen fuer 3 ueberfaellige Tasks (zeitbasiert nach Refactor)."
        )
    }

    // MARK: - AC-7: Task abhaken → Punkt weg, Counter = 2

    /// Verhalten: Nach dem Abhaken eines überfälligen Tasks verschwindet sein overdueMarker
    /// und der Counter sinkt auf 2.
    /// Bricht wenn: overdueMarker nach Abschluss noch sichtbar, oder Tab-Badge nicht synchron.
    func test_checkingOverdueTask_markerDisappearsAndCounterDecrements() throws {
        try navigateToBacklog()

        // Precondition: 3 Marker müssen vorhanden sein
        let firstMarker = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).firstMatch
        XCTAssertTrue(
            firstMarker.waitForExistence(timeout: 10),
            "Precondition: overdueMarker_ muss existieren vor dem Abhaken"
        )

        let markersBefore = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).count
        XCTAssertEqual(markersBefore, 3, "Precondition: Genau 3 Marker vor dem Abhaken")

        // Ersten Complete-Button tippen
        // Format: completeButton_<uuid> (aus /inspect-ui bestätigt)
        let firstCompleteButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        ).firstMatch
        XCTAssertTrue(
            firstCompleteButton.waitForExistence(timeout: 10),
            "completeButton_<uuid> muss zugänglich sein (aus /inspect-ui bestätigt)"
        )
        firstCompleteButton.tap()

        // Warte auf UI-Aktualisierung: kurzes Polling via XCTNSPredicateExpectation
        let markerCountPredicate = NSPredicate(format: "count == 2")
        let markerQuery = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        )
        let countExpectation = XCTNSPredicateExpectation(
            predicate: markerCountPredicate,
            object: markerQuery
        )
        wait(for: [countExpectation], timeout: 5)

        let markersAfter = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).count
        XCTAssertEqual(
            markersAfter, 2,
            "Nach Abhaken: genau 2 Marker dürfen noch sichtbar sein (Counter -1)"
        )

        // Tab-Badge muss auf 2 gesunken sein — ueber den XCUITest-Mirror geprueft
        let badge = app.staticTexts["iosOverdueCountBadge"]
        let badge2Predicate = NSPredicate(format: "label == '2'")
        let badge2Exp = expectation(for: badge2Predicate, evaluatedWith: badge, handler: nil)
        let result2 = XCTWaiter().wait(for: [badge2Exp], timeout: 10)
        XCTAssertEqual(
            result2, .completed,
            "Tab-Badge muss nach Abhaken auf '2' gesunken sein (label='\(badge.label)') — synchron"
        )
    }

    // MARK: - AC-9: Task ohne dueDate hat keinen overdueMarker

    /// Verhalten: Tasks ohne dueDate haben keinen roten Punkt.
    /// Bricht wenn: overdueMarker für Tasks ohne dueDate erscheint.
    ///
    /// Der --overdue-uitesting Seed enthält einen Task mit Titel '[OVERDUE-MOCK] Task ohne Datum'.
    /// Dieser Task darf KEINEN overdueMarker haben.
    func test_taskWithoutDueDate_hasNoOverdueMarker() throws {
        try navigateToBacklog()

        // Warte bis mindestens ein Marker geladen ist (Seed wurde verarbeitet)
        let firstMarker = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).firstMatch
        XCTAssertTrue(
            firstMarker.waitForExistence(timeout: 10),
            "Mindestens ein overdueMarker muss existieren (Seed geladen)"
        )

        // Pruefung des Negativ-Falls ueber Marker-Anzahl (Kern-Invariante):
        // 3 ueberfaellige Tasks (gestern), 2 zukuenftige (morgen), 1 ohne Datum.
        // Nur die 3 ueberfaelligen duerfen Marker haben — Task ohne Datum NICHT.
        let totalMarkers = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).count
        XCTAssertEqual(
            totalMarkers, 3,
            "Exakt 3 overdueMarker: Task ohne dueDate und Tasks mit zukuenftigem dueDate duerfen KEINEN Marker haben"
        )
    }

    // MARK: - Kein Marker für Tasks mit dueDate morgen

    /// Verhalten: Tasks mit dueDate morgen haben keinen roten Punkt.
    /// Bricht wenn: overdueMarker Score-basiert statt zeitbasiert.
    func test_futureDueDateTasks_haveNoOverdueMarker() throws {
        try navigateToBacklog()

        // Marker-Anzahl prüfen: nur 3 der 6 Tasks sind überfällig
        let firstMarkerExists = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(firstMarkerExists, "overdueMarker_ muss für überfällige Tasks existieren")

        let totalMarkers = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'overdueMarker_'")
        ).count
        XCTAssertEqual(
            totalMarkers, 3,
            "Nur 3 Marker: 2 Tasks mit dueDate morgen und 1 ohne Datum haben KEINEN Marker"
        )
    }
}
