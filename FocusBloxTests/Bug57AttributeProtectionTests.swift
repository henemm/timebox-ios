import XCTest
import SwiftData
@testable import FocusBlox

/// Bug 57: Tests fuer Attribut-Schutz bei Reminders-Sync
/// Fixes: A (bedingte Writes), C (Soft-Delete), D (Safe-Setter)
@MainActor
final class Bug57AttributeProtectionTests: XCTestCase {

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

    // MARK: - Fix C: Soft-Delete statt Hard-Delete

    /// GIVEN: LocalTask mit sourceSystem="reminders", urgency="urgent", importance=3
    /// WHEN: Reminder verschwindet aus Apple (Liste versteckt oder geloescht)
    /// THEN: Task wird NICHT geloescht, sondern auf sourceSystem="local" gesetzt
    func testSoftDeletePreservesTask() async throws {
        let task = LocalTask(
            title: "Wichtiger Task",
            importance: 3,
            urgency: "urgent",
            taskType: "essentials",
            externalID: "reminder-abc",
            sourceSystem: "reminders"
        )
        task.estimatedDuration = 15
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = []  // Reminder nicht mehr vorhanden
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        let descriptor = FetchDescriptor<LocalTask>()
        let remaining = try modelContext.fetch(descriptor)

        // SOLL: Task existiert noch (Soft-Delete)
        XCTAssertEqual(remaining.count, 1, "Task darf NICHT geloescht werden bei fehlendem Reminder")
        XCTAssertEqual(remaining.first?.sourceSystem, "local", "sourceSystem muss auf 'local' gesetzt werden")
        XCTAssertNil(remaining.first?.externalID, "externalID muss nil sein nach Soft-Delete")
    }

    /// GIVEN: Soft-deleted Task (ehemals Reminder)
    /// THEN: Alle erweiterten Attribute bleiben erhalten
    func testSoftDeletePreservesAllAttributes() async throws {
        let task = LocalTask(
            title: "Attribut-Test",
            importance: 2,
            urgency: "not_urgent",
            taskType: "recharge",
            externalID: "reminder-xyz",
            sourceSystem: "reminders"
        )
        task.estimatedDuration = 30
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = []
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        let descriptor = FetchDescriptor<LocalTask>()
        let remaining = try modelContext.fetch(descriptor)

        // SOLL: Alle Attribute bleiben erhalten
        XCTAssertEqual(remaining.first?.importance, 2, "importance muss erhalten bleiben")
        XCTAssertEqual(remaining.first?.urgency, "not_urgent", "urgency muss erhalten bleiben")
        XCTAssertEqual(remaining.first?.taskType, "recharge", "taskType muss erhalten bleiben")
        XCTAssertEqual(remaining.first?.estimatedDuration, 30, "duration muss erhalten bleiben")
        XCTAssertEqual(remaining.first?.title, "Attribut-Test", "Titel muss erhalten bleiben")
    }

    // MARK: - Fix A: Bedingte Writes bei Sync

