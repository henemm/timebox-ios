import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class CoachBacklogViewModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - parseCoach

    /// Verhalten: Leerer String → nil
    func test_parseCoach_emptyString_returnsNil() {
        let coach = CoachBacklogViewModel.parseCoach("")
        XCTAssertNil(coach)
    }

    /// Verhalten: Gültiger rawValue → CoachType
    func test_parseCoach_validValue_returnsCoach() {
        XCTAssertEqual(CoachBacklogViewModel.parseCoach("troll"), .troll)
        XCTAssertEqual(CoachBacklogViewModel.parseCoach("feuer"), .feuer)
        XCTAssertEqual(CoachBacklogViewModel.parseCoach("eule"), .eule)
        XCTAssertEqual(CoachBacklogViewModel.parseCoach("golem"), .golem)
    }

    /// Verhalten: Unbekannter Raw-Value → nil
    func test_parseCoach_invalidValue_returnsNil() {
        let coach = CoachBacklogViewModel.parseCoach("nonsense")
        XCTAssertNil(coach)
    }

    // MARK: - relevantTasks (Troll)

    /// Verhalten: Troll filtert Tasks mit rescheduleCount >= 2
    func test_relevantTasks_troll_filtersRescheduledTasks() {
        let t1 = makeLocalTask(title: "Rescheduled", rescheduleCount: 3)
        let t2 = makeLocalTask(title: "Normal")
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "troll")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Rescheduled")
    }

    // MARK: - relevantTasks (Feuer)

    /// Verhalten: Feuer filtert importance == 3
    func test_relevantTasks_feuer_filtersHighImportance() {
        let t1 = makeLocalTask(title: "Important", importance: 3)
        let t2 = makeLocalTask(title: "Normal", importance: 1)
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "feuer")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Important")
    }

    // MARK: - relevantTasks (Eule)

    /// Verhalten: Eule filtert isNextUp, aber relevantTasks entfernt NextUp (eigene Section)
    /// → Coach-Boost fuer Eule ist immer leer (Design-Limitierung, siehe Backlog)
    func test_relevantTasks_eule_emptyBecauseNextUpHasOwnSection() {
        let t1 = makeLocalTask(title: "Next Up", isNextUp: true)
        let t2 = makeLocalTask(title: "Normal")
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "eule")
        XCTAssertEqual(result.count, 0, "Eule tasks are all NextUp → removed by relevantTasks (NextUp has own section)")
    }

    // MARK: - relevantTasks (Empty coach = empty)

    /// Verhalten: Kein Coach → leeres Array
    func test_relevantTasks_emptyCoach_returnsEmpty() {
        let items = [makeLocalTask(title: "Task")].map { PlanItem(localTask: $0) }
        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - otherTasks

    /// Verhalten: otherTasks enthaelt nur Tasks die NICHT in relevantTasks sind
    func test_otherTasks_excludesRelevantTasks() {
        let t1 = makeLocalTask(title: "Next Up", isNextUp: true)
        let t2 = makeLocalTask(title: "Normal")
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.otherTasks(from: items, selectedCoach: "eule")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Normal")
    }

    /// Verhalten: Kein Coach → alle Tasks in otherTasks
    func test_otherTasks_noCoach_returnsAllTasks() {
        let t1 = makeLocalTask(title: "Task 1")
        let t2 = makeLocalTask(title: "Task 2")
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.otherTasks(from: items, selectedCoach: "")
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Completed/Template filtering

    /// Verhalten: Erledigte Tasks werden NICHT in relevantTasks aufgenommen (Troll-Coach)
    func test_relevantTasks_excludesCompletedTasks() {
        let t1 = makeLocalTask(title: "Done Rescheduled", rescheduleCount: 3, isCompleted: true)
        let t2 = makeLocalTask(title: "Active Rescheduled", rescheduleCount: 3)
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "troll")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Active Rescheduled")
    }

    /// Verhalten: Template-Tasks werden NICHT in relevantTasks aufgenommen (Troll-Coach)
    func test_relevantTasks_excludesTemplateTasks() {
        let t1 = makeLocalTask(title: "Template Rescheduled", rescheduleCount: 3, isTemplate: true)
        let t2 = makeLocalTask(title: "Active Rescheduled", rescheduleCount: 3)
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "troll")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Active Rescheduled")
    }

    // MARK: - nextUpTasks

    /// Verhalten: nextUpTasks gibt nur isNextUp==true Tasks zurueck
    func test_nextUpTasks_returnsOnlyNextUpTasks() {
        let t1 = makeLocalTask(title: "Next 1", isNextUp: true)
        let t2 = makeLocalTask(title: "Normal")
        let t3 = makeLocalTask(title: "Next 2", isNextUp: true)
        let items = [t1, t2, t3].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.nextUpTasks(from: items)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.isNextUp })
    }

    /// Verhalten: nextUpTasks schliesst erledigte Tasks aus
    func test_nextUpTasks_excludesCompletedTasks() {
        let t1 = makeLocalTask(title: "Active NextUp", isNextUp: true)
        let t2 = makeLocalTask(title: "Done NextUp", isNextUp: true, isCompleted: true)
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.nextUpTasks(from: items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Active NextUp")
    }

    /// Verhalten: nextUpTasks schliesst Templates aus
    func test_nextUpTasks_excludesTemplateTasks() {
        let t1 = makeLocalTask(title: "Active NextUp", isNextUp: true)
        let t2 = makeLocalTask(title: "Template NextUp", isNextUp: true, isTemplate: true)
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.nextUpTasks(from: items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Active NextUp")
    }

    /// Verhalten: otherTasks schliesst NextUp-Tasks aus
    func test_otherTasks_excludesNextUpTasks() {
        let t1 = makeLocalTask(title: "Next Up", isNextUp: true)
        let t2 = makeLocalTask(title: "Normal 1")
        let t3 = makeLocalTask(title: "Normal 2")
        let items = [t1, t2, t3].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.otherTasks(from: items, selectedCoach: "troll")
        XCTAssertFalse(result.contains { $0.title == "Next Up" },
                       "otherTasks should exclude NextUp tasks")
        XCTAssertEqual(result.count, 2)
    }

    /// Verhalten: relevantTasks bei Eule schliesst NextUp aus (NextUp hat eigene Section)
    func test_relevantTasks_eule_excludedByNextUpSection() {
        let t1 = makeLocalTask(title: "Next 1", isNextUp: true)
        let t2 = makeLocalTask(title: "Next 2", isNextUp: true)
        let t3 = makeLocalTask(title: "Normal")
        let items = [t1, t2, t3].map { PlanItem(localTask: $0) }

        // NextUp tasks are now in their own section, not in relevantTasks
        let nextUp = CoachBacklogViewModel.nextUpTasks(from: items)
        XCTAssertEqual(nextUp.count, 2)

        // otherTasks should not contain NextUp tasks
        let other = CoachBacklogViewModel.otherTasks(from: items, selectedCoach: "eule")
        XCTAssertFalse(other.contains { $0.isNextUp })
    }

    // MARK: - coachBoostedTasks (P1: Coach-Boost Section)

    /// Verhalten: Coach-Boost gibt Tasks passend zum Coach, OHNE NextUp-Tasks
    func test_coachBoostedTasks_troll_excludesNextUp() {
        let t1 = makeLocalTask(title: "Rescheduled", rescheduleCount: 3)
        let t2 = makeLocalTask(title: "NextUp Rescheduled", isNextUp: true, rescheduleCount: 5)
        let t3 = makeLocalTask(title: "Normal")
        let items = [t1, t2, t3].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.coachBoostedTasks(from: items, selectedCoach: "troll")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Rescheduled")
    }

    /// Verhalten: Coach-Boost Feuer filtert importance==3, ohne NextUp
    func test_coachBoostedTasks_feuer_filtersHighImportance() {
        let t1 = makeLocalTask(title: "Big", importance: 3)
        let t2 = makeLocalTask(title: "Small", importance: 1)
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.coachBoostedTasks(from: items, selectedCoach: "feuer")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Big")
    }

    /// Verhalten: Kein Coach → leeres Array
    func test_coachBoostedTasks_noCoach_empty() {
        let items = [makeLocalTask(title: "Task", rescheduleCount: 5)].map { PlanItem(localTask: $0) }
        let result = CoachBacklogViewModel.coachBoostedTasks(from: items, selectedCoach: "")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - remainingTasks (P1: Tasks MINUS NextUp MINUS Coach-Boost)

    /// Verhalten: Remaining schliesst NextUp UND Coach-Boost aus
    func test_remainingTasks_excludesNextUpAndCoachBoost() {
        let t1 = makeLocalTask(title: "NextUp", isNextUp: true)
        let t2 = makeLocalTask(title: "Boosted", rescheduleCount: 5)
        let t3 = makeLocalTask(title: "Normal")
        let items = [t1, t2, t3].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.remainingTasks(from: items, selectedCoach: "troll")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Normal")
    }

    // MARK: - overdueTasks (P1: Ueberfaellig-Sektion)

    /// Verhalten: Nur Tasks mit dueDate < heute
    func test_overdueTasks_filtersOverdueOnly() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let t1 = makeLocalTask(title: "Overdue", dueDate: yesterday)
        let t2 = makeLocalTask(title: "Future", dueDate: tomorrow)
        let t3 = makeLocalTask(title: "NoDue")
        let items = [t1, t2, t3].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.overdueTasks(from: items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Overdue")
    }

    // MARK: - tierTasks (P1: Priority-Tier-Sections)

    /// Verhalten: tierTasks filtert nach PriorityTier und schliesst excludeIDs aus
    func test_tierTasks_filtersByTierAndExcludesIDs() {
        // importance=3 + urgency="urgent" + dueDate=today → score ~77 → .doNow
        let t1 = makeLocalTask(title: "DoNow", importance: 3, urgency: "urgent", dueDate: Date())
        let t2 = makeLocalTask(title: "Someday")
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let doNow = CoachBacklogViewModel.tierTasks(from: items, tier: .doNow, excludeIDs: [])
        XCTAssertTrue(doNow.contains { $0.title == "DoNow" }, "Score should be ≥60 with importance=3+urgent+dueToday")

        let someday = CoachBacklogViewModel.tierTasks(from: items, tier: .someday, excludeIDs: [])
        XCTAssertTrue(someday.contains { $0.title == "Someday" })
    }

    /// Verhalten: tierTasks schliesst excludeIDs aus (fuer Overdue-Deduplizierung)
    func test_tierTasks_excludesIDs() {
        let t1 = makeLocalTask(title: "Excluded", importance: 3, urgency: "urgent", dueDate: Date())
        let items = [t1].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.tierTasks(from: items, tier: .doNow, excludeIDs: Set(items.map(\.id)))
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - recentTasks (P1: Zuletzt-Ansicht)

    /// Verhalten: Sortiert nach juengstem Datum (createdAt oder modifiedAt)
    func test_recentTasks_sortsByMostRecent() {
        let t1 = makeLocalTask(title: "Old")
        let t2 = makeLocalTask(title: "New")
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.recentTasks(from: items)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.title, "New")
    }

    // MARK: - completedTasks (P1: Erledigt-Ansicht)

    /// Verhalten: Nur erledigte Tasks zurueckgeben
    func test_completedTasks_returnsOnlyCompleted() {
        let t1 = makeLocalTask(title: "Done", isCompleted: true)
        let t2 = makeLocalTask(title: "Open")
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.completedTasks(from: items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Done")
    }

    // MARK: - recurringTasks (P1: Wiederkehrend-Ansicht)

    /// Verhalten: Nur Templates zurueckgeben
    func test_recurringTasks_returnsOnlyTemplates() {
        let t1 = makeLocalTask(title: "Template", isTemplate: true)
        let t2 = makeLocalTask(title: "Normal")
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.recurringTasks(from: items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Template")
    }

    // MARK: - coachSectionTitle (P1: Section-Name)

    /// Verhalten: Section-Name = "Coach.displayName — Coach.subtitle"
    func test_coachSectionTitle_formatsCorrectly() {
        let title = CoachBacklogViewModel.coachSectionTitle(for: "troll")
        XCTAssertEqual(title, "Troll — Der Aufräumer")

        let feuerTitle = CoachBacklogViewModel.coachSectionTitle(for: "feuer")
        XCTAssertEqual(feuerTitle, "Feuer — Der Herausforderer")
    }

    /// Verhalten: Kein Coach → nil
    func test_coachSectionTitle_noCoach_nil() {
        let title = CoachBacklogViewModel.coachSectionTitle(for: "")
        XCTAssertNil(title)
    }

    // MARK: - BUG_107: Blocked Tasks duerfen NICHT als eigenstaendige Eintraege erscheinen

    /// Verhalten: nextUpTasks schliesst blocked Tasks aus (blockerTaskID != nil)
    func test_nextUpTasks_excludesBlockedTasks() {
        let blocker = makeLocalTask(title: "Blocker")
        let blocked = makeLocalTask(title: "Blocked NextUp", isNextUp: true, blockerTaskID: blocker.id)
        let normal = makeLocalTask(title: "Normal NextUp", isNextUp: true)
        let items = [blocker, blocked, normal].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.nextUpTasks(from: items)
        XCTAssertEqual(result.count, 1, "Blocked tasks must not appear in nextUpTasks")
        XCTAssertEqual(result.first?.title, "Normal NextUp")
    }

    /// Verhalten: remainingTasks schliesst blocked Tasks aus
    func test_remainingTasks_excludesBlockedTasks() {
        let blocker = makeLocalTask(title: "Blocker")
        let blocked = makeLocalTask(title: "Blocked", blockerTaskID: blocker.id)
        let normal = makeLocalTask(title: "Normal")
        let items = [blocker, blocked, normal].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.remainingTasks(from: items, selectedCoach: "troll")
        XCTAssertFalse(result.contains { $0.title == "Blocked" },
                       "Blocked tasks must not appear in remainingTasks")
    }

    /// Verhalten: overdueTasks schliesst blocked Tasks aus
    func test_overdueTasks_excludesBlockedTasks() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let blocker = makeLocalTask(title: "Blocker")
        let blocked = makeLocalTask(title: "Blocked Overdue", dueDate: yesterday, blockerTaskID: blocker.id)
        let normal = makeLocalTask(title: "Normal Overdue", dueDate: yesterday)
        let items = [blocker, blocked, normal].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.overdueTasks(from: items)
        XCTAssertEqual(result.count, 1, "Blocked tasks must not appear in overdueTasks")
        XCTAssertEqual(result.first?.title, "Normal Overdue")
    }

    /// Verhalten: recentTasks schliesst blocked Tasks aus
    func test_recentTasks_excludesBlockedTasks() {
        let blocker = makeLocalTask(title: "Blocker")
        let blocked = makeLocalTask(title: "Blocked Recent", blockerTaskID: blocker.id)
        let normal = makeLocalTask(title: "Normal Recent")
        let items = [blocker, blocked, normal].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.recentTasks(from: items)
        XCTAssertFalse(result.contains { $0.title == "Blocked Recent" },
                       "Blocked tasks must not appear in recentTasks")
    }

    // MARK: - Helper

    private func makeLocalTask(
        title: String = "Test Task",
        isNextUp: Bool = false,
        importance: Int? = nil,
        urgency: String? = nil,
        rescheduleCount: Int = 0,
        taskType: String = "",
        isCompleted: Bool = false,
        isTemplate: Bool = false,
        dueDate: Date? = nil,
        blockerTaskID: String? = nil
    ) -> LocalTask {
        let task = LocalTask(title: title, importance: importance, isCompleted: isCompleted, taskType: taskType)
        task.isNextUp = isNextUp
        task.rescheduleCount = rescheduleCount
        task.isTemplate = isTemplate
        task.dueDate = dueDate
        task.urgency = urgency
        task.blockerTaskID = blockerTaskID
        context.insert(task)
        return task
    }
}
