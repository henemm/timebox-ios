import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests for RemindersSyncService
@MainActor
final class RemindersSyncServiceTests: XCTestCase {

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

    // MARK: - Import Tests

    /// GIVEN: Reminder without existing LocalTask
    /// WHEN: importFromReminders() is called
    /// THEN: New LocalTask created with sourceSystem="reminders" and externalID
    func testImportCreatesNewLocalTask() async throws {
        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [ReminderData(id: "test-1", title: "Test Reminder")]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        let imported = try await syncService.importFromReminders()

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported.first?.sourceSystem, "reminders")
        XCTAssertEqual(imported.first?.externalID, "test-1")
        XCTAssertEqual(imported.first?.title, "Test Reminder")
    }

    /// GIVEN: LocalTask with externalID, Reminder with changed title
    /// WHEN: importFromReminders() is called
    /// THEN: LocalTask.title is updated
    func testImportUpdatesExistingLocalTask() async throws {
        // Create existing LocalTask
        let existingTask = LocalTask(
            title: "Old Title",
            externalID: "test-1",
            sourceSystem: "reminders"
        )
        modelContext.insert(existingTask)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [ReminderData(id: "test-1", title: "New Title")]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        XCTAssertEqual(existingTask.title, "New Title")
    }

    /// GIVEN: LocalTask with tags=["Test"], Reminder without tags
    /// WHEN: importFromReminders() is called
    /// THEN: LocalTask.tags remains ["Test"]
    func testImportPreservesLocalOnlyFields() async throws {
        // Create existing LocalTask with tags
        let existingTask = LocalTask(
            title: "Test Task",
            tags: ["LocalTag"],
            urgency: "urgent",
            taskType: "deep_work",
            externalID: "test-1",
            sourceSystem: "reminders"
        )
        modelContext.insert(existingTask)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [ReminderData(id: "test-1", title: "Test Task")]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        XCTAssertEqual(existingTask.tags, ["LocalTag"])
        XCTAssertEqual(existingTask.urgency, "urgent")
        XCTAssertEqual(existingTask.taskType, "deep_work")
    }

    /// GIVEN: LocalTask with sourceSystem="reminders"
    /// WHEN: Reminder not found in Apple
    /// THEN: sourceSystem changes to "local", externalID preserved
    func testDeletedReminderBecomesLocal() async throws {
        // Create existing LocalTask linked to a reminder
        let existingTask = LocalTask(
            title: "Orphaned Task",
            externalID: "deleted-reminder-id",
            sourceSystem: "reminders"
        )
        modelContext.insert(existingTask)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = []  // Reminder no longer exists
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        XCTAssertEqual(existingTask.sourceSystem, "local")
        XCTAssertEqual(existingTask.externalID, "deleted-reminder-id")
    }

    /// GIVEN: LocalTask with sourceSystem="reminders", changed title
    /// WHEN: exportToReminders() is called
    /// THEN: Apple Reminder.title is updated
    func testExportUpdatesAppleReminder() async throws {
        // Create LocalTask that should be exported
        let task = LocalTask(
            title: "Updated Title",
            externalID: "test-1",
            sourceSystem: "reminders"
        )
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        try await syncService.exportToReminders(task: task)

        XCTAssertTrue(mockRepo.updateReminderCalled)
        XCTAssertEqual(mockRepo.lastUpdatedTitle, "Updated Title")
    }
}
