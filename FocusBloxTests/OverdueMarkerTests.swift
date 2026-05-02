import XCTest
import SwiftData
@testable import FocusBlox

/// Tests für das Overdue-Marker-Rework (Issues #288, #294, #296).
///
/// Kern-Invariante: Counter-Zahl = Anzahl roter Punkte im Backlog. Immer. Ohne Ausnahme.
///
/// TDD RED-Strategie:
/// Diese Tests kompilieren gegen die ALTE Implementierung und SCHLAGEN FEHL,
/// weil sie erwarten was die NEUE Implementierung liefern muss:
///
///   AC-6: test_kernInvariante_notificationAndBadgeServiceMustAgree
///         → NotificationService gibt 0 (Score-basiert), Test erwartet 3
///
///   AC-6: test_countDoNowTasks_failsForOverdueTasksWithoutScore
///         → countDoNowTasks gibt 0 (Score < 60), Test erwartet 0 (Bug-Dokumentation)
///
/// Implementation muss nach RED implementieren:
///   PlanItem: var isOverdueNow: Bool
///   BacklogBadgeService: static func countOverdueTasks(_ tasks: [PlanItem]) -> Int
///   NotificationService: countDoNowBadgeTasks delegiert an BacklogBadgeService
final class OverdueMarkerTests: XCTestCase {

    // MARK: - Helper

    private func makeTask(
        title: String = "Test-Task",
        importance: Int? = nil,
        urgency: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        isParked: Bool = false,
        isTemplate: Bool = false,
        isNextUp: Bool = false,
        assignedFocusBlockID: String? = nil,
        stackedInstanceCount: Int = 1
    ) -> PlanItem {
        let local = LocalTask(
            title: title,
            importance: importance,
            isCompleted: isCompleted,
            dueDate: dueDate,
            estimatedDuration: 30,
            urgency: urgency
        )
        local.isParked = isParked
        local.isTemplate = isTemplate
        local.isNextUp = isNextUp
        local.assignedFocusBlockID = assignedFocusBlockID
        var item = PlanItem(localTask: local)
        item.stackedInstanceCount = stackedInstanceCount
        return item
    }

    // MARK: - AC-1/AC-3: isDoNow beweist den Bug (kompiliert gegen alte API)

    /// Verhalten: Task mit dueDate gestern OHNE Score-Attribute ist überfällig.
    /// ALTE Logik (isDoNow) liefert false — das ist der Bug.
    /// NEUE Logik muss isOverdueNow == true liefern.
    ///
    /// Dieser Test dokumentiert den Bug und kompiliert mit alter API.
    /// Nach der Implementation wird dieser Test durch isOverdueNow-Tests ersetzt.
    func test_overdueTaskWithoutScore_isNotDoNow_provingTheBug() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        // Task ohne Score-Attribute (isDoNow == false, Score 0)
        let task = makeTask(dueDate: yesterday)

