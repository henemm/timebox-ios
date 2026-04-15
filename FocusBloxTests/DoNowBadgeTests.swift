import XCTest
@testable import FocusBlox

/// Bug #223: Badge soll doNow-Tasks (Score >= 60) zählen statt stale Tasks.
/// Prüft dass die Badge-Logik auf Priority Tier basiert, nicht auf Alter/Reschedule.
final class DoNowBadgeTests: XCTestCase {

    // MARK: - Helper

    private func makePlanItem(
        title: String = "Test Task",
        importance: Int? = nil,
        urgency: String? = nil,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        rescheduleCount: Int = 0,
        estimatedDuration: Int? = nil,
        taskType: String = "arbeit",
        isNextUp: Bool = false,
        isCompleted: Bool = false,
        isParked: Bool = false,
        isTemplate: Bool = false,
        assignedFocusBlockID: String? = nil
    ) -> PlanItem {
        let task = LocalTask(
            title: title,
            importance: importance,
            isCompleted: isCompleted,
            dueDate: dueDate,
            createdAt: createdAt,
            estimatedDuration: estimatedDuration,
            urgency: urgency
        )
        task.rescheduleCount = rescheduleCount
        task.isParked = isParked
        task.isTemplate = isTemplate
        task.isNextUp = isNextUp
        task.taskType = taskType
        task.assignedFocusBlockID = assignedFocusBlockID
        return PlanItem(localTask: task)
    }

    // MARK: - doNow Tier Detection

