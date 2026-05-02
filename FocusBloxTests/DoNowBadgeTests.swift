import XCTest
@testable import FocusBlox

/// Tests für BacklogBadgeService — umgeschrieben für Overdue-Rework (Issues #288, #294, #296).
///
/// VORHER: Tests prüften Score-basierte Logik (isDoNow, Score >= 60).
/// JETZT: Tests dokumentieren den Bug (Score-basiert ist falsch) und erwarten
///        nach dem Rework die zeitbasierte Logik.
///
/// TDD RED: test_countDoNowTasks_givesZeroForOverdueWithoutScore_RedTest SCHEITERT weil
/// countDoNowTasks(in:) 0 zurückgibt für überfällige Tasks ohne Score — aber 3 erwartet werden.
///
/// Nach Implementation muss countOverdueTasks([...]) 3 liefern.
final class DoNowBadgeTests: XCTestCase {

    // MARK: - Helper

    private func makeTask(
        title: String = "Test Task",
        importance: Int? = nil,
        urgency: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        isParked: Bool = false,
        isTemplate: Bool = false,
        isNextUp: Bool = false,
        assignedFocusBlockID: String? = nil
    ) -> PlanItem {
        let task = LocalTask(
            title: title,
            importance: importance,
            isCompleted: isCompleted,
            dueDate: dueDate,
            estimatedDuration: 30,
            urgency: urgency
        )
        task.isParked = isParked
        task.isTemplate = isTemplate
        task.isNextUp = isNextUp
        task.assignedFocusBlockID = assignedFocusBlockID
        return PlanItem(localTask: task)
    }

    // MARK: - TDD RED: Bug-Beweis Tests

    /// Verhalten: 3 überfällige Tasks OHNE Score müssen 3 zählen.
    /// ALTE Logik gibt 0 (Score-basiert).
    /// NEUE Logik (countOverdueTasks) muss 3 geben.
    ///
    /// TDD RED: Dieser Test SCHEITERT weil countDoNowTasks 0 liefert.
    /// Assertion: 0 != 3 → FAIL
    func test_countDoNowTasks_givesZeroForOverdueWithoutScore_RedTest() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // Tasks ohne Score (importance=nil, urgency=nil) — Score = 0, isDoNow = false
        let task1 = makeTask(title: "Überfällig 1", dueDate: yesterday)
        let task2 = makeTask(title: "Überfällig 2", dueDate: yesterday)
        let task3 = makeTask(title: "Überfällig 3", dueDate: yesterday)

        // Alte API gibt 0 (nicht isDoNow → nicht gezählt)
        // Nach Rework: BacklogBadgeService.countOverdueTasks([task1, task2, task3]) == 3
        let count = BacklogBadgeService.countDoNowTasks(in: [task1, task2, task3])

