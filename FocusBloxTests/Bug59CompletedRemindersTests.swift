import XCTest
import SwiftData
@testable import FocusBlox

/// Bug 59: Erledigte Apple Reminders erscheinen im Backlog
/// Root Cause: Bug 57 Fix wechselte Reminder-ID Format, was Duplikate und
/// Orphans erzeugte. Erledigte Reminders wurden als aktive lokale Tasks behalten.
@MainActor
final class Bug59CompletedRemindersTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: LocalTask.self, configurations: config)
        modelContext = modelContainer.mainContext
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Orphan Recovery (Attribut-Rettung)

    /// GIVEN: Orphaned task (sourceSystem="local", externalID=nil) with attributes
    ///        AND no existing reminders-sourced task for this reminder
    /// WHEN: importFromReminders() runs with a reminder matching the orphan's title
    /// THEN: Orphan is restored as reminders task with externalID set
    func testOrphanRestoredWhenNoExistingTask() async throws {
        // Simulate orphaned task from Bug 57 soft-delete
        let orphan = LocalTask(
            title: "Glasfaser aktivieren",
            importance: 3,
            urgency: "urgent",
            taskType: "essentials",
            sourceSystem: "local"  // was "reminders", soft-deleted by Bug 57
        )
        orphan.estimatedDuration = 15
        orphan.tags = ["Telekom"]
        modelContext.insert(orphan)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "ext-glasfaser-123", title: "Glasfaser aktivieren")
        ]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        let imported = try await syncService.importFromReminders()

        XCTAssertEqual(imported.count, 1, "Genau ein Task importiert")
        let task = imported.first!
        // Orphan should be restored, not a new task created
        XCTAssertEqual(task.sourceSystem, "reminders", "sourceSystem muss zurueck auf 'reminders'")
        XCTAssertEqual(task.externalID, "ext-glasfaser-123", "externalID muss gesetzt werden")
        // All attributes preserved
        XCTAssertEqual(task.importance, 3, "importance muss erhalten bleiben")
        XCTAssertEqual(task.urgency, "urgent", "urgency muss erhalten bleiben")
        XCTAssertEqual(task.taskType, "essentials", "taskType muss erhalten bleiben")
        XCTAssertEqual(task.estimatedDuration, 15, "duration muss erhalten bleiben")
        XCTAssertEqual(task.tags, ["Telekom"], "tags muessen erhalten bleiben")

        // Only 1 task in DB (orphan restored, no duplicate)
        let all = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(all.count, 1, "Kein Duplikat - Orphan wurde wiederhergestellt")
    }

    /// GIVEN: Orphan with attributes AND existing duplicate (sourceSystem="reminders") without attributes
    /// WHEN: importFromReminders() runs
    /// THEN: Attributes transferred from orphan to existing task, orphan deleted
    func testAttributeTransferFromOrphanToExisting() async throws {
        // Orphan (old task, has attributes, soft-deleted by Bug 57)
        let orphan = LocalTask(
            title: "Code Review",
            importance: 2,
            urgency: "not_urgent",
            taskType: "income",
            sourceSystem: "local"
        )
        orphan.estimatedDuration = 30
        orphan.aiScore = 75
        orphan.aiEnergyLevel = "high"
        modelContext.insert(orphan)

        // Duplicate (new task, created by Bug 57 with new ID format, no attributes)
        let duplicate = LocalTask(
            title: "Code Review",
            externalID: "ext-code-review-456",
            sourceSystem: "reminders"
        )
        modelContext.insert(duplicate)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "ext-code-review-456", title: "Code Review")
        ]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        // Only 1 task should remain (orphan deleted)
        let all = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(all.count, 1, "Orphan muss geloescht werden nach Attribut-Transfer")

        let remaining = all.first!
        XCTAssertEqual(remaining.sourceSystem, "reminders")
        XCTAssertEqual(remaining.externalID, "ext-code-review-456")
        // Attributes transferred from orphan
        XCTAssertEqual(remaining.importance, 2, "importance von Orphan uebertragen")
        XCTAssertEqual(remaining.urgency, "not_urgent", "urgency von Orphan uebertragen")
        XCTAssertEqual(remaining.taskType, "income", "taskType von Orphan uebertragen")
        XCTAssertEqual(remaining.estimatedDuration, 30, "duration von Orphan uebertragen")
        XCTAssertEqual(remaining.aiScore, 75, "aiScore von Orphan uebertragen")
        XCTAssertEqual(remaining.aiEnergyLevel, "high", "aiEnergyLevel von Orphan uebertragen")
    }

    // MARK: - Completed Reminders

    /// GIVEN: Task with sourceSystem="reminders" whose reminder is no longer incomplete
    /// WHEN: importFromReminders() runs (reminder not in results)
    /// THEN: Task is marked as completed (isCompleted=true, completedAt set)
    func testDeletedReminderMarkedAsCompleted() async throws {
        let task = LocalTask(
            title: "Erledigter Task",
            importance: 1,
            externalID: "completed-reminder-789",
            sourceSystem: "reminders"
        )
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = []  // Reminder nicht mehr vorhanden (erledigt)
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        let all = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(all.count, 1, "Task darf nicht geloescht werden")
        let remaining = all.first!
        XCTAssertTrue(remaining.isCompleted, "Task muss als erledigt markiert werden")
        XCTAssertNotNil(remaining.completedAt, "completedAt muss gesetzt werden")
        XCTAssertEqual(remaining.sourceSystem, "local", "sourceSystem auf 'local' setzen")
        XCTAssertEqual(remaining.importance, 1, "Attribute muessen erhalten bleiben")
    }

    // MARK: - Edge Cases

    /// GIVEN: No orphan, no existing task
    /// WHEN: importFromReminders() runs with new reminder
    /// THEN: New task created normally (no regression)
    func testNewReminderCreatesTaskNormally() async throws {
        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "brand-new-reminder", title: "Neuer Task")
        ]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        let imported = try await syncService.importFromReminders()

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported.first?.title, "Neuer Task")
        XCTAssertEqual(imported.first?.sourceSystem, "reminders")
        XCTAssertEqual(imported.first?.externalID, "brand-new-reminder")
    }
}