    /// Verhalten: Task mit importance=3 + urgent + überfällig hat Score >= 60 → doNow
    /// Bricht wenn: Badge-Logik nicht auf Tier basiert
    func test_highPriorityTask_isDoNow() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        // Eisenhower 50 + Deadline 25 = 75+ → doNow
        let task = makePlanItem(importance: 3, urgency: "urgent", dueDate: yesterday)
        XCTAssertEqual(task.priorityTier, .doNow, "Importance 3 + urgent + überfällig muss doNow sein")
        XCTAssertGreaterThanOrEqual(task.priorityScore, 60)
    }

    /// Verhalten: Task ohne Attribute hat Score < 60 → nicht doNow
    /// Bricht wenn: Score-Berechnung unerwünschte Defaults hat
    func test_emptyTask_isNotDoNow() {
        let task = makePlanItem()
        XCTAssertNotEqual(task.priorityTier, .doNow, "Task ohne Attribute darf nicht doNow sein")
        XCTAssertLessThan(task.priorityScore, 60)
    }

    /// Verhalten: Überfälliger Task mit hoher Wichtigkeit ist doNow
    /// Bricht wenn: Deadline-Score nicht korrekt addiert
    func test_overdueImportantTask_isDoNow() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = makePlanItem(importance: 3, urgency: "not_urgent", dueDate: yesterday)
        // Eisenhower 38 + Deadline 25 = 63 → doNow
        XCTAssertEqual(task.priorityTier, .doNow)
    }

    // MARK: - countDoNowTasks (neue Funktion)

    /// Verhalten: countDoNowTasks zählt nur Tasks mit Tier doNow
    /// Bricht wenn: Funktion nicht existiert oder falsch filtert
    func test_countDoNowTasks_countsOnlyDoNowTier() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let doNow = makePlanItem(title: "Dringend", importance: 3, urgency: "urgent", dueDate: yesterday)
        let planSoon = makePlanItem(title: "Bald", importance: 2, urgency: "not_urgent")
        let someday = makePlanItem(title: "Irgendwann")

        let count = BacklogBadgeService.countDoNowTasks(in: [doNow, planSoon, someday])
        XCTAssertEqual(count, 1, "Nur der doNow-Task soll gezählt werden")
    }

    /// Verhalten: Erledigte Tasks werden nicht gezählt
    /// Bricht wenn: Filter für isCompleted fehlt
    func test_countDoNowTasks_excludesCompleted() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let done = makePlanItem(title: "Erledigt", importance: 3, urgency: "urgent", dueDate: yesterday, isCompleted: true)
        let count = BacklogBadgeService.countDoNowTasks(in: [done])
        XCTAssertEqual(count, 0, "Erledigte Tasks dürfen nicht gezählt werden")
    }

    /// Verhalten: Geparkte Tasks werden nicht gezählt
    /// Bricht wenn: Filter für isParked fehlt
    func test_countDoNowTasks_excludesParked() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let parked = makePlanItem(title: "Geparkt", importance: 3, urgency: "urgent", dueDate: yesterday, isParked: true)
        let count = BacklogBadgeService.countDoNowTasks(in: [parked])
        XCTAssertEqual(count, 0, "Geparkte Tasks dürfen nicht gezählt werden")
    }

    /// Verhalten: Template-Tasks werden nicht gezählt
    /// Bricht wenn: Filter für isTemplate fehlt
    func test_countDoNowTasks_excludesTemplates() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let template = makePlanItem(title: "Template", importance: 3, urgency: "urgent", dueDate: yesterday, isTemplate: true)
        let count = BacklogBadgeService.countDoNowTasks(in: [template])
        XCTAssertEqual(count, 0, "Templates dürfen nicht gezählt werden")
    }

    /// Verhalten: Leere Liste ergibt 0
    /// Bricht wenn: Edge Case nicht behandelt
    func test_countDoNowTasks_emptyList_returnsZero() {
        let count = BacklogBadgeService.countDoNowTasks(in: [])
        XCTAssertEqual(count, 0)
    }

    /// Verhalten: Mehrere doNow-Tasks werden alle gezählt
    /// Bricht wenn: Zählung abgeschnitten wird
    func test_countDoNowTasks_multipleDoNow_countsAll() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task1 = makePlanItem(title: "Dringend 1", importance: 3, urgency: "urgent", dueDate: yesterday)
        let task2 = makePlanItem(title: "Dringend 2", importance: 3, urgency: "urgent", dueDate: yesterday)
        let task3 = makePlanItem(title: "Normal", importance: 1, urgency: "not_urgent")

        let count = BacklogBadgeService.countDoNowTasks(in: [task1, task2, task3])
        XCTAssertEqual(count, 2, "Beide doNow-Tasks sollen gezählt werden")
    }

    // MARK: - isDoNow Property (für visuelle Markierung)

    /// Verhalten: PlanItem hat isDoNow-Property für BacklogRow-Markierung
    /// Bricht wenn: Property nicht existiert
    func test_planItem_isDoNow_trueForHighScore() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = makePlanItem(importance: 3, urgency: "urgent", dueDate: yesterday)
        XCTAssertTrue(task.isDoNow, "Task mit Score >= 60 muss isDoNow == true haben")
    }

    /// Verhalten: PlanItem.isDoNow ist false für niedrigen Score
    /// Bricht wenn: Schwelle falsch gesetzt
    func test_planItem_isDoNow_falseForLowScore() {
        let task = makePlanItem()
        XCTAssertFalse(task.isDoNow, "Task ohne Score darf nicht isDoNow sein")
    }

    // MARK: - Bug #227: Overdue-Score erhöht (25 → 35)

    /// Verhalten: Überfälliger Task mit "nur dringend" (kein Importance) erreicht doNow
    /// Bricht wenn: Overdue-Score < 35
    func test_overdueUrgentOnly_isDoNow() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        // Eisenhower 25 (nur urgent) + Deadline 35 = 60 → doNow
        let task = makePlanItem(urgency: "urgent", dueDate: yesterday)
        XCTAssertGreaterThanOrEqual(task.priorityScore, 60,
            "Überfälliger + dringender Task muss Score >= 60 haben (Overdue-Score 35)")
        XCTAssertEqual(task.priorityTier, .doNow)
    }

    /// Verhalten: Überfälliger Task mit Imp 1 + urgent erreicht doNow
    /// Bricht wenn: Overdue-Score < 35
    func test_overdueLowImportanceUrgent_isDoNow() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        // Eisenhower 30 (imp1+urgent) + Deadline 35 = 65 → doNow
        let task = makePlanItem(importance: 1, urgency: "urgent", dueDate: yesterday)
        XCTAssertGreaterThanOrEqual(task.priorityScore, 60)
        XCTAssertEqual(task.priorityTier, .doNow)
    }

    /// Verhalten: Überfälliger Task ohne Bewertung bleibt unter doNow
    /// Bricht wenn: Overdue-Score allein >= 60 (zu hoch)
    func test_overdueUnrated_isNotDoNow() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        // Eisenhower 0 + Deadline 35 = 35 → planSoon (+ evtl. Neglect, aber frisch erstellt)
        let task = makePlanItem(dueDate: yesterday)
        XCTAssertLessThan(task.priorityScore, 60,
            "Überfälliger Task ohne Bewertung darf nicht doNow sein")
        XCTAssertNotEqual(task.priorityTier, .doNow)
    }

    /// Verhalten: Überfälliger Task mit Imp 1 + not_urgent bleibt unter doNow
    /// Bricht wenn: Overdue-Score zu hoch
    func test_overdueLowImportanceNotUrgent_isNotDoNow() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        // Eisenhower 10 (imp1+not_urgent) + Deadline 35 = 45 → planSoon
        let task = makePlanItem(importance: 1, urgency: "not_urgent", dueDate: yesterday)
        XCTAssertLessThan(task.priorityScore, 60)
        XCTAssertNotEqual(task.priorityTier, .doNow)
    }

    // MARK: - Bug #227: Badge-Filter Konsistenz

    /// Verhalten: NextUp-Tasks werden nicht im Badge gezählt
    /// Bricht wenn: countDoNowTasks isNextUp nicht filtert
    func test_countDoNowTasks_excludesNextUp() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let nextUp = makePlanItem(title: "NextUp", importance: 3, urgency: "urgent",
                                  dueDate: yesterday, isNextUp: true)
        let count = BacklogBadgeService.countDoNowTasks(in: [nextUp])
        XCTAssertEqual(count, 0, "NextUp-Tasks dürfen nicht im Badge gezählt werden")
    }

    /// Verhalten: Tasks in FocusBlock werden nicht im Badge gezählt
    /// Bricht wenn: countDoNowTasks assignedFocusBlockID nicht filtert
    func test_countDoNowTasks_excludesFocusBlockTasks() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let inBlock = makePlanItem(title: "InBlock", importance: 3, urgency: "urgent",
                                   dueDate: yesterday, assignedFocusBlockID: "block-123")
        let count = BacklogBadgeService.countDoNowTasks(in: [inBlock])
        XCTAssertEqual(count, 0, "Tasks in FocusBlock dürfen nicht im Badge gezählt werden")
    }

    /// Verhalten: Nur sichtbare Backlog-Tasks werden gezählt
    /// Bricht wenn: Filter nicht konsistent mit Backlog-Liste
    func test_countDoNowTasks_onlyCountsVisibleBacklogTasks() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let visible = makePlanItem(title: "Sichtbar", importance: 3, urgency: "urgent", dueDate: yesterday)
        let nextUp = makePlanItem(title: "NextUp", importance: 3, urgency: "urgent",
                                  dueDate: yesterday, isNextUp: true)
        let inBlock = makePlanItem(title: "InBlock", importance: 3, urgency: "urgent",
                                   dueDate: yesterday, assignedFocusBlockID: "block-1")
        let parked = makePlanItem(title: "Geparkt", importance: 3, urgency: "urgent",
                                  dueDate: yesterday, isParked: true)

        let count = BacklogBadgeService.countDoNowTasks(in: [visible, nextUp, inBlock, parked])
        XCTAssertEqual(count, 1, "Nur der sichtbare Backlog-Task soll gezählt werden")
    }
}
