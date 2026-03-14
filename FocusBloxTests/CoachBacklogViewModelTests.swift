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

    /// Verhalten: Eule filtert nur isNextUp Tasks, max 3
    func test_relevantTasks_eule_filtersNextUpOnly() {
        let t1 = makeLocalTask(title: "Next Up", isNextUp: true)
        let t2 = makeLocalTask(title: "Normal")
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "eule")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Next Up")
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

    /// Verhalten: Erledigte Tasks werden NICHT in relevantTasks aufgenommen
    func test_relevantTasks_excludesCompletedTasks() {
        let t1 = makeLocalTask(title: "Done NextUp", isNextUp: true, isCompleted: true)
        let t2 = makeLocalTask(title: "Active NextUp", isNextUp: true)
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "eule")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Active NextUp")
    }

    /// Verhalten: Template-Tasks werden NICHT in relevantTasks aufgenommen
    func test_relevantTasks_excludesTemplateTasks() {
        let t1 = makeLocalTask(title: "Template NextUp", isNextUp: true, isTemplate: true)
        let t2 = makeLocalTask(title: "Active NextUp", isNextUp: true)
        let items = [t1, t2].map { PlanItem(localTask: $0) }

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "eule")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Active NextUp")
    }

    // MARK: - Helper

    private func makeLocalTask(
        title: String = "Test Task",
        isNextUp: Bool = false,
        importance: Int? = nil,
        rescheduleCount: Int = 0,
        taskType: String = "",
        isCompleted: Bool = false,
        isTemplate: Bool = false
    ) -> LocalTask {
        let task = LocalTask(title: title, importance: importance, isCompleted: isCompleted, taskType: taskType)
        task.isNextUp = isNextUp
        task.rescheduleCount = rescheduleCount
        task.isTemplate = isTemplate
        context.insert(task)
        return task
    }
}