    /// GIVEN: LocalTask mit gesetzten Attributen, Reminder mit identischem Titel
    /// WHEN: importFromReminders() laeuft (simuliert macOS-Sync)
    /// THEN: Erweiterte Attribute bleiben erhalten
    func testSyncWithUnchangedDataPreservesAttributes() async throws {
        let task = LocalTask(
            title: "Glasfaser aktivieren",
            importance: 3,
            urgency: "urgent",
            taskType: "essentials",
            externalID: "reminder-glasfaser",
            sourceSystem: "reminders"
        )
        task.estimatedDuration = 15
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "reminder-glasfaser", title: "Glasfaser aktivieren")
        ]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        // SOLL: Alle erweiterten Attribute unveraendert
        XCTAssertEqual(task.importance, 3, "importance darf nicht ueberschrieben werden")
        XCTAssertEqual(task.urgency, "urgent", "urgency darf nicht ueberschrieben werden")
        XCTAssertEqual(task.taskType, "essentials", "taskType darf nicht ueberschrieben werden")
        XCTAssertEqual(task.estimatedDuration, 15, "duration darf nicht ueberschrieben werden")
    }

    /// GIVEN: LocalTask mit gesetzten Attributen, Reminder mit geaendertem Titel
    /// WHEN: importFromReminders() aktualisiert den Titel
    /// THEN: Nur Titel aendert sich, erweiterte Attribute bleiben
    func testSyncWithChangedTitlePreservesAttributes() async throws {
        let task = LocalTask(
            title: "Alter Titel",
            importance: 1,
            urgency: "not_urgent",
            taskType: "maintenance",
            externalID: "reminder-update",
            sourceSystem: "reminders"
        )
        task.estimatedDuration = 60
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "reminder-update", title: "Neuer Titel")
        ]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        // Titel aktualisiert
        XCTAssertEqual(task.title, "Neuer Titel", "Titel soll aktualisiert werden")
        // Erweiterte Attribute unveraendert
        XCTAssertEqual(task.importance, 1, "importance darf nicht ueberschrieben werden")
        XCTAssertEqual(task.urgency, "not_urgent", "urgency darf nicht ueberschrieben werden")
        XCTAssertEqual(task.taskType, "maintenance", "taskType darf nicht ueberschrieben werden")
        XCTAssertEqual(task.estimatedDuration, 60, "duration darf nicht ueberschrieben werden")
    }

    // MARK: - Fix D: Safe-Setter auf LocalTask

    /// GIVEN: LocalTask mit importance=3
    /// WHEN: safeSetImportance(nil) aufgerufen
    /// THEN: importance bleibt 3 (nil wird blockiert)
    func testSafeSetImportanceBlocksNilOverwrite() throws {
        let task = LocalTask(title: "Test", importance: 3)
        modelContext.insert(task)

        task.safeSetImportance(nil)

        XCTAssertEqual(task.importance, 3, "safeSetImportance(nil) darf gesetzten Wert nicht loeschen")
    }

    /// GIVEN: LocalTask mit importance=nil
    /// WHEN: safeSetImportance(2) aufgerufen
    /// THEN: importance wird auf 2 gesetzt (erster Write erlaubt)
    func testSafeSetImportanceAllowsFirstWrite() throws {
        let task = LocalTask(title: "Test")
        modelContext.insert(task)

        task.safeSetImportance(2)

        XCTAssertEqual(task.importance, 2, "safeSetImportance soll nil-Felder beschreiben koennen")
    }

    /// GIVEN: LocalTask mit importance=3
    /// WHEN: safeSetImportance(1) aufgerufen
    /// THEN: importance wird auf 1 gesetzt (Wert-Aenderung erlaubt)
    func testSafeSetImportanceAllowsValueChange() throws {
        let task = LocalTask(title: "Test", importance: 3)
        modelContext.insert(task)

        task.safeSetImportance(1)

        XCTAssertEqual(task.importance, 1, "safeSetImportance soll Wert-Aenderungen erlauben")
    }

    /// GIVEN: LocalTask mit urgency="urgent"
    /// WHEN: safeSetUrgency(nil) aufgerufen
    /// THEN: urgency bleibt "urgent"
    func testSafeSetUrgencyBlocksNilOverwrite() throws {
        let task = LocalTask(title: "Test", urgency: "urgent")
        modelContext.insert(task)

        task.safeSetUrgency(nil)

        XCTAssertEqual(task.urgency, "urgent", "safeSetUrgency(nil) darf gesetzten Wert nicht loeschen")
    }

    /// GIVEN: LocalTask mit estimatedDuration=30
    /// WHEN: safeSetDuration(nil) aufgerufen
    /// THEN: estimatedDuration bleibt 30
    func testSafeSetDurationBlocksNilOverwrite() throws {
        let task = LocalTask(title: "Test")
        task.estimatedDuration = 30
        modelContext.insert(task)

        task.safeSetDuration(nil)

        XCTAssertEqual(task.estimatedDuration, 30, "safeSetDuration(nil) darf gesetzten Wert nicht loeschen")
    }

    /// GIVEN: LocalTask mit taskType="essentials"
    /// WHEN: safeSetTaskType("") aufgerufen
    /// THEN: taskType bleibt "essentials"
    func testSafeSetTaskTypeBlocksEmptyOverwrite() throws {
        let task = LocalTask(title: "Test", taskType: "essentials")
        modelContext.insert(task)

        task.safeSetTaskType("")

        XCTAssertEqual(task.taskType, "essentials", "safeSetTaskType('') darf gesetzten Wert nicht loeschen")
    }
}
