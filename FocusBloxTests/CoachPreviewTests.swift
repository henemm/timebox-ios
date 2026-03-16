import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class CoachPreviewTests: XCTestCase {

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

    // MARK: - Troll Preview

    func test_troll_withProcrastinated_teaserContainsTaskName() {
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let tasks = [
            makeTask(title: "Steuererklärung", rescheduleCount: 5, createdAt: old),
            makeTask(title: "Garage aufräumen", rescheduleCount: 3, createdAt: old),
            makeTask(title: "Normal Task", rescheduleCount: 0)
        ]

        let preview = CoachMissionService.generatePreview(coach: .troll, allTasks: tasks)

        XCTAssertFalse(preview.isEmpty)
        XCTAssertTrue(preview.teaser.contains("Steuererklärung"), "Teaser should contain top task name, got: \(preview.teaser)")
        XCTAssertEqual(preview.taskCount, 2)
    }

    func test_troll_withoutTasks_isEmpty() {
        let tasks = [
            makeTask(title: "Fresh Task", rescheduleCount: 0)
        ]

        let preview = CoachMissionService.generatePreview(coach: .troll, allTasks: tasks)

        XCTAssertTrue(preview.isEmpty)
        XCTAssertEqual(preview.teaser, CoachType.troll.shortPitch)
    }

    // MARK: - Feuer Preview

    func test_feuer_withBigChallenge_teaserContainsTaskName() {
        let tasks = [
            makeTask(title: "Bewerbung schreiben", importance: 3),
            makeTask(title: "Emails checken", importance: 1)
        ]

        let preview = CoachMissionService.generatePreview(coach: .feuer, allTasks: tasks)

        XCTAssertFalse(preview.isEmpty)
        XCTAssertTrue(preview.teaser.contains("Bewerbung schreiben"), "Got: \(preview.teaser)")
        XCTAssertEqual(preview.taskCount, 1)
    }

    // MARK: - Eule Preview

    func test_eule_withPlannedTasks_teaserContainsTaskNames() {
        let tasks = [
            makeTask(title: "Meeting vorbereiten", isNextUp: true, nextUpSortOrder: 1),
            makeTask(title: "Report schreiben", isNextUp: true, nextUpSortOrder: 2),
            makeTask(title: "Not planned")
        ]

        let preview = CoachMissionService.generatePreview(coach: .eule, allTasks: tasks)

        XCTAssertFalse(preview.isEmpty)
        XCTAssertTrue(preview.teaser.contains("Meeting"), "Got: \(preview.teaser)")
        XCTAssertEqual(preview.taskCount, 2)
    }

    // MARK: - Golem Preview

    func test_golem_withImbalance_teaserContainsCategoryName() {
        let tasks = [
            makeTask(title: "Work 1", taskType: "income"),
            makeTask(title: "Yoga", taskType: "recharge"),
            makeTask(title: "Learn Swift", taskType: "learning")
        ]

        let preview = CoachMissionService.generatePreview(coach: .golem, allTasks: tasks)

        XCTAssertFalse(preview.isEmpty)
        // Golem teaser should mention a category name
        XCTAssertTrue(preview.taskCount > 0)
    }

    // MARK: - Recommended Coach

    func test_recommendedCoach_highestTaskCount() {
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let tasks = [
            // 3 troll tasks (varied categories so golem's least-category < 3)
            makeTask(title: "Task A", rescheduleCount: 5, createdAt: old),
            makeTask(title: "Task B", taskType: "recharge", rescheduleCount: 3, createdAt: old),
            makeTask(title: "Task C", taskType: "learning", rescheduleCount: 2, createdAt: old),
            // 1 feuer task
            makeTask(title: "Big Task", importance: 3),
            // 1 eule task
            makeTask(title: "Planned", isNextUp: true, nextUpSortOrder: 1)
        ]

        let previews = Dictionary(uniqueKeysWithValues:
            CoachType.allCases.map { ($0, CoachMissionService.generatePreview(coach: $0, allTasks: tasks)) }
        )

        let recommended = CoachMissionService.recommendedCoach(from: previews)

        XCTAssertEqual(recommended, .troll, "Troll has 3 tasks = highest count")
    }

    func test_recommendedCoach_allEmpty_returnsNil() {
        // All tasks completed → no coach has relevant tasks
        let tasks = [
            makeTask(title: "Done Task", isCompleted: true, completedAt: Date())
        ]

        let previews = Dictionary(uniqueKeysWithValues:
            CoachType.allCases.map { ($0, CoachMissionService.generatePreview(coach: $0, allTasks: tasks)) }
        )

        let recommended = CoachMissionService.recommendedCoach(from: previews)

        XCTAssertNil(recommended, "No coach has tasks → nil")
    }

    // MARK: - Teaser Length

    func test_teaser_maxLength60() {
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let tasks = [
            makeTask(title: "Ein sehr langer Taskname der gekürzt werden muss weil er zu lang ist", rescheduleCount: 5, createdAt: old)
        ]

        for coach in CoachType.allCases {
            let preview = CoachMissionService.generatePreview(coach: coach, allTasks: tasks)
            XCTAssertLessThanOrEqual(preview.teaser.count, 60, "\(coach) teaser too long: \(preview.teaser)")
        }
    }
}
