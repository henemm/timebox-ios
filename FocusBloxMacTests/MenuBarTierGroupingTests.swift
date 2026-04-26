import XCTest
@testable import FocusBloxMac

/// Unit Tests fuer Bug #290: MenuBar-Popover Sortierung & Tier-Sektionen.
///
/// Das Feature: Das macOS MenuBar-Popover gruppiert Backlog-Tasks in
/// "Heute" / "Ueberfaellig" / "Dringend" — analog zum Hauptfenster, aber
/// mit globalem 9-Task-Limit ueber alle Sektionen.
///
/// TDD RED: Diese Tests MUESSEN fehlschlagen weil `MenuBarBacklogGrouping`
/// und `LocalTask.priorityTier`-Extension noch nicht existieren.
@MainActor
final class MenuBarTierGroupingTests: XCTestCase {

    // MARK: - Test Fixtures

    /// Erzeugt einen LocalTask mit gegebenen Eigenschaften (alle anderen Defaults).
    private func makeTask(
        title: String,
        importance: Int? = nil,
        urgency: String? = nil,
        dueDate: Date? = nil,
        isNextUp: Bool = false,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) -> LocalTask {
        let task = LocalTask(
            title: title,
            importance: importance,
            isCompleted: isCompleted,
            dueDate: dueDate,
            createdAt: createdAt,
            urgency: urgency
        )
        task.isNextUp = isNextUp
        return task
    }

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }
    private var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: startOfToday)! }
    private var twoDaysAgo: Date { Calendar.current.date(byAdding: .day, value: -2, to: startOfToday)! }

    // MARK: - LocalTask Extension Tests

    /// Bricht wenn: `LocalTask.priorityTier` Extension fehlt in Sources/Extensions/
    func test_localTask_hasPriorityTierProperty() {
        // importance=3 + urgent (Eisenhower 50) + dueDate=heute (Deadline 35) = 87 → .doNow
        let task = makeTask(title: "doNow Task",
                            importance: 3,
                            urgency: "urgent",
                            dueDate: Date())
        XCTAssertEqual(task.priorityTier, .doNow,
                       "importance=3 + urgent + due heute ergibt Tier .doNow (Score >=60)")
    }

    /// Bricht wenn: `LocalTask.priorityScore` Extension fehlt in Sources/Extensions/
    func test_localTask_hasPriorityScoreProperty() {
        let task = makeTask(title: "Score Test", importance: 3, urgency: "urgent")
        let expected = TaskPriorityScoringService.calculateScore(
            importance: task.importance, urgency: task.urgency, dueDate: task.dueDate,
            createdAt: task.createdAt, rescheduleCount: task.rescheduleCount,
            estimatedDuration: task.estimatedDuration, taskType: task.taskType,
            isNextUp: task.isNextUp, dependentTaskCount: 0
        )
        XCTAssertEqual(task.priorityScore, expected,
                       "Extension priorityScore muss identisch zu PlanItem.priorityScore sein")
    }

    // MARK: - Grouping: Heute Section

    /// Bricht wenn: MenuBarBacklogGrouping fehlt oder `heute` falsch befuellt.
    func test_grouping_heuteContainsOnlyNextUpTasks() {
        let nextUp = makeTask(title: "Heute Task", importance: 2, isNextUp: true)
        let backlog = makeTask(title: "Backlog Task", importance: 2, isNextUp: false)

        let result = MenuBarBacklogGrouping.group(tasks: [nextUp, backlog])

        XCTAssertEqual(result.heute.map(\.title), ["Heute Task"],
                       "Heute-Sektion enthaelt nur isNextUp-Tasks")
        XCTAssertFalse(result.ueberfaellig.contains(where: { $0.uuid == nextUp.uuid }),
                       "Heute-Task darf nicht in Ueberfaellig erscheinen")
        XCTAssertFalse(result.dringend.contains(where: { $0.uuid == nextUp.uuid }),
                       "Heute-Task darf nicht in Dringend erscheinen")
    }

    // MARK: - Grouping: Ueberfaellig Section

    /// Bricht wenn: Ueberfaellige Tasks landen in Dringend statt eigener Sektion.
    func test_grouping_ueberfaelligContainsTasksWithDueBeforeToday() {
        let overdue = makeTask(title: "Overdue", importance: 2, dueDate: yesterday)
        let dueToday = makeTask(title: "Today",
                                 importance: 2,
                                 dueDate: Date().addingTimeInterval(3600))
        let noDate = makeTask(title: "NoDate", importance: 2)

        let result = MenuBarBacklogGrouping.group(tasks: [overdue, dueToday, noDate])

        XCTAssertEqual(result.ueberfaellig.map(\.title), ["Overdue"],
                       "Nur Tasks mit due < startOfToday gehoeren in Ueberfaellig")
    }

    /// Bricht wenn: Erledigte ueberfaellige Tasks taucht trotzdem auf.
    func test_grouping_ueberfaelligExcludesCompleted() {
        let completed = makeTask(title: "Done Overdue",
                                  importance: 3,
                                  dueDate: yesterday,
                                  isCompleted: true)

        let result = MenuBarBacklogGrouping.group(tasks: [completed])

        XCTAssertTrue(result.ueberfaellig.isEmpty,
                      "Completed Tasks gehoeren NICHT in Ueberfaellig")
    }

    /// Bricht wenn: Heute-Tasks (isNextUp) auch in Ueberfaellig erscheinen.
    func test_grouping_ueberfaelligExcludesNextUp() {
        let overdueButNextUp = makeTask(title: "OverdueAndScheduled",
                                         importance: 3,
                                         dueDate: yesterday,
                                         isNextUp: true)

        let result = MenuBarBacklogGrouping.group(tasks: [overdueButNextUp])

        XCTAssertTrue(result.ueberfaellig.isEmpty,
                      "isNextUp-Tasks gehoeren in Heute, nicht in Ueberfaellig")
        XCTAssertEqual(result.heute.map(\.title), ["OverdueAndScheduled"])
    }

    // MARK: - Grouping: Dringend Section

    /// Bricht wenn: Dringend nicht ueber Tier .doNow filtert.
    func test_grouping_dringendContainsOnlyDoNowTier() {
        // Score 87 (>=60 = .doNow) ohne Ueberfaelligkeit (due=heute)
        let doNow = makeTask(title: "DoNow",
                             importance: 3, urgency: "urgent",
                             dueDate: Date())
        let planSoon = makeTask(title: "PlanSoon", importance: 2)
        let someday = makeTask(title: "Someday")

        let result = MenuBarBacklogGrouping.group(tasks: [doNow, planSoon, someday])

        XCTAssertEqual(result.dringend.map(\.title), ["DoNow"],
                       "Dringend enthaelt nur Tier .doNow")
    }

    /// Bricht wenn: Ueberfaellige .doNow-Tasks doppelt erscheinen.
    func test_grouping_dringendExcludesOverdue() {
        let overdueDoNow = makeTask(title: "OverdueDoNow",
                                     importance: 3, urgency: "urgent",
                                     dueDate: yesterday)

        let result = MenuBarBacklogGrouping.group(tasks: [overdueDoNow])

        XCTAssertEqual(result.ueberfaellig.map(\.title), ["OverdueDoNow"],
                       "Ueberfaellige Tasks landen in Ueberfaellig")
        XCTAssertTrue(result.dringend.isEmpty,
                      "Ueberfaellige Tasks erscheinen NICHT zusaetzlich in Dringend")
    }

    // MARK: - Bald / Spaeter (Out of Scope)

    /// Bricht wenn: planSoon/eventually/someday Tasks im Popover erscheinen.
    func test_grouping_baldAndSpaeterTasksAreOmittedEntirely() {
        let planSoon = makeTask(title: "PlanSoon", importance: 2)
        let eventually = makeTask(title: "Eventually", importance: 1)

        let result = MenuBarBacklogGrouping.group(tasks: [planSoon, eventually])

        XCTAssertTrue(result.heute.isEmpty)
        XCTAssertTrue(result.ueberfaellig.isEmpty)
        XCTAssertTrue(result.dringend.isEmpty,
                      "Bald/Spaeter-Tasks duerfen NICHT im Popover auftauchen")
    }

    // MARK: - Sortierung innerhalb Sektion

    /// Bricht wenn: Innerhalb einer Sektion nicht nach Score absteigend sortiert.
    func test_grouping_sortsBySectionByPriorityScoreDescending() {
        let highScore = makeTask(title: "High",
                                  importance: 3, urgency: "urgent",
                                  dueDate: yesterday)
        let lowScore = makeTask(title: "Low",
                                 importance: 1,
                                 dueDate: yesterday)

        let result = MenuBarBacklogGrouping.group(tasks: [lowScore, highScore])

        XCTAssertEqual(result.ueberfaellig.map(\.title), ["High", "Low"],
                       "Sortierung innerhalb Ueberfaellig: Score absteigend")
    }

    // MARK: - 9-Task-Limit

    /// Bricht wenn: Mehr als 9 Tasks total ausgegeben werden.
    func test_grouping_neverExceedsNineTasksTotal() {
        let manyHeute = (0..<5).map {
            makeTask(title: "Heute_\($0)", importance: 2, isNextUp: true)
        }
        let manyOverdue = (0..<10).map {
            makeTask(title: "Overdue_\($0)", importance: 2, dueDate: yesterday)
        }
        let manyDringend = (0..<10).map {
            makeTask(title: "Dringend_\($0)", importance: 3, urgency: "urgent")
        }

        let result = MenuBarBacklogGrouping.group(tasks: manyHeute + manyOverdue + manyDringend)

        let total = result.heute.count + result.ueberfaellig.count + result.dringend.count
        XCTAssertLessThanOrEqual(total, 9,
                                 "Niemals mehr als 9 Tasks insgesamt im Popover")
    }

    /// Bricht wenn: Auffuell-Reihenfolge ist nicht Heute → Ueberfaellig → Dringend.
    func test_grouping_fillsHeuteFirstThenOverdueThenDringend() {
        // 3 Heute + 4 Ueberfaellig + 5 Dringend = 12, Limit 9
        // Dringend braucht due=heute damit Score >=60 (.doNow), aber NICHT ueberfaellig
        let heute = (0..<3).map { makeTask(title: "H_\($0)", importance: 2, isNextUp: true) }
        let overdue = (0..<4).map { makeTask(title: "O_\($0)", importance: 2, dueDate: yesterday) }
        let dringend = (0..<5).map {
            makeTask(title: "D_\($0)", importance: 3, urgency: "urgent", dueDate: Date())
        }

        let result = MenuBarBacklogGrouping.group(tasks: heute + overdue + dringend)

        XCTAssertEqual(result.heute.count, 3, "Heute komplett (3)")
        XCTAssertEqual(result.ueberfaellig.count, 4, "Ueberfaellig komplett (4)")
        XCTAssertEqual(result.dringend.count, 2, "Dringend nur 2 (Limit erreicht bei 9)")
    }

    /// Bricht wenn: Limit innerhalb Heute wird ignoriert (Ueberfaellig erscheint trotzdem).
    func test_grouping_omitsLaterSectionsWhenEarlierSectionFillsLimit() {
        // 12 Heute → Limit 9 erreicht in Heute, keine andere Sektion
        let manyHeute = (0..<12).map {
            makeTask(title: "Heute_\($0)", importance: 2, isNextUp: true)
        }
        let overdue = makeTask(title: "Overdue", importance: 3, dueDate: yesterday)
        let dringend = makeTask(title: "Dringend", importance: 3, urgency: "urgent")

        let result = MenuBarBacklogGrouping.group(tasks: manyHeute + [overdue, dringend])

        XCTAssertEqual(result.heute.count, 9, "Heute auf 9 limitiert")
        XCTAssertTrue(result.ueberfaellig.isEmpty,
                      "Ueberfaellig leer wenn Limit in Heute erreicht")
        XCTAssertTrue(result.dringend.isEmpty,
                      "Dringend leer wenn Limit in Heute erreicht")
    }

    // MARK: - "+M more" Counter

    /// Bricht wenn: Counter zaehlt Heute mit (Henning: nur Backlog-Tasks zaehlen).
    func test_grouping_abgeschnittenCounterExcludesHeute() {
        // 12 Heute → 3 abgeschnitten, aber Heute zaehlt nicht
        let manyHeute = (0..<12).map {
            makeTask(title: "Heute_\($0)", importance: 2, isNextUp: true)
        }

        let result = MenuBarBacklogGrouping.group(tasks: manyHeute)

        XCTAssertEqual(result.abgeschnittenCount, 0,
                       "Heute-Tasks zaehlen NICHT als 'abgeschnitten' (nur Backlog)")
    }

    /// Bricht wenn: Counter falsch berechnet bei abgeschnittenen Backlog-Tasks.
    func test_grouping_abgeschnittenCounterCountsBacklogOverflow() {
        // 0 Heute, 4 Ueberfaellig, 10 Dringend → 14 Backlog total
        // Limit 9 → 9 angezeigt → 5 abgeschnitten
        // Dringend braucht due=heute fuer Score >=60 (.doNow), aber NICHT ueberfaellig
        let overdue = (0..<4).map { makeTask(title: "O_\($0)", importance: 2, dueDate: yesterday) }
        let dringend = (0..<10).map {
            makeTask(title: "D_\($0)", importance: 3, urgency: "urgent", dueDate: Date())
        }

        let result = MenuBarBacklogGrouping.group(tasks: overdue + dringend)

        let displayedBacklog = result.ueberfaellig.count + result.dringend.count
        XCTAssertEqual(displayedBacklog, 9, "9 Backlog-Tasks angezeigt")
        XCTAssertEqual(result.abgeschnittenCount, 5,
                       "14 Backlog total minus 9 angezeigt = 5 abgeschnitten")
    }

    /// Bricht wenn: Counter > 0 obwohl alles passt.
    func test_grouping_abgeschnittenCounterIsZeroWhenNothingTruncated() {
        let overdue = makeTask(title: "O", importance: 2, dueDate: yesterday)
        // Dringend braucht due=heute fuer Score >=60 (.doNow), aber NICHT ueberfaellig
        let dringend = makeTask(title: "D",
                                 importance: 3, urgency: "urgent",
                                 dueDate: Date())

        let result = MenuBarBacklogGrouping.group(tasks: [overdue, dringend])

        XCTAssertEqual(result.abgeschnittenCount, 0,
                       "Counter = 0 wenn alle Backlog-Tasks reinpassen")
    }

    // MARK: - Konfigurierbares Limit (Test-Konsistenz)

    /// Bricht wenn: Limit-Parameter wird ignoriert.
    func test_grouping_respectsCustomLimit() {
        let overdue = (0..<5).map { makeTask(title: "O_\($0)", importance: 2, dueDate: yesterday) }

        let result = MenuBarBacklogGrouping.group(tasks: overdue, limit: 3)

        XCTAssertEqual(result.ueberfaellig.count, 3, "Limit von 3 wird respektiert")
        XCTAssertEqual(result.abgeschnittenCount, 2, "5 - 3 = 2 abgeschnitten")
    }
}
