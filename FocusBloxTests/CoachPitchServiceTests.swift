import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class CoachPitchServiceTests: XCTestCase {

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
        taskType: String = "income",
        rescheduleCount: Int = 0,
        createdAt: Date = Date(),
        isNextUp: Bool = false
    ) -> PlanItem {
        let task = LocalTask(
            title: title,
            importance: importance,
            isCompleted: isCompleted,
            createdAt: createdAt,
            taskType: taskType
        )
        container.mainContext.insert(task)
        task.rescheduleCount = rescheduleCount
        task.isNextUp = isNextUp
        return PlanItem(localTask: task)
    }

    // MARK: - buildPrompt

    func test_buildPrompt_containsCoachNameAndPersonality() {
        let tasks = [makeTask(title: "Steuererklärung", rescheduleCount: 3)]

        let prompt = CoachPitchService.buildPrompt(coach: .troll, allTasks: tasks)

        XCTAssertTrue(prompt.contains("Troll"), "Prompt should contain coach name, got: \(prompt)")
        XCTAssertTrue(prompt.contains(CoachType.troll.personality), "Prompt should contain personality")
    }

    func test_buildPrompt_containsTaskTitles_max3() {
        let tasks = [
            makeTask(title: "Task Eins", rescheduleCount: 3),
            makeTask(title: "Task Zwei", rescheduleCount: 2),
            makeTask(title: "Task Drei", rescheduleCount: 2),
            makeTask(title: "Task Vier", rescheduleCount: 2)
        ]
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let trollTasks = [
            makeTask(title: "Alpha", rescheduleCount: 5, createdAt: old),
            makeTask(title: "Beta", rescheduleCount: 4, createdAt: old),
            makeTask(title: "Gamma", rescheduleCount: 3, createdAt: old),
            makeTask(title: "Delta", rescheduleCount: 2, createdAt: old)
        ]

        let prompt = CoachPitchService.buildPrompt(coach: .troll, allTasks: trollTasks)

        XCTAssertTrue(prompt.contains("Alpha"), "Should contain first task")
        XCTAssertTrue(prompt.contains("Beta"), "Should contain second task")
        XCTAssertTrue(prompt.contains("Gamma"), "Should contain third task")
        XCTAssertFalse(prompt.contains("Delta"), "Should NOT contain fourth task (max 3)")
    }

    func test_buildPrompt_noRelevantTasks_mentionsKeine() {
        let tasks = [
            makeTask(title: "Normal Task", importance: 1, rescheduleCount: 0)
        ]

        let prompt = CoachPitchService.buildPrompt(coach: .troll, allTasks: tasks)

        XCTAssertTrue(prompt.lowercased().contains("keine"), "Should mention 'keine' when no relevant tasks, got: \(prompt)")
    }

    func test_generatePitch_nilWhenAIDisabled() async {
        AppSettings.shared.aiScoringEnabled = false
        let tasks = [makeTask(title: "Task")]

        let result = await CoachPitchService.generatePitch(coach: .troll, allTasks: tasks)

        XCTAssertNil(result, "Should return nil when AI is disabled")
    }

    func test_buildPrompt_feuer_containsChallengeTasks() {
        let tasks = [
            makeTask(title: "Große Präsentation", importance: 3),
            makeTask(title: "Kleine Aufgabe", importance: 1)
        ]

        let prompt = CoachPitchService.buildPrompt(coach: .feuer, allTasks: tasks)

        XCTAssertTrue(prompt.contains("Große Präsentation"), "Should contain the challenge task")
        XCTAssertTrue(prompt.contains("Feuer"), "Should contain coach name")
    }
}