        // DIESE ASSERTION SCHEITERT: countDoNowTasks gibt 0, nicht 3
        // Nach dem Rework (countOverdueTasks) muss count == 3 sein
        XCTAssertEqual(count, 3,
            "TDD RED: überfällige Tasks ohne Score MÜSSEN 3 zählen (zeitbasiert). "
            + "Aktuell gibt countDoNowTasks 0 zurück (Score-basiert). "
            + "Nach Rework: countOverdueTasks muss 3 liefern.")
    }

    /// Verhalten: Überfälliger Task ohne Score ist nicht isDoNow — das ist der Bug.
    /// Nach Rework: isOverdueNow == true (neue Property).
    func test_overdueTaskWithoutScore_isNotIsDoNow_proving_bug() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = makeTask(dueDate: yesterday)  // kein Score → isDoNow == false

        XCTAssertFalse(task.isDoNow,
            "Bug-Beweis: Überfälliger Task ohne Score ist isDoNow==false. "
            + "Nach Rework: task.isOverdueNow == true.")
    }

    /// Verhalten: Task mit hohem Score + dueDate morgen ist isDoNow — das ist der Bug.
    /// Nach Rework: isOverdueNow == false.
    func test_highScoreFutureTask_isDoNow_proving_bug() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = makeTask(importance: 3, urgency: "urgent", dueDate: tomorrow)

        XCTAssertTrue(task.isDoNow,
            "Bug-Beweis: Zukünftiger Task mit hohem Score ist isDoNow==true (erscheint als rot im UI). "
            + "Nach Rework: task.isOverdueNow == false.")
    }

    // MARK: - Bestehende Korrektheit (bleiben GREEN)

    /// Verhalten: Task mit importance=3 + urgent + dueDate gestern hat Score >= 60 → doNow.
    func test_highPriorityTask_isDoNow() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = makeTask(importance: 3, urgency: "urgent", dueDate: yesterday)
        XCTAssertEqual(task.priorityTier, .doNow, "Importance 3 + urgent + überfällig muss doNow sein")
        XCTAssertGreaterThanOrEqual(task.priorityScore, 60)
    }

    /// Verhalten: Task ohne Attribute hat Score < 60 → nicht doNow.
    func test_emptyTask_isNotDoNow() {
        let task = makeTask()
        XCTAssertNotEqual(task.priorityTier, .doNow, "Task ohne Attribute darf nicht doNow sein")
        XCTAssertLessThan(task.priorityScore, 60)
    }

    /// Verhalten: countDoNowTasks zählt nur Tasks mit Tier doNow (alte Semantik, bleibt).
    func test_countDoNowTasks_countsOnlyDoNowTier() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let doNow = makeTask(title: "Dringend", importance: 3, urgency: "urgent", dueDate: yesterday)
        let planSoon = makeTask(title: "Bald", importance: 2, urgency: "not_urgent")
        let someday = makeTask(title: "Irgendwann")

        let count = BacklogBadgeService.countDoNowTasks(in: [doNow, planSoon, someday])
        XCTAssertEqual(count, 1, "Nur der doNow-Task soll gezählt werden")
    }

    /// Verhalten: Erledigte Tasks werden nicht gezählt.
    func test_countDoNowTasks_excludesCompleted() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let done = makeTask(title: "Erledigt", importance: 3, urgency: "urgent",
                            dueDate: yesterday, isCompleted: true)
        let count = BacklogBadgeService.countDoNowTasks(in: [done])
        XCTAssertEqual(count, 0, "Erledigte Tasks dürfen nicht gezählt werden")
    }

    /// Verhalten: Geparkte Tasks werden nicht gezählt.
    func test_countDoNowTasks_excludesParked() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let parked = makeTask(title: "Geparkt", importance: 3, urgency: "urgent",
                              dueDate: yesterday, isParked: true)
        let count = BacklogBadgeService.countDoNowTasks(in: [parked])
        XCTAssertEqual(count, 0, "Geparkte Tasks dürfen nicht gezählt werden")
    }

    /// Verhalten: Template-Tasks werden nicht gezählt.
    func test_countDoNowTasks_excludesTemplates() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let template = makeTask(title: "Template", importance: 3, urgency: "urgent",
                                dueDate: yesterday, isTemplate: true)
        let count = BacklogBadgeService.countDoNowTasks(in: [template])
        XCTAssertEqual(count, 0, "Templates dürfen nicht gezählt werden")
    }

    /// Verhalten: Leere Liste ergibt 0.
    func test_countDoNowTasks_emptyList_returnsZero() {
        let count = BacklogBadgeService.countDoNowTasks(in: [])
        XCTAssertEqual(count, 0)
    }

    /// Verhalten: NextUp-Tasks werden nicht im Badge gezählt.
    func test_countDoNowTasks_excludesNextUp() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let nextUp = makeTask(title: "NextUp", importance: 3, urgency: "urgent",
                              dueDate: yesterday, isNextUp: true)
        let count = BacklogBadgeService.countDoNowTasks(in: [nextUp])
        XCTAssertEqual(count, 0, "NextUp-Tasks dürfen nicht im Badge gezählt werden")
    }

    /// Verhalten: Tasks in FocusBlock werden nicht im Badge gezählt.
    func test_countDoNowTasks_excludesFocusBlockTasks() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let inBlock = makeTask(title: "InBlock", importance: 3, urgency: "urgent",
                               dueDate: yesterday, assignedFocusBlockID: "block-123")
        let count = BacklogBadgeService.countDoNowTasks(in: [inBlock])
        XCTAssertEqual(count, 0, "Tasks in FocusBlock dürfen nicht im Badge gezählt werden")
    }

    /// Verhalten: Nur sichtbare Backlog-Tasks werden gezählt.
    func test_countDoNowTasks_onlyCountsVisibleBacklogTasks() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let visible = makeTask(title: "Sichtbar", importance: 3, urgency: "urgent", dueDate: yesterday)
        let nextUp = makeTask(title: "NextUp", importance: 3, urgency: "urgent",
                              dueDate: yesterday, isNextUp: true)
        let inBlock = makeTask(title: "InBlock", importance: 3, urgency: "urgent",
                               dueDate: yesterday, assignedFocusBlockID: "block-1")
        let parked = makeTask(title: "Geparkt", importance: 3, urgency: "urgent",
                              dueDate: yesterday, isParked: true)

        let count = BacklogBadgeService.countDoNowTasks(in: [visible, nextUp, inBlock, parked])
        XCTAssertEqual(count, 1, "Nur der sichtbare Backlog-Task soll gezählt werden")
    }
}
