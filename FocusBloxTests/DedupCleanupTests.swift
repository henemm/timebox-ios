import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class DedupCleanupTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([LocalTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Test 1: Duplicate deleted, original kept

    func testDedupDeletesRemindersTaskWhenLocalExists() throws {
        // GIVEN: A local/CloudKit task and a reminders duplicate with same title
        let localTask = LocalTask(title: "Einkaufen", importance: 3, sourceSystem: "local")
        localTask.urgency = "urgent"
        localTask.estimatedDuration = 30

        let remindersTask = LocalTask(title: "Einkaufen", sourceSystem: "reminders")
        // remindersTask has no importance, urgency, duration (stripped copy)

        context.insert(localTask)
        context.insert(remindersTask)
        try context.save()

        // WHEN: Dedup cleanup runs
        let deletedCount = FocusBloxApp.cleanupRemindersDuplicates(in: context)

        // THEN: Reminders copy deleted, local kept
        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(deletedCount, 1, "Should delete 1 duplicate")
        XCTAssertEqual(remaining.count, 1, "Should keep 1 task")
        XCTAssertEqual(remaining.first?.sourceSystem, "local", "Kept task should be local")
        XCTAssertEqual(remaining.first?.importance, 3, "Kept task should have full attributes")
    }

    // MARK: - Test 2: Non-duplicate reminders task kept

    func testDedupKeepsRemindersTaskWithoutLocalMatch() throws {
        // GIVEN: A reminders task with no matching local task
        let remindersTask = LocalTask(title: "Nur in Reminders", sourceSystem: "reminders")
        let localTask = LocalTask(title: "Anderer Task", sourceSystem: "local")

        context.insert(remindersTask)
        context.insert(localTask)
        try context.save()

        // WHEN: Dedup cleanup runs
        let deletedCount = FocusBloxApp.cleanupRemindersDuplicates(in: context)

        // THEN: Both tasks kept
        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(deletedCount, 0, "Should delete nothing")
        XCTAssertEqual(remaining.count, 2, "Both tasks should remain")
    }

    // MARK: - Test 3: No reminders tasks = nothing to do

    func testDedupDoesNothingWithoutRemindersTasks() throws {
        // GIVEN: Only local tasks, no reminders tasks
        let task1 = LocalTask(title: "Task A", sourceSystem: "local")
        let task2 = LocalTask(title: "Task B", sourceSystem: "local")

        context.insert(task1)
        context.insert(task2)
        try context.save()

        // WHEN: Dedup cleanup runs
        let deletedCount = FocusBloxApp.cleanupRemindersDuplicates(in: context)

        // THEN: Nothing deleted
        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(deletedCount, 0, "Should delete nothing")
        XCTAssertEqual(remaining.count, 2, "All tasks should remain")
    }

    // MARK: - Test 4: Multiple duplicates cleaned up

    func testDedupDeletesMultipleDuplicates() throws {
        // GIVEN: 3 local tasks and 2 reminders duplicates
        let local1 = LocalTask(title: "Einkaufen", importance: 3, sourceSystem: "local")
        let local2 = LocalTask(title: "Sport", importance: 2, sourceSystem: "local")
        let local3 = LocalTask(title: "Lesen", importance: 1, sourceSystem: "local")

        let dup1 = LocalTask(title: "Einkaufen", sourceSystem: "reminders")
        let dup2 = LocalTask(title: "Sport", sourceSystem: "reminders")

        [local1, local2, local3, dup1, dup2].forEach { context.insert($0) }
        try context.save()

        // WHEN: Dedup cleanup runs
        let deletedCount = FocusBloxApp.cleanupRemindersDuplicates(in: context)

        // THEN: 2 duplicates deleted, 3 originals kept
        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(deletedCount, 2, "Should delete 2 duplicates")
        XCTAssertEqual(remaining.count, 3, "Should keep 3 original tasks")
        XCTAssertTrue(remaining.allSatisfy { $0.sourceSystem == "local" }, "All remaining should be local")
    }
}
