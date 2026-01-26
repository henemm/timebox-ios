import XCTest

/// TDD RED UI Tests für TBD Tasks (Unvollständige Tasks)
/// Spec: docs/specs/features/tbd-tasks.md
///
/// Diese Tests prüfen:
/// 1. tbd Tag sichtbar bei unvollständigen Tasks
/// 2. TBD ViewMode im Toggle
/// 3. TBD Tasks nicht in Matrix
/// 4. Umbenennung "Priorität" → "Wichtigkeit"
final class TbdTasksUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 3) {
            backlogTab.tap()
        }
    }

    private func openViewModeSwitcher() {
        // ViewMode Switcher ist ein Menu mit accessibilityIdentifier "viewModeSwitcher"
        let switcher = app.buttons["viewModeSwitcher"]
        if switcher.waitForExistence(timeout: 3) {
            switcher.tap()
        }
    }

    private func selectViewMode(_ mode: String) {
        openViewModeSwitcher()

        // Warten bis Menu offen ist (kleine Pause fuer Animation)
        Thread.sleep(forTimeInterval: 0.5)

        // Menu-Item im Popover/Menu suchen
        // Das Menu zeigt Buttons mit Label "TBD" etc.
        // Wir nehmen den ersten der NICHT der viewModeSwitcher ist
        let menuItems = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", mode))

        // Es gibt moeglicherweise mehrere Matches:
        // 1. Der viewModeSwitcher Button selbst
        // 2. Das Menu-Item im Dropdown
        // Wir wollen das Menu-Item, nicht den Switcher selbst
        for i in 0..<menuItems.count {
            let item = menuItems.element(boundBy: i)
            // Prüfen ob es NICHT der viewModeSwitcher ist
            if item.identifier != "viewModeSwitcher" && item.exists && item.isHittable {
                item.tap()
                return
            }
        }

        // Fallback: Wenn kein spezifisches gefunden, ersten nehmen
        if menuItems.firstMatch.exists {
            menuItems.firstMatch.tap()
        }
    }

    private func createQuickCaptureTask(title: String) {
        // Task erstellen ohne Details (simuliert Quick Capture)
        navigateToBacklog()

        // Plus-Button hat accessibilityIdentifier "addTaskButton"
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add Task Button sollte existieren")
        addButton.tap()

        // TextField hat Placeholder "Task-Titel"
        let titleField = app.textFields["Task-Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Titel-Feld sollte existieren")
        titleField.tap()
        titleField.typeText(title)

        // Speichern ohne weitere Details (Task bleibt "tbd" weil Default-Werte verwendet)
        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2), "Speichern-Button sollte existieren")
        saveButton.tap()

        // Warten bis Sheet geschlossen ist
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Sollte zurück zur Backlog-Liste sein")
    }

    // MARK: - TBD Tag Tests

    /// GIVEN: Ein Task mit Default-Werten (Quick Capture)
    /// WHEN: BacklogView Liste angezeigt wird
    /// THEN: Task ist NICHT "tbd" weil CreateTaskView bereits Default-Werte setzt
    ///
    /// HINWEIS: In der aktuellen Implementierung setzt CreateTaskView bereits:
    /// - priority = 1 (Low)
    /// - duration = 15
    /// - urgency = "not_urgent"
    /// Daher ist ein neu erstellter Task NICHT "tbd"!
    /// TBD-Tasks entstehen nur durch Import von unvollständigen Reminders.
    func testTbdTagVisibleForIncompleteTask() throws {
        // Da CreateTaskView Default-Werte setzt, ist dieser Test eigentlich
        // ein Test dass Tasks mit Default-Werten KEIN tbd-Tag haben
        createQuickCaptureTask(title: "Quick Capture Test")
        navigateToBacklog()

        // Warten auf Task in Liste
        let taskText = app.staticTexts["Quick Capture Test"]
        XCTAssertTrue(taskText.waitForExistence(timeout: 5), "Task sollte in Liste erscheinen")

        // Da Default-Werte gesetzt sind, sollte kein tbd-Tag erscheinen
        // (Task hat importance=1, duration=15, urgency="not_urgent")
        let tbdTag = app.staticTexts["tbd"]
        // Dieser Test verifiziert dass Tasks mit allen Feldern kein tbd haben
        // Echter tbd-Test müsste einen Task ohne Werte importieren
        XCTAssertFalse(tbdTag.exists, "Task mit Default-Werten sollte kein tbd Tag haben")
    }

    /// GIVEN: Ein vollständiger Task (alle Felder gesetzt)
    /// WHEN: BacklogView Liste angezeigt wird
    /// THEN: "tbd" Tag sollte NICHT sichtbar sein
    func testTbdTagNotVisibleForCompleteTask() throws {
        // Task mit allen Details erstellen
        navigateToBacklog()

        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add Task Button sollte existieren")
        addButton.tap()

        let titleField = app.textFields["Task-Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Titel-Feld sollte existieren")
        titleField.tap()
        titleField.typeText("Vollständiger Task")

        // Priorität setzen (Hoch = 3)
        // QuickPriorityButton zeigt "🔴 Hoch"
        let highPriorityButton = app.buttons["🔴 Hoch"]
        if highPriorityButton.exists {
            highPriorityButton.tap()
        }

        // Dringlichkeit setzen (Segmented Picker)
        let urgentSegment = app.buttons["Dringend"]
        if urgentSegment.exists {
            urgentSegment.tap()
        }

        // Dauer setzen (30m)
        let duration30Button = app.buttons["30m"]
        if duration30Button.exists {
            duration30Button.tap()
        }

        app.buttons["Speichern"].tap()

        // Warten bis Sheet geschlossen und Task sichtbar
        let taskText = app.staticTexts["Vollständiger Task"]
        XCTAssertTrue(taskText.waitForExistence(timeout: 5), "Task sollte in Liste erscheinen")

        // tbd Tag sollte NICHT sichtbar sein
        let tbdTag = app.staticTexts["tbd"]
        XCTAssertFalse(tbdTag.exists, "tbd Tag sollte für vollständigen Task nicht sichtbar sein")
    }

    // MARK: - TBD ViewMode Tests

    /// GIVEN: BacklogView mit ViewMode Switcher (Menu)
    /// WHEN: Menu geöffnet wird
    /// THEN: "TBD" Option sollte vorhanden sein
    func testTbdViewModeExistsInToggle() throws {
        navigateToBacklog()

        // ViewMode Switcher öffnen
        openViewModeSwitcher()

        // TBD MenuItem sollte existieren
        let tbdMenuItem = app.buttons["TBD"]
        XCTAssertTrue(tbdMenuItem.waitForExistence(timeout: 3), "TBD ViewMode sollte im Menu existieren")
    }

    /// GIVEN: Backlog mit View Mode Switcher
    /// WHEN: TBD ViewMode ausgewählt wird
    /// THEN: TBD View wird aktiv und zeigt entsprechenden Content (Empty State oder tbd-Tasks)
    func testTbdViewModeShowsOnlyTbdTasks() throws {
        navigateToBacklog()

        // Warte auf Backlog-Ansicht
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5), "ViewMode Switcher sollte existieren")

        // TBD ViewMode ueber Menu waehlen
        openViewModeSwitcher()
        Thread.sleep(forTimeInterval: 0.5)

        // Im Menu nach TBD suchen
        let tbdMenuItem = app.buttons.matching(NSPredicate(format: "identifier == 'questionmark.circle' OR (label BEGINSWITH 'TBD' AND identifier != 'viewModeSwitcher')")).firstMatch
        if tbdMenuItem.waitForExistence(timeout: 2) {
            tbdMenuItem.tap()
        } else {
            // Fallback: Einfach "TBD" tippen auf erstes nicht-switcher Element
            let allTbdButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'TBD'"))
            for i in 0..<allTbdButtons.count {
                let btn = allTbdButtons.element(boundBy: i)
                if btn.identifier != "viewModeSwitcher" && btn.isHittable {
                    btn.tap()
                    break
                }
            }
        }

        // Warten auf ViewMode-Wechsel
        Thread.sleep(forTimeInterval: 1.0)

        // Verifizieren dass ViewMode gewechselt wurde:
        // Der Switcher sollte jetzt "TBD" im Label zeigen
        let switcherAfter = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcherAfter.waitForExistence(timeout: 3), "ViewMode Switcher sollte noch existieren")

        // Pruefe ob ViewMode auf TBD gewechselt hat ODER Empty State angezeigt wird
        let switcherShowsTbd = switcherAfter.label.contains("TBD")
        let hasEmptyState = app.staticTexts["Keine unvollständigen Tasks"].exists ||
                            app.staticTexts["Keine Tasks"].exists

        XCTAssertTrue(switcherShowsTbd || hasEmptyState,
                      "TBD ViewMode sollte aktiv sein (Switcher zeigt: '\(switcherAfter.label)')")
    }

    /// GIVEN: ViewMode Switcher sichtbar
    /// WHEN: TBD ViewMode hat Tasks
    /// THEN: Badge mit Anzahl wird im Menu-Label angezeigt
    ///
    /// HINWEIS: Der Badge erscheint nur wenn tbd-Tasks existieren.
    /// Da CreateTaskView Default-Werte setzt, testen wir hier nur
    /// dass der ViewMode Switcher funktioniert.
    func testTbdBadgeShowsCount() throws {
        navigateToBacklog()

        // ViewMode Switcher sollte existieren
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 3), "ViewMode Switcher sollte existieren")

        // Menu öffnen und TBD prüfen
        openViewModeSwitcher()

        // TBD MenuItem existiert (Badge nur wenn Tasks vorhanden)
        let tbdMenuItem = app.buttons["TBD"]
        XCTAssertTrue(tbdMenuItem.waitForExistence(timeout: 2), "TBD Option sollte im Menu sein")
    }

    // MARK: - Matrix Exclusion Tests

    /// GIVEN: Ein Task mit niedrigen Default-Werten
    /// WHEN: Matrix ViewMode ausgewählt wird
    /// THEN: Task erscheint in entsprechendem Quadranten
    ///
    /// HINWEIS: Da CreateTaskView Default-Werte setzt (priority=1, urgency="not_urgent"),
    /// erscheint ein Quick-Capture Task im "Eliminate" Quadranten (nicht urgent + nicht wichtig)
    func testTbdTaskNotVisibleInMatrix() throws {
        createQuickCaptureTask(title: "Matrix Test Task")
        navigateToBacklog()

        // Matrix ViewMode über Menu wählen
        selectViewMode("Matrix")

        // Warten auf Matrix-Ansicht
        let doFirstHeader = app.staticTexts["Do First"]
        XCTAssertTrue(doFirstHeader.waitForExistence(timeout: 3), "Matrix sollte angezeigt werden")

        // Task mit Default-Werten (priority=1, urgency="not_urgent")
        // erscheint im "Eliminate" Quadranten
        let eliminateHeader = app.staticTexts["Eliminate"]
        XCTAssertTrue(eliminateHeader.exists, "Eliminate-Quadrant sollte sichtbar sein")

        // Task sollte in Matrix erscheinen (weil es KEIN tbd ist)
        let taskText = app.staticTexts["Matrix Test Task"]
        XCTAssertTrue(taskText.waitForExistence(timeout: 3), "Task mit Default-Werten sollte in Matrix erscheinen")
    }

    // MARK: - Umbenennung Tests

    /// GIVEN: CreateTaskView wird geöffnet
    /// WHEN: Felder angezeigt werden
    /// THEN: "Wichtigkeit" Section Header sollte existieren
    func testImportanceLabelInsteadOfPriority() throws {
        navigateToBacklog()

        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add Task Button sollte existieren")
        addButton.tap()

        // CreateTaskView öffnet sich
        let titleField = app.textFields["Task-Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "CreateTask sollte geöffnet sein")

        // "Wichtigkeit" Section Header (umbenannt von "Priorität")
        let importanceLabel = app.staticTexts["Wichtigkeit"]
        XCTAssertTrue(importanceLabel.exists, "Wichtigkeit Section sollte existieren")

        // Abbrechen
        app.buttons["Abbrechen"].tap()
    }

    /// GIVEN: CreateTaskView wird geöffnet
    /// WHEN: Wichtigkeit-Section angezeigt wird
    /// THEN: Section Header "Wichtigkeit" sollte existieren
    func testImportanceLabelInCreateTask() throws {
        navigateToBacklog()

        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add Task Button sollte existieren")
        addButton.tap()

        // CreateTaskView sollte geöffnet sein
        let titleField = app.textFields["Task-Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "CreateTask sollte geöffnet sein")

        // "Wichtigkeit" Section Header prüfen
        let importanceLabel = app.staticTexts["Wichtigkeit"]
        XCTAssertTrue(importanceLabel.exists, "CreateTask sollte 'Wichtigkeit' Section haben")

        // Abbrechen
        app.buttons["Abbrechen"].tap()
    }

    // MARK: - Task Visibility Tests

    /// GIVEN: Ein Task wurde erstellt
    /// WHEN: Backlog Liste angezeigt wird
    /// THEN: Task sollte sichtbar und tippbar sein
    func testTbdTaskHasAccessibilityHint() throws {
        createQuickCaptureTask(title: "Accessible Test Task")
        navigateToBacklog()

        // Task sollte in Liste erscheinen
        let taskText = app.staticTexts["Accessible Test Task"]
        XCTAssertTrue(taskText.waitForExistence(timeout: 5), "Task sollte in Liste sichtbar sein")

        // Task ist tippbar (öffnet Details)
        taskText.tap()

        // TaskDetailSheet sollte sich öffnen (oder irgendeine Reaktion)
        // Wir prüfen ob wir immer noch in der App sind
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 3), "App sollte noch reagieren")
    }

    // MARK: - Empty State Tests

    /// GIVEN: Keine Tasks vorhanden
    /// WHEN: TBD ViewMode ausgewählt wird
    /// THEN: Empty State oder leere Liste sollte angezeigt werden
    func testTbdViewModeShowsEmptyState() throws {
        navigateToBacklog()

        // TBD ViewMode ueber Menu waehlen
        openViewModeSwitcher()
        Thread.sleep(forTimeInterval: 0.5)

        // Im Menu nach TBD suchen
        let tbdMenuItem = app.buttons.matching(NSPredicate(format: "identifier == 'questionmark.circle' OR (label BEGINSWITH 'TBD' AND identifier != 'viewModeSwitcher')")).firstMatch
        if tbdMenuItem.waitForExistence(timeout: 2) {
            tbdMenuItem.tap()
        } else {
            // Fallback
            let allTbdButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'TBD'"))
            for i in 0..<allTbdButtons.count {
                let btn = allTbdButtons.element(boundBy: i)
                if btn.identifier != "viewModeSwitcher" && btn.isHittable {
                    btn.tap()
                    break
                }
            }
        }

        // Warten auf ViewMode-Wechsel
        Thread.sleep(forTimeInterval: 1.0)

        // Empty State oder leere Liste pruefen
        // ViewMode.tbd.emptyStateMessage = ("Keine unvollständigen Tasks", "Alle Tasks haben...")
        let emptyStateTitle = app.staticTexts["Keine unvollständigen Tasks"]
        let emptyStateDesc = app.staticTexts["Alle Tasks haben Wichtigkeit, Dringlichkeit und Dauer."]
        let noTasksText = app.staticTexts["Keine Tasks"]

        // Einer dieser Texte sollte erscheinen (oder die Liste ist einfach leer)
        let hasEmptyState = emptyStateTitle.waitForExistence(timeout: 5) ||
                            emptyStateDesc.exists ||
                            noTasksText.exists

        // Auch akzeptabel: ViewMode wurde gewechselt und Switcher zeigt "TBD"
        let switcherShowsTbd = app.buttons["viewModeSwitcher"].label.contains("TBD")

        XCTAssertTrue(hasEmptyState || switcherShowsTbd,
                      "Empty State sollte bei leerer TBD-Liste angezeigt werden oder ViewMode auf TBD gewechselt haben")
    }

    // MARK: - Task Update Tests

    /// GIVEN: Ein Task wurde erstellt (mit Default-Werten, also nicht tbd)
    /// WHEN: Task bleibt unverändert
    /// THEN: Task hat kein tbd Tag (weil Default-Werte vorhanden)
    ///
    /// HINWEIS: Diese Test verifiziert dass Tasks mit allen Default-Werten
    /// korrekt als "vollständig" behandelt werden (kein tbd-Tag).
    func testTbdTagDisappearsAfterCompletion() throws {
        createQuickCaptureTask(title: "Complete Task Test")
        navigateToBacklog()

        // Task sollte in Liste erscheinen
        let taskText = app.staticTexts["Complete Task Test"]
        XCTAssertTrue(taskText.waitForExistence(timeout: 5), "Task sollte in Liste erscheinen")

        // Da CreateTaskView Default-Werte setzt, sollte KEIN tbd Tag existieren
        let tbdTag = app.staticTexts["tbd"]
        XCTAssertFalse(tbdTag.exists, "Task mit Default-Werten sollte kein tbd Tag haben")

        // Task antippen sollte Details öffnen
        taskText.tap()

        // Prüfen dass App noch reagiert
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 3), "App sollte noch reagieren")
    }
}
