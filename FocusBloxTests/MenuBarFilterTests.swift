import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests für Bug #289 + #287 — MenuBar-Popover zeigt falsche Aufgaben.
///
/// Testet die noch-nicht-existierende Extension:
///   extension Array where Element == LocalTask {
///       func filteredForMenuBarPopover() -> [LocalTask]
///   }
///
/// ERWARTETER RED-STATUS: Compile-Fehler, weil `filteredForMenuBarPopover()`
/// noch nicht in MenuBarView.swift implementiert ist.
///
/// TDD RED → Tests schlagen fehl → Phase 5 implementiert den Fix → GREEN.
final class MenuBarFilterTests: XCTestCase {

    // MARK: - Helpers

    /// Morgen um Mitternacht (start of tomorrow)
    private var tomorrow: Date {
        let cal = Calendar.current
        return cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date())!)
    }

    /// Heute um Mitternacht (start of today)
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Factory für LocalTask mit sinnvollen Defaults für alle Bug-relevanten Felder.
    /// Ein "normaler" Task der im Popover sichtbar sein MUSS.
    private func makeTask(
        title: String = "Test Task",
        isCompleted: Bool = false,
        recurrencePattern: String = "none",
        dueDate: Date? = nil,
        lifecycleStatus: String = "active",
        isTemplate: Bool = false,
        assignedFocusBlockID: String? = nil,
        blockerTaskID: String? = nil
    ) -> LocalTask {
        let task = LocalTask(
            title: title,
            isCompleted: isCompleted,
            dueDate: dueDate,
            recurrencePattern: recurrencePattern,
            lifecycleStatus: lifecycleStatus
        )
        task.isTemplate = isTemplate
        task.assignedFocusBlockID = assignedFocusBlockID
        task.blockerTaskID = blockerTaskID
        return task
    }

    // MARK: - AK0 — Sanity / Negativ-Test (Silent-Pass-Schutz)

    /// Verhalten: Normaler Task (keine Ausschluss-Kriterien) ist im Filter-Output enthalten.
    /// Bricht wenn: filteredForMenuBarPopover() alle Tasks herausfiltert (Over-filtering).
    /// Zweck: Verhindert Silent-Pass — ein Filter der alles ausblendet wäre immer "GREEN".
    func test_AK0_normalTask_isIncluded() {
        let task = makeTask(title: "Normaler Task")
        let result = [task].filteredForMenuBarPopover()

        XCTAssertEqual(result.count, 1, "Ein normaler Task ohne Ausschluss-Kriterien muss im Popover erscheinen")
        XCTAssertEqual(result.first?.title, "Normaler Task")
    }

    // MARK: - AK1 — Recurring future-dated Task ausgeschlossen

    /// Verhalten: Wiederkehrender Task mit dueDate = morgen → NICHT im Popover.
    /// Bricht wenn: Post-Fetch-Filter isVisibleInBacklog-Check fehlt.
    /// Beweist Bug #289: @Query ohne Post-Fetch-Filter würde diesen Task zeigen.
    func test_AK1_recurringFutureDated_isExcluded() {
        let task = makeTask(
            title: "Recurring morgen",
            recurrencePattern: "weekly",
            dueDate: tomorrow
        )

        // Precondition: isVisibleInBacklog muss false sein (damit der Test den richtigen Pfad testet)
        XCTAssertFalse(task.isVisibleInBacklog, "Precondition: Recurring Task mit future dueDate muss isVisibleInBacklog=false haben")

        let result = [task].filteredForMenuBarPopover()

        XCTAssertEqual(result.count, 0,
            "Wiederkehrender Task mit dueDate=morgen darf NICHT im MenuBar-Popover erscheinen (Bug #289)")
    }

    // MARK: - AK2 — lifecycleStatus "raw" ausgeschlossen

    /// Verhalten: Task mit lifecycleStatus="raw" → NICHT im Popover.
    /// Bricht wenn: lifecycleStatus != "raw" Prüfung im Post-Fetch-Filter fehlt.
    func test_AK2_rawLifecycleStatus_isExcluded() {
        let task = makeTask(
            title: "Roher Entwurfs-Task",
            lifecycleStatus: "raw"
        )

        let result = [task].filteredForMenuBarPopover()

        XCTAssertEqual(result.count, 0,
            "Task mit lifecycleStatus='raw' darf NICHT im MenuBar-Popover erscheinen")
    }

    // MARK: - AK3 — assignedFocusBlockID gesetzt → ausgeschlossen

    /// Verhalten: Task der einem FocusBlock zugewiesen ist → NICHT im Popover-Backlog.
    /// Bricht wenn: assignedFocusBlockID == nil Prüfung im Post-Fetch-Filter fehlt.
    func test_AK3_assignedToFocusBlock_isExcluded() {
        let focusBlockID = UUID().uuidString
        let task = makeTask(
            title: "Task in FocusBlock",
            assignedFocusBlockID: focusBlockID
        )

        let result = [task].filteredForMenuBarPopover()

        XCTAssertEqual(result.count, 0,
            "Task mit assignedFocusBlockID darf NICHT im MenuBar-Popover erscheinen")
    }

    // MARK: - AK4 — Template ausgeschlossen

    /// Verhalten: Task mit isTemplate=true → NICHT im Popover.
    /// Bricht wenn: isVisibleInBacklog-Check fehlt (isTemplate=true → isVisibleInBacklog=false).
    func test_AK4_templateTask_isExcluded() {
        let task = makeTask(
            title: "Recurring Template",
            recurrencePattern: "weekly",
            isTemplate: true
        )

        // Precondition: Templates sind per isVisibleInBacklog immer false
        XCTAssertFalse(task.isVisibleInBacklog, "Precondition: Template muss isVisibleInBacklog=false haben")

        let result = [task].filteredForMenuBarPopover()

        XCTAssertEqual(result.count, 0,
            "Template-Task (isTemplate=true) darf NICHT im MenuBar-Popover erscheinen")
    }

    // MARK: - AK5 — Recurring today → enthalten (Positiv-Test)

    /// Verhalten: Wiederkehrender Task mit dueDate=heute → IM Popover sichtbar.
    /// Bricht wenn: Filter auch Tasks für heute herausfiltert (Over-filtering).
    /// Beweist: Heutiger Recurring Task ist korrekt sichtbar — Zukunft nicht.
    func test_AK5_recurringDueToday_isIncluded() {
        let task = makeTask(
            title: "Recurring heute",
            recurrencePattern: "weekly",
            dueDate: today
        )

        // Precondition: Heutiger recurring Task ist sichtbar
        XCTAssertTrue(task.isVisibleInBacklog, "Precondition: Recurring Task mit dueDate=heute muss isVisibleInBacklog=true haben")

        let result = [task].filteredForMenuBarPopover()

        XCTAssertEqual(result.count, 1,
            "Wiederkehrender Task mit dueDate=heute MUSS im MenuBar-Popover erscheinen")
    }

    // MARK: - AK6 — Neue Recurrence-Instanz nach Completion nicht sichtbar

    /// Verhalten: Nach Abhaken eines Recurring Tasks wird eine neue Instanz mit
    /// future dueDate angelegt — diese erscheint NICHT als "Ersatz" im Popover.
    /// Bricht wenn: Post-Fetch-Filter die neue Instanz nicht herausfiltert (Bug #287).
    ///
    /// Simuliert: Original-Task abgehakt, neue Instanz mit dueDate=morgen angelegt.
    func test_AK6_newRecurrenceInstanceAfterCompletion_isExcluded() {
        // Schritt 1: Original recurring Task (heute fällig) — war sichtbar
        let originalTask = makeTask(
            title: "Wöchentliche Review",
            isCompleted: true,  // User hat abgehakt
            recurrencePattern: "weekly",
            dueDate: today
        )

        // Schritt 2: RecurrenceService legt neue Instanz an — dueDate = nächste Woche
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        let newInstance = makeTask(
            title: "Wöchentliche Review",
            isCompleted: false,
            recurrencePattern: "weekly",
            dueDate: nextWeek
        )

        // Precondition: Neue Instanz hat isVisibleInBacklog=false (future-dated)
        XCTAssertFalse(newInstance.isVisibleInBacklog,
            "Precondition: Neue Recurrence-Instanz mit future dueDate muss isVisibleInBacklog=false sein")

        // Der @Query liefert nur incomplete Tasks → originalTask nicht dabei
        // Der neue Instance ist incomplete → würde ohne Filter erscheinen
        let incompleteTasks = [newInstance]  // simuliert @Query { !$0.isCompleted }
        let result = incompleteTasks.filteredForMenuBarPopover()

        XCTAssertEqual(result.count, 0,
            "Neue Recurrence-Instanz mit future dueDate darf NICHT als 'Ersatz' im Popover erscheinen (Bug #287)")
    }

    // MARK: - AK7 — Filter-Konsistenz mit LocalTaskSource

    /// Verhalten: filteredForMenuBarPopover() und LocalTaskSource.fetchIncompleteTasks()
    /// wenden dieselben Ausschluss-Regeln an — keine Divergenz.
    /// Bricht wenn: einer der beiden Filter eine Regel hinzufügt/entfernt ohne den anderen anzupassen.
    ///
    /// Test-Strategie: Alle problematischen Task-Typen aus Bug #289 werden gegen
    /// filteredForMenuBarPopover() geprüft und müssen denselben Ausschluss-Effekt zeigen,
    /// den LocalTaskSource.fetchIncompleteTasks() (Zeile 45) auch anwendet.
    func test_AK7_filterConsistency_allExcludedTypesMatch() throws {
        // Alle Task-Typen die LocalTaskSource.fetchIncompleteTasks() ausschließt:
        let recurringFuture = makeTask(title: "Recurring Zukunft", recurrencePattern: "weekly", dueDate: tomorrow)
        let rawTask = makeTask(title: "Raw Task", lifecycleStatus: "raw")
        let templateTask = makeTask(title: "Template", recurrencePattern: "weekly", isTemplate: true)
        let assignedTask = makeTask(title: "Assigned", assignedFocusBlockID: UUID().uuidString)
        let blockerTask = makeTask(title: "Blocked", blockerTaskID: UUID().uuidString)

        // Ein normaler Task der durchkommen muss
        let normalTask = makeTask(title: "Normal")

        let allTasks = [recurringFuture, rawTask, templateTask, assignedTask, blockerTask, normalTask]
        let result = allTasks.filteredForMenuBarPopover()

        // Nur normalTask darf durch
        XCTAssertEqual(result.count, 1,
            "filteredForMenuBarPopover() muss exakt dieselben Ausschluss-Regeln wie LocalTaskSource.fetchIncompleteTasks() anwenden")

        let resultTitle = try XCTUnwrap(result.first?.title)
        XCTAssertEqual(resultTitle, "Normal",
            "Nur der normale Task ohne Ausschluss-Kriterien darf im Filter-Output sein")
    }

    // MARK: - Bonus — blockerTaskID gesetzt → ausgeschlossen

    /// Verhalten: Task mit blockerTaskID (blockierter Sub-Task) → NICHT im Popover.
    /// Bricht wenn: blockerTaskID == nil Prüfung im Post-Fetch-Filter fehlt.
    func test_blockedTask_isExcluded() {
        let blockerID = UUID().uuidString
        let task = makeTask(
            title: "Blockierter Sub-Task",
            blockerTaskID: blockerID
        )

        let result = [task].filteredForMenuBarPopover()

        XCTAssertEqual(result.count, 0,
            "Task mit blockerTaskID darf NICHT im MenuBar-Popover erscheinen")
    }
}
