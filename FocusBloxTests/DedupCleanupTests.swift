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

    // MARK: - Test 1: Enriched kept, stripped deleted (same externalID)

    func testDedupKeepsEnrichedDeletesStripped() throws {
        // GIVEN: Two tasks with SAME externalID, both sourceSystem="reminders"
        // One enriched (via CloudKit sync), one stripped (direct Reminders import)
        let enriched = LocalTask(title: "Einkaufen", importance: 3, externalID: "REM-ABC-123", sourceSystem: "reminders")
        enriched.urgency = "urgent"
        enriched.estimatedDuration = 30
        enriched.taskType = "shallow_work"
        enriched.tags = ["einkauf"]

        let stripped = LocalTask(title: "Einkaufen", externalID: "REM-ABC-123", sourceSystem: "reminders")
        // stripped has no importance, urgency, duration, taskType, tags

        context.insert(enriched)
        context.insert(stripped)
        try context.save()

        // WHEN: Dedup cleanup runs
        let deletedCount = FocusBloxApp.cleanupRemindersDuplicates(in: context)

        // THEN: Stripped deleted, enriched kept
        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(deletedCount, 1, "Should delete 1 duplicate")
        XCTAssertEqual(remaining.count, 1, "Should keep 1 task")
        XCTAssertEqual(remaining.first?.importance, 3, "Kept task should have enriched attributes")
        XCTAssertEqual(remaining.first?.urgency, "urgent", "Kept task should have urgency")
        XCTAssertEqual(remaining.first?.estimatedDuration, 30, "Kept task should have duration")
    }

    // MARK: - Test 2: Unique externalID task kept

    func testDedupKeepsTaskWithUniqueExternalID() throws {
        // GIVEN: A task with externalID but NO duplicate
        let unique = LocalTask(title: "Nur einmal", externalID: "REM-UNIQUE-1", sourceSystem: "reminders")
        unique.importance = 2

        let otherTask = LocalTask(title: "Anderer Task", externalID: "REM-OTHER-1", sourceSystem: "reminders")

        context.insert(unique)
        context.insert(otherTask)
        try context.save()

        // WHEN: Dedup cleanup runs
        let deletedCount = FocusBloxApp.cleanupRemindersDuplicates(in: context)

        // THEN: Both tasks kept (no duplicates)
        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(deletedCount, 0, "Should delete nothing")
        XCTAssertEqual(remaining.count, 2, "Both tasks should remain")
    }

    // MARK: - Test 3: No tasks with externalID = nothing to do

    func testDedupDoesNothingWithoutExternalIDs() throws {
        // GIVEN: Tasks without externalID (manually created, not from Reminders)
        let task1 = LocalTask(title: "Task A")
        let task2 = LocalTask(title: "Task B")

        context.insert(task1)
        context.insert(task2)
        try context.save()

        // WHEN: Dedup cleanup runs
        let deletedCount = FocusBloxApp.cleanupRemindersDuplicates(in: context)

        // THEN: Nothing deleted, return 0
        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(deletedCount, 0, "Should delete nothing")
        XCTAssertEqual(remaining.count, 2, "All tasks should remain")
    }

    // MARK: - Test 4: Three duplicates, only most enriched survives

    func testDedupKeepsMostEnrichedOfThree() throws {
        // GIVEN: Three tasks with SAME externalID, different enrichment levels
        // Level 0: bare minimum (no attributes)
        let bare = LocalTask(title: "Sport machen", externalID: "REM-SPORT-1", sourceSystem: "reminders")

        // Level 2: partially enriched (importance + duration)
        let partial = LocalTask(title: "Sport machen", importance: 2, estimatedDuration: 45, externalID: "REM-SPORT-1", sourceSystem: "reminders")

        // Level 5: fully enriched (all attributes)
        let full = LocalTask(title: "Sport machen", importance: 3, estimatedDuration: 60, externalID: "REM-SPORT-1", sourceSystem: "reminders")
        full.urgency = "urgent"
        full.taskType = "deep_work"
        full.tags = ["fitness"]

        context.insert(bare)
        context.insert(partial)
        context.insert(full)
        try context.save()

        // WHEN: Dedup cleanup runs
        let deletedCount = FocusBloxApp.cleanupRemindersDuplicates(in: context)

        // THEN: Only the fully enriched task survives
        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(deletedCount, 2, "Should delete 2 less-enriched duplicates")
        XCTAssertEqual(remaining.count, 1, "Should keep only 1 task")
        XCTAssertEqual(remaining.first?.importance, 3, "Kept task should be the fully enriched one")
        XCTAssertEqual(remaining.first?.urgency, "urgent", "Kept task should have urgency")
        XCTAssertEqual(remaining.first?.taskType, "deep_work", "Kept task should have taskType")
    }
}
