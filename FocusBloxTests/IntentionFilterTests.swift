import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests for coach-based backlog filtering.
///
/// Tests the static functions on CoachBacklogViewModel that determine
/// task visibility based on the selected morning coach.
@MainActor
final class CoachTypeFilterTests: XCTestCase {

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

    // MARK: - Helpers

    private func makePlanItem(
        title: String = "Test Task",
        isNextUp: Bool = false,
        importance: Int? = nil,
        rescheduleCount: Int = 0,
        taskType: String = "",
        isCompleted: Bool = false,
        isTemplate: Bool = false
    ) -> PlanItem {
        let task = LocalTask(title: title, importance: importance, isCompleted: isCompleted, taskType: taskType)
        task.isNextUp = isNextUp
        task.rescheduleCount = rescheduleCount
        task.isTemplate = isTemplate
        context.insert(task)
        return PlanItem(localTask: task)
    }

    // MARK: - Troll: rescheduleCount threshold

    /// Verhalten: Troll zeigt nur Tasks mit rescheduleCount >= 2.
    /// Bricht wenn: Schwelle != 2 (z.B. >= 1 oder >= 3).
    func test_troll_rescheduleThresholdIsExactlyTwo() {
        let once = makePlanItem(title: "Once", rescheduleCount: 1)
        let twice = makePlanItem(title: "Twice", rescheduleCount: 2)
        let thrice = makePlanItem(title: "Thrice", rescheduleCount: 3)
        let items = [once, twice, thrice]

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "troll")

        XCTAssertFalse(result.contains { $0.title == "Once" },
            "rescheduleCount 1 should NOT pass troll filter (threshold is 2)")
        XCTAssertTrue(result.contains { $0.title == "Twice" },
            "rescheduleCount 2 should pass troll filter")
        XCTAssertTrue(result.contains { $0.title == "Thrice" },
            "rescheduleCount 3 should pass troll filter")
    }

    // MARK: - Feuer: importance threshold

    /// Verhalten: Feuer zeigt nur Tasks mit importance == 3.
    /// Bricht wenn: Schwelle auf importance >= 2 geaendert wird.
    func test_feuer_importanceThresholdIsExactlyThree() {
        let low = makePlanItem(title: "Low", importance: 1)
        let medium = makePlanItem(title: "Medium", importance: 2)
        let high = makePlanItem(title: "High", importance: 3)
        let items = [low, medium, high]

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "feuer")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "High")
    }

    // MARK: - Eule: NextUp only, max 3

    /// Verhalten: Eule zeigt nur isNextUp Tasks, maximal 3.
    /// Bricht wenn: Max-Limit entfernt oder isNextUp-Filter fehlt.
    func test_eule_maxThreeNextUpTasks() {
        let items = (1...5).map { i in
            makePlanItem(title: "NextUp \(i)", isNextUp: true)
        }

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "eule")

        XCTAssertEqual(result.count, 3, "Eule should show max 3 NextUp tasks")
    }

    /// Verhalten: Eule zeigt KEINE Tasks die nicht NextUp sind.
    /// Bricht wenn: isNextUp-Filter fehlt.
    func test_eule_excludesNonNextUpTasks() {
        let nextUp = makePlanItem(title: "Planned", isNextUp: true)
        let backlog = makePlanItem(title: "Backlog", isNextUp: false)
        let items = [nextUp, backlog]

        let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "eule")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Planned")
    }

    // MARK: - Completed/Template exclusion

    /// Verhalten: Erledigte Tasks werden bei ALLEN Coaches ausgeschlossen.
    /// Bricht wenn: isCompleted-Filter in relevantTasks fehlt.
    func test_allCoaches_excludeCompletedTasks() {
        for coachName in ["troll", "feuer", "eule", "golem"] {
            let completed = makePlanItem(
                title: "Done", isNextUp: true, importance: 3,
                rescheduleCount: 3, isCompleted: true
            )
            let active = makePlanItem(
                title: "Active", isNextUp: true, importance: 3,
                rescheduleCount: 3
            )
            let items = [completed, active]

            let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: coachName)

            XCTAssertFalse(result.contains { $0.title == "Done" },
                "\(coachName) should exclude completed tasks")
        }
    }

    /// Verhalten: Template-Tasks werden bei ALLEN Coaches ausgeschlossen.
    /// Bricht wenn: isTemplate-Filter in relevantTasks fehlt.
    func test_allCoaches_excludeTemplateTasks() {
        for coachName in ["troll", "feuer", "eule", "golem"] {
            let template = makePlanItem(
                title: "Template", isNextUp: true, importance: 3,
                rescheduleCount: 3, isTemplate: true
            )
            let normal = makePlanItem(
                title: "Normal", isNextUp: true, importance: 3,
                rescheduleCount: 3
            )
            let items = [template, normal]

            let result = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: coachName)

            XCTAssertFalse(result.contains { $0.title == "Template" },
                "\(coachName) should exclude template tasks")
        }
    }

    // MARK: - Invalid/empty coach

    /// Verhalten: Ungueltiger Coach-String → leeres Ergebnis.
    /// Bricht wenn: parseCoach unbekannte Werte nicht als nil behandelt.
    func test_invalidCoach_returnsEmpty() {
        let item = makePlanItem(title: "Task", isNextUp: true, importance: 3, rescheduleCount: 5)
        let result = CoachBacklogViewModel.relevantTasks(from: [item], selectedCoach: "nonsense")
        XCTAssertTrue(result.isEmpty, "Invalid coach should return empty relevant tasks")
    }

    // MARK: - otherTasks complement

    /// Verhalten: relevantTasks + otherTasks = alle aktiven Tasks (keine Luecken).
    /// Bricht wenn: Ein Task weder in relevant noch in other erscheint.
    func test_relevantAndOther_coverAllActiveTasks() {
        let items = [
            makePlanItem(title: "Rescheduled", rescheduleCount: 3),
            makePlanItem(title: "Normal"),
            makePlanItem(title: "Important", importance: 3),
        ]

        let relevant = CoachBacklogViewModel.relevantTasks(from: items, selectedCoach: "troll")
        let other = CoachBacklogViewModel.otherTasks(from: items, selectedCoach: "troll")

        let allTitles = Set(relevant.map(\.title) + other.map(\.title))
        let inputTitles = Set(items.map(\.title))
        XCTAssertEqual(allTitles, inputTitles, "relevant + other should cover all input tasks")
    }
}