        // Bug: isDoNow == false für überfälligen Task ohne Score
        // Das bedeutet: kein roter Punkt, nicht im Counter — obwohl Task gestern fällig war
        XCTAssertFalse(task.isDoNow,
            "Bug-Dokumentation (AC-1/AC-3): Überfälliger Task ohne Score ist isDoNow==false. "
            + "Nach Rework muss isOverdueNow==true liefern, unabhängig vom Score.")
        // Nach Rework: dieser Test wird zu XCTAssertTrue(task.isOverdueNow, ...)
    }

    /// Verhalten: Task mit hohem Score + dueDate morgen ist isDoNow — das ist falsch.
    /// Er bekommt einen roten Punkt obwohl er noch nicht fällig ist.
    func test_highScoreTaskWithFutureDueDate_isDoNow_provingTheBug() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = makeTask(importance: 3, urgency: "urgent", dueDate: tomorrow)

        // Bug: isDoNow == true für zukünftigen Task — roter Punkt erscheint zu früh
        XCTAssertTrue(task.isDoNow,
            "Bug-Dokumentation (AC-2): Zukünftiger Task mit hohem Score ist isDoNow==true. "
            + "Nach Rework muss isOverdueNow==false sein.")
        // Nach Rework: dieser Test wird zu XCTAssertFalse(task.isOverdueNow, ...)
    }

    // MARK: - AC-3: Task ohne dueDate

    /// Verhalten: Task ohne dueDate ist nicht isDoNow — bleibt korrekt nach Rework.
    func test_taskWithNilDueDate_isNotDoNow() {
        let task = makeTask(dueDate: nil)
        XCTAssertFalse(task.isDoNow, "Task ohne dueDate darf nicht isDoNow sein")
    }

    // MARK: - AC-6: Kern-Invariante TDD RED

    /// Verhalten: 3 überfällige Tasks ohne Score sollen 3 zählen.
    /// Nach Rework: countOverdueTasks (und countDoNowTasks-Alias) liefern 3.
    func test_countOverdueTasks_returnsThreeForOverdueTasksWithoutScore() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task1 = makeTask(title: "Überfällig 1", dueDate: yesterday)
        let task2 = makeTask(title: "Überfällig 2", dueDate: yesterday)
        let task3 = makeTask(title: "Überfällig 3", dueDate: yesterday)

        // Neue Logik (zeitbasiert): 3 überfällige Tasks → 3
        let count = BacklogBadgeService.countOverdueTasks([task1, task2, task3])
        XCTAssertEqual(count, 3,
            "AC-6: countOverdueTasks muss 3 liefern für 3 überfällige Tasks ohne Score.")

        // Alias bleibt erhalten und liefert denselben Wert
        let aliasCount = BacklogBadgeService.countDoNowTasks(in: [task1, task2, task3])
        XCTAssertEqual(aliasCount, count,
            "countDoNowTasks-Alias muss identische Ergebnisse liefern wie countOverdueTasks.")
    }

    // MARK: - AC-11: Kern-Invariante — beide Counter-Quellen identisch (RED)

    /// Verhalten: NotificationService.countDoNowBadgeTasks und BacklogBadgeService
    /// müssen für identische Datenlage denselben Wert liefern.
    ///
    /// TDD RED: Dieser Test SCHEITERT weil:
    /// - NotificationService (alt): Score-basiert → gibt 0 für Tasks ohne Score
    /// - Nach Rework muss er 3 liefern (zeitbasiert, delegiert an BacklogBadgeService)
    @MainActor
    func test_kernInvariante_notificationServiceCountsZeroForOverdueWithoutScore() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalTask.self, configurations: config)
        let context = ModelContext(container)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // 3 überfällige Tasks OHNE Score-Attribute
        for i in 1...3 {
            let task = LocalTask(title: "Überfällig \(i)", importance: nil, isCompleted: false,
                                 dueDate: yesterday, estimatedDuration: nil, urgency: nil)
            task.isNextUp = false
            task.isParked = false
            task.isTemplate = false
            task.assignedFocusBlockID = nil
            context.insert(task)
        }
        try context.save()

        // Alte Implementierung: Score-basiert → 0 (kein Score → nicht isDoNow)
        let count = NotificationService.countDoNowBadgeTasks(context: context)

        // DIESER TEST SCHEITERT: 0 != 3
        // Das ist die RED-Assertion: alte Logik gibt 0, neue muss 3 geben.
        XCTAssertEqual(count, 3,
            "Kern-Invariante (AC-11): NotificationService MUSS 3 überfällige Tasks ohne Score zählen. "
            + "Aktuell liefert er 0 (Score-basiert). Das ist der Bug der durch das Rework behoben wird.")
    }

    // MARK: - AC-7: Erledigter Task nicht gezählt

    /// Verhalten: Erledigte Tasks werden nicht gezählt.
    /// Mit Score-Attributen damit countDoNowTasks überhaupt reagiert.
    func test_completedTasks_notCounted() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let done = makeTask(title: "Erledigt", importance: 3, urgency: "urgent",
                            dueDate: yesterday, isCompleted: true)
        let count = BacklogBadgeService.countDoNowTasks(in: [done])
        XCTAssertEqual(count, 0, "Erledigte Tasks dürfen nicht gezählt werden")
    }

    // MARK: - AC-10: Recurring Master zählt nur 1x

    /// Verhalten: Recurring Master mit stackedInstanceCount=3 zählt nur einmal.
    /// (Direktes Setup — testet nur, dass ein bereits gestapelter Master nicht doppelt zaehlt.)
    func test_recurringMasterWithStack_countedOnce() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var master = makeTask(title: "Recurring", importance: 3, urgency: "urgent",
                              dueDate: yesterday, stackedInstanceCount: 3)
        let count = BacklogBadgeService.countDoNowTasks(in: [master])
        XCTAssertEqual(count, 1, "Recurring Master muss nur 1x gezählt werden")
    }

    // MARK: - AC-10 (real): Recurring-Stacking realistisch reproduzieren (Issue #302)

    /// Verhalten: 3 echte Recurring-Instanzen (gleiche `recurrenceGroupID`) mit
    /// ueberfaelligem dueDate → countOverdueTasks MUSS 1 liefern (nicht 3).
    ///
    /// Repariert Adversary-Finding: Counter zaehlte alle 3 Instanzen einzeln,
    /// Backlog kollabierte sie aber zu einem Master mit StackingCounterBar
    /// "3 Instanzen" → Counter (3) ≠ rote Punkte (1). Kern-Invariante kaputt.
    func test_recurringStack_realInstances_countedOnce() {
        let groupID = "rec-group-overdue"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

        let task1 = makeRecurringTask(title: "Recurring 1", dueDate: threeDaysAgo, groupID: groupID)
        let task2 = makeRecurringTask(title: "Recurring 2", dueDate: twoDaysAgo, groupID: groupID)
        let task3 = makeRecurringTask(title: "Recurring 3", dueDate: yesterday, groupID: groupID)

        let count = BacklogBadgeService.countOverdueTasks([task1, task2, task3])
        XCTAssertEqual(count, 1,
            "AC-10 (Issue #302): 3 ueberfaellige Recurring-Instanzen werden zu einem "
            + "Master gestapelt → Counter MUSS 1 liefern, nicht 3.")
    }

    /// Edge-Case (Issue #302): Master in Zukunft, aber aeltere Instanzen ueberfaellig.
    /// `RecurringStackingHelper` waehlt das juengste Child als Master. Wenn nur die
    /// AELTEREN Instanzen ueberfaellig sind, ist Master selbst nicht ueberfaellig.
    /// Counter MUSS trotzdem 1 liefern weil `stackedOldestDueDate` < jetzt ist.
    func test_recurringStack_onlyOldInstancesOverdue_stillCountedOnce() {
        let groupID = "rec-group-old-overdue"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        // Aelteste Instanzen ueberfaellig, juengste (=Master) in Zukunft.
        let task1 = makeRecurringTask(title: "Recurring old 1", dueDate: twoDaysAgo, groupID: groupID)
        let task2 = makeRecurringTask(title: "Recurring old 2", dueDate: yesterday, groupID: groupID)
        let task3 = makeRecurringTask(title: "Recurring future master", dueDate: tomorrow, groupID: groupID)

        let count = BacklogBadgeService.countOverdueTasks([task1, task2, task3])
        XCTAssertEqual(count, 1,
            "AC-10 Edge-Case (Issue #302): Master in Zukunft, aeltere Instanzen ueberfaellig — "
            + "Counter MUSS 1 liefern weil StackingCounterBar im Backlog Punkt anzeigt.")
    }

    /// Helper fuer Recurring-Tasks mit gleicher recurrenceGroupID.
    private func makeRecurringTask(title: String, dueDate: Date, groupID: String) -> PlanItem {
        let local = LocalTask(
            title: title,
            importance: nil,
            isCompleted: false,
            dueDate: dueDate,
            estimatedDuration: 30,
            urgency: nil,
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        local.isParked = false
        local.isTemplate = false
        local.isNextUp = false
        local.assignedFocusBlockID = nil
        return PlanItem(localTask: local)
    }

    // MARK: - Bestehende Filter bleiben korrekt (GREEN auch vor Rework)

    /// Verhalten: Geparkte Tasks nicht gezählt.
    func test_parkedTasks_notCounted() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let parked = makeTask(title: "Geparkt", importance: 3, urgency: "urgent",
                              dueDate: yesterday, isParked: true)
        let active = makeTask(title: "Aktiv", importance: 3, urgency: "urgent",
                              dueDate: yesterday, isParked: false)
        let count = BacklogBadgeService.countDoNowTasks(in: [parked, active])
        XCTAssertEqual(count, 1, "Geparkte Tasks dürfen nicht gezählt werden")
    }

    /// Verhalten: NextUp-Tasks nicht gezählt.
    func test_nextUpTasks_notCounted() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let nextUp = makeTask(title: "NextUp", importance: 3, urgency: "urgent",
                              dueDate: yesterday, isNextUp: true)
        let backlog = makeTask(title: "Backlog", importance: 3, urgency: "urgent",
                               dueDate: yesterday, isNextUp: false)
        let count = BacklogBadgeService.countDoNowTasks(in: [nextUp, backlog])
        XCTAssertEqual(count, 1, "NextUp-Tasks dürfen nicht gezählt werden")
    }

    /// Verhalten: Leere Liste ergibt 0.
    func test_emptyList_returnsZero() {
        let count = BacklogBadgeService.countDoNowTasks(in: [])
        XCTAssertEqual(count, 0, "Leere Liste muss 0 ergeben")
    }

    /// Verhalten: FocusBlock-Tasks nicht gezählt.
    func test_focusBlockTasks_notCounted() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let inBlock = makeTask(title: "Im Block", importance: 3, urgency: "urgent",
                               dueDate: yesterday, assignedFocusBlockID: "block-1")
        let backlog = makeTask(title: "Backlog", importance: 3, urgency: "urgent",
                               dueDate: yesterday, assignedFocusBlockID: nil)
        let count = BacklogBadgeService.countDoNowTasks(in: [inBlock, backlog])
        XCTAssertEqual(count, 1, "FocusBlock-Tasks dürfen nicht gezählt werden")
    }

    // MARK: - AC-13/AC-14: Pending-Completion synchron aus Counter ausschliessen

    /// Hilfs-Builder fuer einen sauber konfigurierten ueberfaelligen Task.
    /// Gibt PlanItem zurueck — die UUID-basierte `id` wird vom Test-Code uebernommen.
    private func makeOverdueTask(titleSuffix: String) -> PlanItem {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let local = LocalTask(
            title: "Overdue \(titleSuffix)",
            importance: nil,
            isCompleted: false,
            dueDate: yesterday,
            estimatedDuration: 30,
            urgency: nil
        )
        local.isParked = false
        local.isTemplate = false
        local.isNextUp = false
        local.assignedFocusBlockID = nil
        return PlanItem(localTask: local)
    }

    /// AC-13: Ein Pending-Task wird aus dem Counter ausgeschlossen — Punkt + Counter
    /// verschwinden SOFORT bei Tap auf die Checkbox, nicht erst nach dem 3s-Commit.
    func test_pendingCompletion_excludedFromCount() {
        let task = makeOverdueTask(titleSuffix: "p1")
        let count = BacklogBadgeService.countOverdueTasks(
            [task],
            excludingPendingIDs: [task.id]
        )
        XCTAssertEqual(count, 0,
            "AC-13: Pending-Task darf nicht im Counter sein (Punkt+Badge sofort weg).")
    }

    /// AC-13: Bei mehreren ueberfaelligen Tasks dekrementiert genau der Pending um 1,
    /// die anderen bleiben gezaehlt — kein Off-by-One, kein Komplett-Reset.
    func test_pendingCompletion_withOtherOverdue_decrementsCount() {
        let task1 = makeOverdueTask(titleSuffix: "t1")
        let task2 = makeOverdueTask(titleSuffix: "t2")
        let task3 = makeOverdueTask(titleSuffix: "t3")

        let withoutPending = BacklogBadgeService.countOverdueTasks([task1, task2, task3])
        XCTAssertEqual(withoutPending, 3, "Precondition: alle 3 sind ueberfaellig")

        let withPending = BacklogBadgeService.countOverdueTasks(
            [task1, task2, task3],
            excludingPendingIDs: [task2.id]
        )
        XCTAssertEqual(withPending, 2,
            "AC-13: Counter -1 wenn genau ein Task pending ist; die anderen bleiben.")
    }

    /// AC-14 (Backwards-Compat): Leeres `pendingIDs` darf bestehende Aufrufer
    /// (Tests, NotificationService App-Icon-Badge) nicht veraendern.
    func test_emptyPendingIDs_behavesIdentical() {
        let task = makeOverdueTask(titleSuffix: "x")
        let withDefault = BacklogBadgeService.countOverdueTasks([task])
        let withEmptySet = BacklogBadgeService.countOverdueTasks([task], excludingPendingIDs: [])
        XCTAssertEqual(withDefault, 1, "Sanity: ueberfaelliger Task wird ohne Pending gezaehlt.")
        XCTAssertEqual(withDefault, withEmptySet,
            "AC-14: Default-Argument und explizit leeres Set verhalten sich identisch — "
            + "bestehende Aufrufer bleiben unveraendert.")
    }

    /// AC-14 (Undo-Symmetrie): Wenn der User die Pending-Completion abbricht, wird der
    /// Task wieder gezaehlt — symmetrisch zum Tap. Fuer den Service heisst das schlicht:
    /// gleiche Tasks ohne pendingIDs liefern wieder den vollen Count.
    func test_cancelPending_taskReturnsToCount() {
        let task1 = makeOverdueTask(titleSuffix: "u1")
        let task2 = makeOverdueTask(titleSuffix: "u2")

        // Schritt 1: Tap → Pending → Counter -1
        let duringPending = BacklogBadgeService.countOverdueTasks(
            [task1, task2],
            excludingPendingIDs: [task1.id]
        )
        XCTAssertEqual(duringPending, 1)

        // Schritt 2: Undo → kein Pending mehr → Counter zurueck auf 2
        let afterUndo = BacklogBadgeService.countOverdueTasks(
            [task1, task2],
            excludingPendingIDs: []
        )
        XCTAssertEqual(afterUndo, 2,
            "AC-14: Nach Cancel-Pending kehrt der Task in den Counter zurueck — Undo-Symmetrie.")
    }
}
