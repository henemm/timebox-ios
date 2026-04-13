import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class TaskSplitServiceTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - persistSplit (AC7 + AC8)

    /// GIVEN: An original task and sub-task suggestions
    /// WHEN: persistSplit is called
    /// THEN: Sub-tasks are created in the database with correct attributes
    func test_persistSplit_createsSubTasks() throws {
        let context = container.mainContext
        let original = LocalTask(title: "Umzug planen")
        original.taskType = "maintenance"
        context.insert(original)
        try context.save()

        let suggestions: [(title: String, minutes: Int)] = [
            (title: "Kartons besorgen", minutes: 30),
            (title: "Möbel abbauen", minutes: 60),
            (title: "Transporter mieten", minutes: 15)
        ]

        let created = TaskSplitService.persistSplit(
            originalTaskID: original.uuid.uuidString,
            suggestions: suggestions,
            taskType: "maintenance",
            importance: nil,
            urgency: nil,
            tags: [],
            dueDate: nil,
            modelContext: context
        )

        XCTAssertEqual(created, 3, "Should create 3 sub-tasks")

        // Verify sub-tasks exist in DB
        let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
        let subTasks = allTasks.filter { $0.parentTaskID == original.uuid.uuidString }

        XCTAssertEqual(subTasks.count, 3, "3 sub-tasks should reference original via parentTaskID")
        XCTAssertTrue(subTasks.contains { $0.title == "Kartons besorgen" })
        XCTAssertTrue(subTasks.contains { $0.title == "Möbel abbauen" })
        XCTAssertEqual(subTasks.first { $0.title == "Transporter mieten" }?.estimatedDuration, 15)
        XCTAssertEqual(subTasks.first { $0.title == "Kartons besorgen" }?.taskType, "maintenance")
    }

    /// GIVEN: An original task exists
    /// WHEN: persistSplit is called
    /// THEN: Original task is marked as completed
    func test_persistSplit_marksOriginalAsCompleted() throws {
        let context = container.mainContext
        let original = LocalTask(title: "Großer Task")
        context.insert(original)
        try context.save()

        XCTAssertFalse(original.isCompleted, "Original should not be completed before split")
        XCTAssertNil(original.completedAt, "CompletedAt should be nil before split")

        TaskSplitService.persistSplit(
            originalTaskID: original.uuid.uuidString,
            suggestions: [(title: "Sub 1", minutes: 15)],
            taskType: "",
            importance: nil,
            urgency: nil,
            tags: [],
            dueDate: nil,
            modelContext: context
        )

        XCTAssertTrue(original.isCompleted, "Original should be marked as completed after split")
        XCTAssertNotNil(original.completedAt, "CompletedAt should be set after split")
    }

    /// GIVEN: Suggestions with empty titles
    /// WHEN: persistSplit is called
    /// THEN: Empty-title suggestions are filtered out, only valid ones created
    func test_persistSplit_filtersEmptyTitles() throws {
        let context = container.mainContext
        let original = LocalTask(title: "Task")
        context.insert(original)
        try context.save()

        let suggestions: [(title: String, minutes: Int)] = [
            (title: "Gültiger Sub-Task", minutes: 30),
            (title: "", minutes: 15),
            (title: "", minutes: 60)
        ]

        let created = TaskSplitService.persistSplit(
            originalTaskID: original.uuid.uuidString,
            suggestions: suggestions,
            taskType: "",
            importance: nil,
            urgency: nil,
            tags: [],
            dueDate: nil,
            modelContext: context
        )

        XCTAssertEqual(created, 1, "Should only create 1 valid sub-task")
    }

    /// GIVEN: All suggestions have empty titles
    /// WHEN: persistSplit is called
    /// THEN: No sub-tasks created, original NOT marked as completed
    func test_persistSplit_noopWhenAllEmpty() throws {
        let context = container.mainContext
        let original = LocalTask(title: "Task")
        context.insert(original)
        try context.save()

        let created = TaskSplitService.persistSplit(
            originalTaskID: original.uuid.uuidString,
            suggestions: [(title: "", minutes: 15)],
            taskType: "",
            importance: nil,
            urgency: nil,
            tags: [],
            dueDate: nil,
            modelContext: context
        )

        XCTAssertEqual(created, 0, "Should create 0 sub-tasks")
        XCTAssertFalse(original.isCompleted, "Original should NOT be completed when no valid sub-tasks")
    }

    /// GIVEN: Original task has importance, urgency, tags, dueDate
    /// WHEN: persistSplit is called with inherited attributes
    /// THEN: Sub-tasks inherit all attributes from original
    func test_persistSplit_inheritsAttributes() throws {
        let context = container.mainContext
        let original = LocalTask(title: "Großprojekt")
        original.taskType = "project"
        original.importance = 3
        original.urgency = "urgent"
        original.tags = ["arbeit", "Q2"]
        original.dueDate = Date(timeIntervalSince1970: 1800000000)
        context.insert(original)
        try context.save()

        TaskSplitService.persistSplit(
            originalTaskID: original.uuid.uuidString,
            suggestions: [(title: "Schritt 1", minutes: 30)],
            taskType: "project",
            importance: 3,
            urgency: "urgent",
            tags: ["arbeit", "Q2"],
            dueDate: Date(timeIntervalSince1970: 1800000000),
            modelContext: context
        )

        let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
        let sub = allTasks.first { $0.parentTaskID == original.uuid.uuidString }!

        XCTAssertEqual(sub.importance, 3, "Should inherit importance")
        XCTAssertEqual(sub.urgency, "urgent", "Should inherit urgency")
        XCTAssertEqual(sub.tags, ["arbeit", "Q2"], "Should inherit tags")
        XCTAssertEqual(sub.dueDate?.timeIntervalSince1970, 1800000000, "Should inherit dueDate")
        XCTAssertEqual(sub.taskType, "project", "Should inherit taskType")
    }

    // MARK: - Availability Guard

    func test_suggestSplit_returnsEmptyWhenUnavailable() async {
        // If AI is not available (CI, old device), we expect an empty result — not a crash
        if !TaskSplitService.isAvailable {
            let result = await TaskSplitService.suggestSplit(for: "Test Task")
            XCTAssertTrue(result.isEmpty, "Should return empty when AI unavailable")
        }
    }

    // MARK: - AI Quality Tests (only run when Apple Intelligence available)

    func test_splitHouseholdTask() async throws {
        try XCTSkipUnless(TaskSplitService.isAvailable, "Apple Intelligence not available")

        let result = await TaskSplitService.suggestSplit(for: "Wohnung aufräumen und putzen")

        XCTAssertGreaterThanOrEqual(result.count, 2, "Should generate at least 2 sub-tasks")
        XCTAssertLessThanOrEqual(result.count, 6, "Should generate at most 6 sub-tasks")

        for sub in result {
            XCTAssertFalse(sub.title.isEmpty, "Sub-task title should not be empty")
            XCTAssertTrue([5, 15, 30, 60].contains(sub.minutes), "Duration should be valid: \(sub.minutes)")
        }
    }

    func test_splitWorkTask() async throws {
        try XCTSkipUnless(TaskSplitService.isAvailable, "Apple Intelligence not available")

        let result = await TaskSplitService.suggestSplit(for: "Quartalsbericht für Q1 erstellen")

        XCTAssertGreaterThanOrEqual(result.count, 2)
        XCTAssertLessThanOrEqual(result.count, 6)

        for sub in result {
            XCTAssertFalse(sub.title.isEmpty)
            XCTAssertTrue(sub.title.count <= 60, "Title too long: \(sub.title)")
        }
    }

    func test_splitProjectTask() async throws {
        try XCTSkipUnless(TaskSplitService.isAvailable, "Apple Intelligence not available")

        let result = await TaskSplitService.suggestSplit(for: "Umzug planen und organisieren")

        XCTAssertGreaterThanOrEqual(result.count, 3, "Complex task should generate at least 3 sub-tasks")

        // Print for manual quality review
        print("=== AI SPLIT QUALITY CHECK ===")
        print("Original: Umzug planen und organisieren")
        for (i, sub) in result.enumerated() {
            print("  \(i + 1). \(sub.title) (\(sub.minutes) min)")
        }
        print("==============================")
    }

    func test_splitSmallTask() async throws {
        try XCTSkipUnless(TaskSplitService.isAvailable, "Apple Intelligence not available")

        let result = await TaskSplitService.suggestSplit(for: "Milch kaufen")

        // Small task might generate fewer sub-tasks — that's fine
        XCTAssertGreaterThanOrEqual(result.count, 1)

        print("=== AI SPLIT: SMALL TASK ===")
        print("Original: Milch kaufen")
        for (i, sub) in result.enumerated() {
            print("  \(i + 1). \(sub.title) (\(sub.minutes) min)")
        }
        print("============================")
    }

    func test_splitEnglishTask() async throws {
        try XCTSkipUnless(TaskSplitService.isAvailable, "Apple Intelligence not available")

        let result = await TaskSplitService.suggestSplit(for: "Prepare annual tax filing")

        XCTAssertGreaterThanOrEqual(result.count, 2)

        print("=== AI SPLIT: ENGLISH TASK ===")
        print("Original: Prepare annual tax filing")
        for (i, sub) in result.enumerated() {
            print("  \(i + 1). \(sub.title) (\(sub.minutes) min)")
        }
        print("==============================")
    }
}
