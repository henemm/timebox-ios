import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class RemindersImportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private var mockRepo: MockEventKitRepository!
    private var sut: RemindersImportService!

    override func setUp() async throws {
        let schema = Schema([LocalTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)

        mockRepo = MockEventKitRepository()
        sut = RemindersImportService(eventKitRepo: mockRepo, modelContext: modelContext)

        // Clear visible-lists filter so all reminders pass through
        UserDefaults.standard.removeObject(forKey: "visibleReminderListIDs")
    }

    override func tearDown() async throws {
        container = nil
        modelContext = nil
        mockRepo = nil
        sut = nil
        UserDefaults.standard.removeObject(forKey: "visibleReminderListIDs")
    }

    // MARK: - Basic Import

    func test_importAll_createsLocalTasks() async throws {
        // Given: Two reminders
        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "Buy milk"),
            ReminderData(id: "r2", title: "Call dentist")
        ]

        // When
        let result = try await sut.importAll()

        // Then: Both imported as local tasks
        XCTAssertEqual(result.imported.count, 2)
        XCTAssertEqual(result.skippedDuplicates, 0)

        let tasks = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(tasks.count, 2)

        // Verify sourceSystem and externalID
        for task in tasks {
            XCTAssertEqual(task.sourceSystem, "local")
            XCTAssertNil(task.externalID)
        }
    }

    // MARK: - Duplicate Detection

    func test_importAll_skipsDuplicates() async throws {
        // Given: An existing task with same title
        let existing = LocalTask(title: "Buy milk")
        modelContext.insert(existing)
        try modelContext.save()

        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "Buy milk"),
            ReminderData(id: "r2", title: "Call dentist")
        ]

        // When
        let result = try await sut.importAll()

        // Then: Only "Call dentist" imported, "Buy milk" skipped
        XCTAssertEqual(result.imported.count, 1)
        XCTAssertEqual(result.skippedDuplicates, 1)
        XCTAssertEqual(result.imported.first?.title, "Call dentist")

        let tasks = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(tasks.count, 2) // 1 existing + 1 imported
    }

    func test_importAll_twiceProducesNoDuplicates() async throws {
        // Given
        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "Buy milk")
        ]

        // When: Import twice
        _ = try await sut.importAll()
        let result2 = try await sut.importAll()

        // Then: Second import skips the duplicate
        XCTAssertEqual(result2.imported.count, 0)
        XCTAssertEqual(result2.skippedDuplicates, 1)

        let tasks = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(tasks.count, 1)
    }

    // MARK: - Visible Lists Filter

    func test_importAll_respectsVisibleListsFilter() async throws {
        // Given: Two reminders from different lists, only one list visible
        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "From visible", calendarIdentifier: "list-A"),
            ReminderData(id: "r2", title: "From hidden", calendarIdentifier: "list-B")
        ]
        UserDefaults.standard.set(["list-A"], forKey: "visibleReminderListIDs")

        // When
        let result = try await sut.importAll()

        // Then: Only reminder from visible list imported
        XCTAssertEqual(result.imported.count, 1)
        XCTAssertEqual(result.imported.first?.title, "From visible")
    }

    // MARK: - Priority Mapping

    func test_importAll_mapsPriorityCorrectly() async throws {
        // Given: Reminders with different EK priorities
        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "None", priority: 0),
            ReminderData(id: "r2", title: "High", priority: 1),
            ReminderData(id: "r3", title: "Medium", priority: 5),
            ReminderData(id: "r4", title: "Low", priority: 9)
        ]

        // When
        let result = try await sut.importAll()

        // Then: Priorities mapped correctly
        let tasksByTitle = Dictionary(uniqueKeysWithValues: result.imported.map { ($0.title, $0) })
        XCTAssertNil(tasksByTitle["None"]?.importance)      // 0 → nil (TBD)
        XCTAssertEqual(tasksByTitle["High"]?.importance, 3)  // 1-4 → 3
        XCTAssertEqual(tasksByTitle["Medium"]?.importance, 2) // 5 → 2
        XCTAssertEqual(tasksByTitle["Low"]?.importance, 1)   // 6-9 → 1
    }

    // MARK: - Due Date & Notes

    func test_importAll_transfersDueDateAndNotes() async throws {
        // Given
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "Task with details", dueDate: dueDate, notes: "Some notes")
        ]

        // When
        let result = try await sut.importAll()

        // Then
        let task = result.imported.first
        XCTAssertEqual(task?.dueDate, dueDate)
        XCTAssertEqual(task?.taskDescription, "Some notes")
    }

    // MARK: - Mark Complete After Import

    func test_importAll_markCompleteMarksAllFilteredReminders() async throws {
        // Given: Two reminders, one will be a duplicate
        let existing = LocalTask(title: "Already here")
        modelContext.insert(existing)
        try modelContext.save()

        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "Already here"),
            ReminderData(id: "r2", title: "New task")
        ]

        // When: Import with markComplete
        _ = try await sut.importAll(markCompleteInReminders: true)

        // Then: BOTH reminders marked complete (imported + skipped)
        XCTAssertTrue(mockRepo.markReminderCompleteCalled)
        XCTAssertEqual(mockRepo.completedReminderIDs.count, 2)
        XCTAssertTrue(mockRepo.completedReminderIDs.contains("r1"))
        XCTAssertTrue(mockRepo.completedReminderIDs.contains("r2"))
    }

    func test_importAll_withoutMarkComplete_doesNotMarkReminders() async throws {
        // Given
        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "A task")
        ]

        // When: Import WITHOUT markComplete
        _ = try await sut.importAll(markCompleteInReminders: false)

        // Then: No reminders marked
        XCTAssertFalse(mockRepo.markReminderCompleteCalled)
        XCTAssertTrue(mockRepo.completedReminderIDs.isEmpty)
    }

    func test_importAll_defaultDoesNotMarkComplete() async throws {
        // Given
        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "A task")
        ]

        // When: Import with default parameter
        _ = try await sut.importAll()

        // Then: Default is false — no marking
        XCTAssertFalse(mockRepo.markReminderCompleteCalled)
    }

    // MARK: - Migration

    func test_migration_convertsRemindersToLocal() async throws {
        // Given: Tasks with sourceSystem "reminders"
        let task1 = LocalTask(title: "Old reminder task", externalID: "ext-1", sourceSystem: "reminders")
        let task2 = LocalTask(title: "Local task", sourceSystem: "local")
        modelContext.insert(task1)
        modelContext.insert(task2)
        try modelContext.save()

        // When
        let migrated = RemindersImportService.migrateRemindersToLocal(in: modelContext)

        // Then
        XCTAssertEqual(migrated, 1)

        let allTasks = try modelContext.fetch(FetchDescriptor<LocalTask>())
        for task in allTasks {
            XCTAssertEqual(task.sourceSystem, "local")
            XCTAssertNil(task.externalID)
        }
    }

    func test_migration_isIdempotent() async throws {
        // Given
        let task = LocalTask(title: "Migrated task", externalID: "ext-1", sourceSystem: "reminders")
        modelContext.insert(task)
        try modelContext.save()

        // When: Run migration twice
        let first = RemindersImportService.migrateRemindersToLocal(in: modelContext)
        let second = RemindersImportService.migrateRemindersToLocal(in: modelContext)

        // Then: First migrates, second finds nothing
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 0)
    }

    // MARK: - Empty Import

    func test_importAll_withNoReminders_returnsEmpty() async throws {
        // Given: No reminders
        mockRepo.mockReminders = []

        // When
        let result = try await sut.importAll()

        // Then
        XCTAssertEqual(result.imported.count, 0)
        XCTAssertEqual(result.skippedDuplicates, 0)
    }

    // MARK: - Mark Complete Failure Reporting

    func test_importAll_reportsMarkCompleteSuccess() async throws {
        // Given: One reminder to import, markComplete enabled
        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "New task")
        ]

        // When
        let result = try await sut.importAll(markCompleteInReminders: true)

        // Then: ImportResult must report how many reminders were successfully marked complete.
        // BUG: ImportResult has no such field — mark-complete failures are silently swallowed.
        // The caller (BacklogView) cannot show meaningful feedback.
        XCTAssertEqual(result.markedComplete, 1)
    }

    func test_importAll_reportsMarkCompleteFailures() async throws {
        // Given: One reminder, but markReminderComplete will throw
        mockRepo.mockReminders = [
            ReminderData(id: "r1", title: "New task")
        ]
        mockRepo.markCompleteError = EventKitError.notAuthorized

        // When: Import with markComplete — should NOT throw (import succeeded)
        let result = try await sut.importAll(markCompleteInReminders: true)

        // Then: ImportResult must report the failure count.
        XCTAssertEqual(result.imported.count, 1)
        XCTAssertEqual(result.markCompleteFailures, 1)
    }

}
