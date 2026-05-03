import XCTest

/// UI Tests fuer Feature #293 — "Eigenes Datum" im Verschieben-Dialog
///
/// Geprueft wird das User-Verhalten: Long-Press → Verschieben-Menue →
/// "Eigenes Datum..." → Sheet oeffnet → Datum bestaetigen / abbrechen.
///
/// TDD RED: Alle Tests FEHLSCHLAGEN bis die Implementation existiert,
/// weil customDateMenuButton / customDateSheet noch nicht im UI-Tree sind.
///
/// macOS UI-Tests: pending — kein macOS UI-Test-Target im Projekt vorhanden.
final class CustomDatePostponeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // -UITesting: in-memory Store + seedUITestData (Backlog-Tasks werden angelegt)
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Navigation-Helper

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    /// Long-Press auf den Title-Bereich der ersten Backlog-Row mit Importance-Badge.
    /// Gibt false zurueck wenn kein passender Task gefunden wird.
    @discardableResult
    private func longPressFirstBacklogRow() -> Bool {
        // Echter Identifier-Praefix in Production (TaskBadges.swift): "importanceBadge_<id>".
        // Test-Original verwendete kebab-case 'importance-badge-' — angepasst an
        // den tatsaechlichen Production-Identifier (camelCase mit Underscore).
        let importanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).firstMatch

        guard importanceBadge.waitForExistence(timeout: 5) else {
            return false
        }

        // Offset nach rechts vom Badge → landet auf nicht-interaktivem Title-Bereich,
        // so dass der Context-Menu (parent's .contextMenu) ausgeloest wird.
        let titleArea = importanceBadge.coordinate(
            withNormalizedOffset: CGVector(dx: 4.0, dy: 0.5)
        )
        titleArea.press(forDuration: 1.5)
        return true
    }

    /// Oeffnet das Verschieben-Untermenue (Long-Press → "Verschieben" antippen).
    /// Gibt false zurueck wenn Verschieben-Button nicht gefunden wird.
    @discardableResult
    private func openPostponeSubmenu() -> Bool {
        guard longPressFirstBacklogRow() else { return false }

        // "Verschieben"-Untermenue antippen — Label kann variieren, daher CONTAINS
        let postponeButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Verschieben'")
        ).firstMatch

        guard postponeButton.waitForExistence(timeout: 3) else { return false }
        postponeButton.tap()
        return true
    }

    // MARK: - TEST_01: Menue zeigt "Eigenes Datum..."-Eintrag

    /// Verhalten: Long-Press auf Backlog-Task → Verschieben-Untermenue → Eintrag "Eigenes Datum..."
    ///            mit Identifier customDateMenuButton ist sichtbar
    /// Bricht wenn: BacklogView.postponeMenu() keinen dritten Eintrag mit diesem Identifier hat
    func test_postponeMenu_showsCustomDateOption() throws {
        navigateToBacklog()

        guard openPostponeSubmenu() else {
            XCTFail("Backlog-Row mit Importance-Badge oder Verschieben-Button nicht gefunden")
            return
        }

        let customDateButton = app.buttons["customDateMenuButton"]
        XCTAssertTrue(
            customDateButton.waitForExistence(timeout: 3),
            "Verschieben-Untermenue muss Eintrag 'customDateMenuButton' enthalten (Eigenes Datum...)"
        )
    }

    // MARK: - TEST_02: Tap auf "Eigenes Datum..." oeffnet Sheet

    /// Verhalten: Tap auf customDateMenuButton oeffnet Sheet mit Identifier customDateSheet
    /// Bricht wenn: showCustomDateSheet-State nicht gesetzt wird oder Sheet-Identifier fehlt
    func test_customDateMenu_opensSheet() throws {
        navigateToBacklog()

        guard openPostponeSubmenu() else {
            XCTFail("Backlog-Row oder Verschieben-Button nicht gefunden")
            return
        }

        let customDateButton = app.buttons["customDateMenuButton"]
        guard customDateButton.waitForExistence(timeout: 3) else {
            XCTFail("customDateMenuButton nicht gefunden — Verschieben-Menue hat keinen 'Eigenes Datum...'-Eintrag")
            return
        }
        customDateButton.tap()

        let sheet = app.otherElements["customDateSheet"]
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 2),
            "Nach Tap auf customDateMenuButton muss customDateSheet erscheinen"
        )
    }

    // MARK: - TEST_03: Sheet hat Bestaetigen- und Abbrechen-Button

    /// Verhalten: Geoeffnetes Sheet zeigt beide Aktions-Buttons
    /// Bricht wenn: Sheet-Buttons falschen Identifier haben oder fehlen
    func test_customDateSheet_hasConfirmAndCancel() throws {
        navigateToBacklog()

        guard openPostponeSubmenu() else {
            XCTFail("Kein Backlog-Task gefunden")
            return
        }

        let customDateButton = app.buttons["customDateMenuButton"]
        guard customDateButton.waitForExistence(timeout: 3) else {
            XCTFail("customDateMenuButton nicht gefunden")
            return
        }
        customDateButton.tap()

        let sheet = app.otherElements["customDateSheet"]
        guard sheet.waitForExistence(timeout: 2) else {
            XCTFail("customDateSheet nicht erschienen")
            return
        }

        let confirmButton = app.buttons["customDateConfirmButton"]
        let cancelButton = app.buttons["customDateCancelButton"]

        XCTAssertTrue(
            confirmButton.waitForExistence(timeout: 2),
            "customDateSheet muss 'customDateConfirmButton' enthalten"
        )
        XCTAssertTrue(
            cancelButton.waitForExistence(timeout: 2),
            "customDateSheet muss 'customDateCancelButton' enthalten"
        )
    }

    // MARK: - TEST_04: Abbrechen schliesst Sheet ohne Datenaenderung

    /// Verhalten: Tap auf "Abbrechen" — Sheet schliesst, Task-Datum unveraendert
    /// Bricht wenn: Cancel den State veraendert oder Sheet nicht schliesst
    func test_customDateCancel_dismissesWithoutChange() throws {
        navigateToBacklog()

        // Merke das aktuelle Task-Label vor dem Dialog (erster sichtbarer Task-Titel)
        let firstTaskTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch
        guard firstTaskTitle.waitForExistence(timeout: 5) else {
            XCTFail("Kein Task-Titel im Backlog gefunden")
            return
        }
        let originalLabel = firstTaskTitle.label

        guard openPostponeSubmenu() else {
            XCTFail("Kein Backlog-Task gefunden")
            return
        }

        let customDateButton = app.buttons["customDateMenuButton"]
        guard customDateButton.waitForExistence(timeout: 3) else {
            XCTFail("customDateMenuButton nicht gefunden")
            return
        }
        customDateButton.tap()

        let sheet = app.otherElements["customDateSheet"]
        guard sheet.waitForExistence(timeout: 2) else {
            XCTFail("customDateSheet nicht erschienen")
            return
        }

        // Cancel antippen
        let cancelButton = app.buttons["customDateCancelButton"]
        guard cancelButton.waitForExistence(timeout: 2) else {
            XCTFail("customDateCancelButton nicht gefunden")
            return
        }
        cancelButton.tap()

        // Sheet muss verschwinden
        XCTAssertTrue(
            sheet.waitForNonExistence(timeout: 3),
            "customDateSheet muss nach Cancel geschlossen sein"
        )

        // Task-Titel muss unveraendert sein (Abbrechen darf keine Datenaenderung erzeugen)
        let taskTitleAfter = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch
        guard taskTitleAfter.waitForExistence(timeout: 3) else {
            XCTFail("Task-Titel nach Cancel nicht mehr sichtbar")
            return
        }
        XCTAssertEqual(
            taskTitleAfter.label,
            originalLabel,
            "Task-Titel muss nach Abbrechen unveraendert bleiben"
        )
    }

    // MARK: - TEST_05: Bestaetigen mit Default-Datum setzt neues Datum

    /// Verhalten: Bestaetigen mit Default-Wert (morgen 09:00) — Task hat neues Datum,
    ///            sheet ist geschlossen, Backlog-Row zeigt das neue Datum
    /// Bricht wenn: LocalTask.postpone(_:to:) nicht aufgerufen wird oder UI sich nicht aktualisiert
    func test_customDateConfirm_setsTaskDueDate() throws {
        navigateToBacklog()

        guard openPostponeSubmenu() else {
            XCTFail("Kein Backlog-Task gefunden")
            return
        }

        let customDateButton = app.buttons["customDateMenuButton"]
        guard customDateButton.waitForExistence(timeout: 3) else {
            XCTFail("customDateMenuButton nicht gefunden")
            return
        }
        customDateButton.tap()

        let sheet = app.otherElements["customDateSheet"]
        guard sheet.waitForExistence(timeout: 2) else {
            XCTFail("customDateSheet nicht erschienen")
            return
        }

        // Default-Datum ist bereits vorausgewaehlt (morgen 09:00) — direkt bestaetigen
        let confirmButton = app.buttons["customDateConfirmButton"]
        guard confirmButton.waitForExistence(timeout: 2) else {
            XCTFail("customDateConfirmButton nicht gefunden")
            return
        }
        confirmButton.tap()

        // Sheet muss schliessen
        XCTAssertTrue(
            sheet.waitForNonExistence(timeout: 3),
            "customDateSheet muss nach Bestaetigen geschlossen sein"
        )

        // Nachweis: Backlog-Liste zeigt ein Datum-Label (taskDueDate_*).
        // Das ist der Real-State-Check: dueDate wurde gesetzt und die View hat sich aktualisiert.
        let backlogList = app.collectionViews["backlogTaskList"]
        XCTAssertTrue(
            backlogList.waitForExistence(timeout: 3),
            "Backlog-Liste muss nach Bestaetigen noch sichtbar sein"
        )

        // Datum-Label in der Row muss sichtbar sein — Beweis dass dueDate gesetzt + angezeigt wird.
        // Production-Identifier (TaskBadges.swift): "dueDateBadge_<id>" auf einem HStack-Container —
        // angepasst vom Test-Original "taskDueDate_<id>" auf den tatsaechlichen Identifier
        // und auf .descendants statt .staticTexts (HStack ist ein anderes Element).
        let dateLabel = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'dueDateBadge_'")
        ).firstMatch
        XCTAssertTrue(
            dateLabel.waitForExistence(timeout: 3),
            "Nach Bestaetigen muss mindestens eine Backlog-Row ein Datum-Label (dueDateBadge_*) zeigen — Beweis dass dueDate gesetzt wurde"
        )
    }
}
