import XCTest
import SwiftData
@testable import TimeBox

@MainActor
final class SyncEngineTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var eventKitRepo: EventKitRepository!
    var syncEngine: SyncEngine!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: TaskMetadata.self, configurations: config)
        modelContext = modelContainer.mainContext
        eventKitRepo = EventKitRepository()
        syncEngine = SyncEngine(eventKitRepo: eventKitRepo, modelContext: modelContext)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        eventKitRepo = nil
        syncEngine = nil
    }

    // MARK: - TDD RED: updateDuration Tests

    /// GIVEN: TaskMetadata exists for a reminder
    /// WHEN: updateDuration(itemID, 30) is called
    /// THEN: manualDuration should be 30
    func testUpdateDurationSetsManualDuration() throws {
        // Setup: Create TaskMetadata
        let reminderID = "test-reminder-123"
        let metadata = TaskMetadata(reminderID: reminderID, sortOrder: 0)
        modelContext.insert(metadata)
        try modelContext.save()

        // Act: Call updateDuration - THIS METHOD DOESN'T EXIST YET
        try syncEngine.updateDuration(itemID: reminderID, minutes: 30)

        // Assert
        let fetchDescriptor = FetchDescriptor<TaskMetadata>(
            predicate: #Predicate { $0.reminderID == reminderID }
        )
        let results = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(results.first?.manualDuration, 30)
    }

    /// GIVEN: TaskMetadata exists with manualDuration == 30
    /// WHEN: updateDuration(itemID, nil) is called (reset)
    /// THEN: manualDuration should be nil
    func testUpdateDurationResetSetsNil() throws {
        // Setup: Create TaskMetadata with existing duration
        let reminderID = "test-reminder-456"
        let metadata = TaskMetadata(reminderID: reminderID, sortOrder: 0)
        metadata.manualDuration = 30
        modelContext.insert(metadata)
        try modelContext.save()

        // Act: Call updateDuration with nil - THIS METHOD DOESN'T EXIST YET
        try syncEngine.updateDuration(itemID: reminderID, minutes: nil)

        // Assert
        let fetchDescriptor = FetchDescriptor<TaskMetadata>(
            predicate: #Predicate { $0.reminderID == reminderID }
        )
        let results = try modelContext.fetch(fetchDescriptor)
        XCTAssertNil(results.first?.manualDuration)
    }

    /// GIVEN: No TaskMetadata exists for the given ID
    /// WHEN: updateDuration is called
    /// THEN: Nothing crashes, operation is a no-op
    func testUpdateDurationWithNonexistentIDDoesNotCrash() throws {
        // Act: Call updateDuration for non-existent ID
        XCTAssertNoThrow(try syncEngine.updateDuration(itemID: "nonexistent", minutes: 15))
    }
}
