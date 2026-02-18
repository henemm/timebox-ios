import XCTest
import SwiftData
@testable import FocusBlox

/// Bug 60: Erweiterte Attribute verschwinden bei Reminders-Sync (7. Wiederholung)
///
/// Root Causes:
/// 1. externalID wird auf nil gesetzt — Recovery permanent unmoeglich
/// 2. isCompleted=true blockiert Orphan-Recovery
/// 3. Kein Title-Match fuer sourceSystem="reminders" Tasks
/// 4. calendarItemExternalIdentifier aendert sich
/// 5. handleDeletedReminders nutzt gefilterte statt aller IDs
///
/// Diese Tests verifizieren den Fix fuer ALLE Root Causes.
@MainActor
final class Bug60AttributeRecoveryTests: XCTestCase {

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

    // MARK: - Root Cause 1+4: ID aendert sich, Task muss per Titel gefunden werden

    /// GIVEN: Task mit externalID="old-id", alle Attribute gesetzt
    /// WHEN: Reminder kommt mit NEUER ID aber gleichem Titel zurueck
    /// THEN: Task per Titel gefunden, externalID aktualisiert, ALLE Attribute erhalten
    /// EXPECTED TO FAIL: findReminderTask(byTitle:) existiert noch nicht
    func testIDChangePreservesAttributes() async throws {
        let task = LocalTask(
            title: "Glasfaser aktivieren",
            importance: 3,
            urgency: "urgent",
            taskType: "essentials",
            externalID: "old-external-id",
            sourceSystem: "reminders"
        )
        task.estimatedDuration = 15
        task.tags = ["Telekom"]
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "new-external-id", title: "Glasfaser aktivieren")
        ]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        let imported = try await syncService.importFromReminders()

        // Task muss gefunden und aktualisiert worden sein (nicht neu erstellt)
        let all = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(all.count, 1, "Kein Duplikat — Task per Titel wiedererkannt")

        let result = all.first!
        XCTAssertEqual(result.externalID, "new-external-id", "externalID muss auf neue ID aktualisiert werden")
        XCTAssertEqual(result.sourceSystem, "reminders", "sourceSystem muss reminders bleiben")
        // ALLE erweiterten Attribute muessen erhalten bleiben
        XCTAssertEqual(result.importance, 3, "importance muss erhalten bleiben")
        XCTAssertEqual(result.urgency, "urgent", "urgency muss erhalten bleiben")
        XCTAssertEqual(result.taskType, "essentials", "taskType muss erhalten bleiben")
        XCTAssertEqual(result.estimatedDuration, 15, "duration muss erhalten bleiben")
        XCTAssertEqual(result.tags, ["Telekom"], "tags muessen erhalten bleiben")
    }

    // MARK: - Root Cause 1: externalID darf NIE auf nil gesetzt werden

    /// GIVEN: Task mit sourceSystem="reminders", externalID gesetzt
    /// WHEN: Reminder ist nicht mehr in der Liste (erledigt in Apple)
    /// THEN: externalID und sourceSystem BLEIBEN erhalten, nur isCompleted=true
    /// EXPECTED TO FAIL: handleDeletedReminders setzt externalID=nil
    func testDeletedReminderKeepsExternalID() async throws {
        let task = LocalTask(
            title: "Erledigter Task",
            importance: 2,
            urgency: "not_urgent",
            externalID: "reminder-to-complete",
            sourceSystem: "reminders"
        )
        task.estimatedDuration = 30
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [] // Reminder erledigt
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        let all = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(all.count, 1)
        let result = all.first!
        XCTAssertTrue(result.isCompleted, "Task muss als erledigt markiert werden")
        XCTAssertEqual(result.sourceSystem, "reminders", "sourceSystem darf NICHT auf 'local' gesetzt werden")
        XCTAssertEqual(result.externalID, "reminder-to-complete", "externalID darf NICHT auf nil gesetzt werden")
        XCTAssertEqual(result.importance, 2, "Attribute muessen erhalten bleiben")
        XCTAssertEqual(result.estimatedDuration, 30, "Duration muss erhalten bleiben")
    }

    // MARK: - Root Cause 2: isCompleted darf Recovery nicht blockieren

    /// GIVEN: Task wurde durch handleDeletedReminders als completed markiert
    /// WHEN: Reminder taucht wieder auf (uncompleted in Apple)
    /// THEN: Task wird reaktiviert (isCompleted=false), Attribute erhalten
    /// EXPECTED TO FAIL: externalID ist nil nach handleDeletedReminders
    func testCompletedTaskReactivatedWhenReminderReappears() async throws {
        // Schritt 1: Task erstellen und als completed markieren (simuliert handleDeletedReminders)
        let task = LocalTask(
            title: "Comeback Task",
            importance: 3,
            urgency: "urgent",
            taskType: "income",
            externalID: "comeback-reminder",
            sourceSystem: "reminders"
        )
        task.estimatedDuration = 45
        task.isCompleted = true
        task.completedAt = Date()
        modelContext.insert(task)
        try modelContext.save()

        // Schritt 2: Reminder taucht wieder auf
        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "comeback-reminder", title: "Comeback Task")
        ]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        let imported = try await syncService.importFromReminders()

        let all = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(all.count, 1, "Kein Duplikat")
        let result = all.first!
        XCTAssertFalse(result.isCompleted, "Task muss reaktiviert werden (isCompleted=false)")
        XCTAssertEqual(result.importance, 3, "importance muss erhalten bleiben")
        XCTAssertEqual(result.urgency, "urgent", "urgency muss erhalten bleiben")
        XCTAssertEqual(result.estimatedDuration, 45, "duration muss erhalten bleiben")
    }

    // MARK: - Root Cause 2+4: ID aendert sich UND Task war zwischenzeitlich completed

    /// GIVEN: Task mit alter ID, als completed markiert
    /// WHEN: Reminder kommt mit NEUER ID und gleichem Titel
    /// THEN: Task per Titel gefunden, ID aktualisiert, reaktiviert, Attribute erhalten
    /// EXPECTED TO FAIL: Mehrere Root Causes blockieren diesen Flow
    func testIDChangeAndCompletedTaskRecovery() async throws {
        let task = LocalTask(
            title: "Steuererklarung abgeben",
            importance: 3,
            urgency: "urgent",
            taskType: "essentials",
            externalID: "old-steuer-id",
            sourceSystem: "reminders"
        )
        task.estimatedDuration = 120
        task.tags = ["Steuern", "Deadline"]
        task.isCompleted = true
        task.completedAt = Date()
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "new-steuer-id", title: "Steuererklarung abgeben")
        ]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        let all = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(all.count, 1, "Kein Duplikat — Task per Titel wiedererkannt trotz neuer ID + completed")
        let result = all.first!
        XCTAssertEqual(result.externalID, "new-steuer-id", "externalID auf neue ID aktualisiert")
        XCTAssertFalse(result.isCompleted, "Task reaktiviert")
        XCTAssertEqual(result.importance, 3)
        XCTAssertEqual(result.urgency, "urgent")
        XCTAssertEqual(result.taskType, "essentials")
        XCTAssertEqual(result.estimatedDuration, 120)
        XCTAssertEqual(result.tags, ["Steuern", "Deadline"])
    }

    // MARK: - Root Cause 5: handleDeletedReminders muss ALLE IDs nutzen

    /// GIVEN: Task aus Liste A (sichtbar) und Task aus Liste B (versteckt)
    /// WHEN: importFromReminders() laeuft (Liste B ist versteckt)
    /// THEN: Task aus Liste B darf NICHT als geloescht markiert werden
    /// EXPECTED TO FAIL: handleDeletedReminders bekommt nur gefilterte IDs
    func testHiddenListTaskNotDeleted() async throws {
        // Task aus sichtbarer Liste
        let visibleTask = LocalTask(
            title: "Sichtbarer Task",
            importance: 1,
            externalID: "visible-reminder",
            sourceSystem: "reminders"
        )
        // Task aus versteckter Liste
        let hiddenTask = LocalTask(
            title: "Versteckter Task",
            importance: 3,
            urgency: "urgent",
            externalID: "hidden-reminder",
            sourceSystem: "reminders"
        )
        hiddenTask.estimatedDuration = 60
        modelContext.insert(visibleTask)
        modelContext.insert(hiddenTask)
        try modelContext.save()

        // Mock: Beide Reminders existieren, aber nur einer in sichtbarer Liste
        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "visible-reminder", title: "Sichtbarer Task", calendarIdentifier: "list-A"),
            ReminderData(id: "hidden-reminder", title: "Versteckter Task", calendarIdentifier: "list-B")
        ]

        // Nur Liste A ist sichtbar
        UserDefaults.standard.set(["list-A"], forKey: "visibleReminderListIDs")
        defer { UserDefaults.standard.removeObject(forKey: "visibleReminderListIDs") }

        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)
        _ = try await syncService.importFromReminders()

        // Versteckter Task darf NICHT als erledigt/geloescht markiert werden
        let all = try modelContext.fetch(FetchDescriptor<LocalTask>())
        let hidden = all.first(where: { $0.title == "Versteckter Task" })
        XCTAssertNotNil(hidden, "Versteckter Task muss noch existieren")
        XCTAssertEqual(hidden?.sourceSystem, "reminders", "sourceSystem darf nicht geaendert werden")
        XCTAssertEqual(hidden?.externalID, "hidden-reminder", "externalID darf nicht geloescht werden")
        XCTAssertEqual(hidden?.importance, 3, "Attribute muessen erhalten bleiben")
        XCTAssertEqual(hidden?.urgency, "urgent", "urgency muss erhalten bleiben")
        XCTAssertEqual(hidden?.estimatedDuration, 60, "duration muss erhalten bleiben")
    }

    // MARK: - Regression: Normaler Sync darf nicht brechen

    /// GIVEN: Bestehender Task mit stabiler externalID
    /// WHEN: Normaler Sync laeuft
    /// THEN: Alle Attribute bleiben erhalten (keine Regression)
    func testNormalSyncPreservesAttributes() async throws {
        let task = LocalTask(
            title: "Normaler Task",
            importance: 2,
            urgency: "not_urgent",
            taskType: "maintenance",
            externalID: "stable-id-123",
            sourceSystem: "reminders"
        )
        task.estimatedDuration = 30
        task.tags = ["Routine"]
        modelContext.insert(task)
        try modelContext.save()

        let mockRepo = MockEventKitRepository()
        mockRepo.mockReminders = [
            ReminderData(id: "stable-id-123", title: "Normaler Task")
        ]
        let syncService = RemindersSyncService(eventKitRepo: mockRepo, modelContext: modelContext)

        _ = try await syncService.importFromReminders()

        let all = try modelContext.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(all.count, 1)
        let result = all.first!
        XCTAssertEqual(result.importance, 2)
        XCTAssertEqual(result.urgency, "not_urgent")
        XCTAssertEqual(result.taskType, "maintenance")
        XCTAssertEqual(result.estimatedDuration, 30)
        XCTAssertEqual(result.tags, ["Routine"])
    }
}
