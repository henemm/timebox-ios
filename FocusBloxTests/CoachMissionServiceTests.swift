import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class CoachMissionServiceTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - Helper

    @discardableResult
    private func makeTask(
        title: String = "Test Task",
        isCompleted: Bool = false,
        importance: Int? = nil,
        estimatedDuration: Int? = nil,
        taskType: String = "income",
        rescheduleCount: Int = 0,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        isNextUp: Bool = false,
        nextUpSortOrder: Int? = nil,
        completedAt: Date? = nil,
        aiEnergyLevel: String? = nil
    ) -> PlanItem {
        let task = LocalTask(
            title: title,
            importance: importance,
            isCompleted: isCompleted,
            dueDate: dueDate,
            createdAt: createdAt,
            estimatedDuration: estimatedDuration,
            taskType: taskType,
            nextUpSortOrder: nextUpSortOrder
        )
        container.mainContext.insert(task)
        task.rescheduleCount = rescheduleCount
        task.isNextUp = isNextUp
        task.completedAt = completedAt
        task.aiEnergyLevel = aiEnergyLevel
        return PlanItem(localTask: task)
    }

    // MARK: - Troll Tests

    func test_troll_withProcrastinatedTasks_headlineCountsAll() {
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let tasks = [
            makeTask(title: "Steuererklärung", rescheduleCount: 5, createdAt: old),
            makeTask(title: "Garage aufräumen", rescheduleCount: 3, createdAt: old),
            makeTask(title: "Normal Task", rescheduleCount: 0)
        ]

        let mission = CoachMissionService.generateMission(coach: .troll, allTasks: tasks)

        XCTAssertFalse(mission.isEmpty)
        XCTAssertTrue(mission.headline.contains("2"), "Should count 2 procrastinated, got: \(mission.headline)")
        XCTAssertTrue(mission.detail.contains("Steuererklärung"), "Should name top task, got: \(mission.detail)")
        XCTAssertEqual(mission.progressTotal, 2)
        XCTAssertEqual(mission.progressDone, 0)
        XCTAssertEqual(mission.progressLabel, "angepackt")
    }

    func test_troll_emptyState_saubereSache() {
        let tasks = [
            makeTask(title: "Fresh Task", rescheduleCount: 0)
        ]

        let mission = CoachMissionService.generateMission(coach: .troll, allTasks: tasks)

        XCTAssertTrue(mission.isEmpty)
        XCTAssertTrue(mission.detail.contains("Saubere Sache"), "Got: \(mission.detail)")
    }

    func test_troll_progress_countsCompletedToday() {
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let tasks = [
            makeTask(title: "Open task", rescheduleCount: 5, createdAt: old),
            makeTask(title: "Done today", isCompleted: true, rescheduleCount: 3,
                     createdAt: old, completedAt: Date())
        ]

        let mission = CoachMissionService.generateMission(coach: .troll, allTasks: tasks)

        XCTAssertEqual(mission.progressTotal, 2)
        XCTAssertEqual(mission.progressDone, 1, "One procrastinated task completed today")
    }

    // MARK: - Feuer Tests

    func test_feuer_withBigChallenge_namesTask() {
        let tasks = [
            makeTask(title: "Bewerbung schreiben", importance: 3),
            makeTask(title: "Emails checken", importance: 1)
        ]

        let mission = CoachMissionService.generateMission(coach: .feuer, allTasks: tasks)

        XCTAssertFalse(mission.isEmpty)
        XCTAssertTrue(mission.detail.contains("Bewerbung schreiben"), "Got: \(mission.detail)")
        XCTAssertEqual(mission.progressTotal, 1)
        XCTAssertEqual(mission.progressDone, 0)
    }

    func test_feuer_emptyState_langweilig() {
        let tasks = [
            makeTask(title: "Small Task", importance: 1)
        ]

        let mission = CoachMissionService.generateMission(coach: .feuer, allTasks: tasks)

        XCTAssertTrue(mission.isEmpty)
        XCTAssertTrue(mission.detail.contains("Langweilig"), "Got: \(mission.detail)")
    }

    // MARK: - Eule Tests

    func test_eule_withPlannedTasks_listsNames() {
        let tasks = [
            makeTask(title: "Meeting vorbereiten", isNextUp: true, nextUpSortOrder: 1),
            makeTask(title: "Report schreiben", isNextUp: true, nextUpSortOrder: 2),
            makeTask(title: "Code Review", isNextUp: true, nextUpSortOrder: 3),
            makeTask(title: "Not planned")
        ]

        let mission = CoachMissionService.generateMission(coach: .eule, allTasks: tasks)

        XCTAssertFalse(mission.isEmpty)
        XCTAssertTrue(mission.detail.contains("Meeting vorbereiten"), "Got: \(mission.detail)")
        XCTAssertTrue(mission.detail.contains("Report schreiben"), "Got: \(mission.detail)")
        XCTAssertEqual(mission.progressTotal, 3)
    }

    func test_eule_emptyState_nochNichtGeplant() {
        let tasks = [
            makeTask(title: "Unplanned", isNextUp: false)
        ]

        let mission = CoachMissionService.generateMission(coach: .eule, allTasks: tasks)

        XCTAssertTrue(mission.isEmpty)
        XCTAssertTrue(mission.detail.contains("3 Tasks"), "Got: \(mission.detail)")
    }

    // MARK: - Golem Tests

    func test_golem_imbalanced_mentionsMissingArea() {
        let tasks = [
            makeTask(title: "Work 1", isCompleted: true, taskType: "income", completedAt: Date()),
            makeTask(title: "Work 2", isCompleted: true, taskType: "income", completedAt: Date()),
            makeTask(title: "Yoga", taskType: "recharge"),
            makeTask(title: "Mama anrufen", taskType: "giving_back")
        ]

        let mission = CoachMissionService.generateMission(coach: .golem, allTasks: tasks)

        XCTAssertFalse(mission.isEmpty)
        XCTAssertTrue(mission.progressDone < mission.progressTotal,
                       "done: \(mission.progressDone), total: \(mission.progressTotal)")
    }

    func test_golem_allCovered_schoeneBalance() {
        let tasks = [
            makeTask(title: "Work", isCompleted: true, taskType: "income", completedAt: Date()),
            makeTask(title: "Clean", isCompleted: true, taskType: "maintenance", completedAt: Date()),
            makeTask(title: "Yoga", isCompleted: true, taskType: "recharge", completedAt: Date())
        ]

        let mission = CoachMissionService.generateMission(coach: .golem, allTasks: tasks)

        XCTAssertTrue(mission.isEmpty, "All covered = empty state")
        XCTAssertTrue(mission.detail.contains("Balance"), "Got: \(mission.detail)")
    }

    // MARK: - Progress after completion

    func test_eule_progress_afterCompletion() {
        let tasks = [
            makeTask(title: "Open Task", isNextUp: true, nextUpSortOrder: 1),
            makeTask(title: "Done Task", isCompleted: true, isNextUp: true,
                     nextUpSortOrder: 2, completedAt: Date())
        ]

        let mission = CoachMissionService.generateMission(coach: .eule, allTasks: tasks)

        XCTAssertEqual(mission.progressDone, 1, "One planned task completed today")
        XCTAssertEqual(mission.progressTotal, 2, "Two total planned tasks")
    }
}
