import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for child instance deduplication within recurring series.
/// Root cause: deduplicateTemplates() reassigns children from duplicate templates
/// to a single survivor GroupID, but does NOT remove date-duplicate children.
/// This leaves multiple open instances for the same (groupID, dueDate).
@MainActor
final class RecurringChildDedupTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - Core Dedup Tests

    /// 3 offene Instanzen mit gleicher GroupID + gleichem Datum → nur 1 bleibt.
    /// Bricht wenn: deduplicateChildInstances nicht existiert oder Duplikate nicht loescht.
    func test_deduplicateChildInstances_removes_dateDuplicates() throws {
        let context = container.mainContext
        let groupID = UUID().uuidString
        let dueDate = Calendar.current.startOfDay(for: Date())

        // Template
        let template = LocalTask(title: "Fahrradkette reinigen", recurrencePattern: "weekly", recurrenceGroupID: groupID)
        template.isTemplate = true
        context.insert(template)

        // 3 offene Kinder mit gleichem Datum (simuliert Reassignment nach Template-Dedup)
        let child1 = LocalTask(title: "Fahrradkette reinigen", dueDate: dueDate, recurrencePattern: "weekly", recurrenceGroupID: groupID)
        child1.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        context.insert(child1)

        let child2 = LocalTask(title: "Fahrradkette reinigen", dueDate: dueDate, recurrencePattern: "weekly", recurrenceGroupID: groupID)
        child2.createdAt = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        context.insert(child2)

        let child3 = LocalTask(title: "Fahrradkette reinigen", dueDate: dueDate, recurrencePattern: "weekly", recurrenceGroupID: groupID)
        child3.createdAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        context.insert(child3)
        try context.save()

        let deleted = RecurrenceService.deduplicateChildInstances(in: context)

        XCTAssertEqual(deleted, 2, "Should delete 2 of 3 duplicate children")

        let remaining = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.recurrenceGroupID == groupID && !$0.isTemplate && !$0.isCompleted }
        ))
        XCTAssertEqual(remaining.count, 1, "Only 1 open child per (groupID, dueDate) should remain")
    }

    /// Verschiedene Daten in derselben Serie → keine Dedup (korrekt).
    /// Bricht wenn: Dedup faelschlicherweise Instanzen mit verschiedenen Daten loescht.
    func test_deduplicateChildInstances_keepsDistinctDates() throws {
        let context = container.mainContext
        let groupID = UUID().uuidString

        let template = LocalTask(title: "Waesche waschen", recurrencePattern: "weekly", recurrenceGroupID: groupID)
        template.isTemplate = true
        context.insert(template)

        // 3 Kinder mit VERSCHIEDENEN Daten (aufgelaufene Wochen)
        let child1 = LocalTask(title: "Waesche waschen", dueDate: Calendar.current.date(byAdding: .day, value: -14, to: Date())!, recurrencePattern: "weekly", recurrenceGroupID: groupID)
        context.insert(child1)

        let child2 = LocalTask(title: "Waesche waschen", dueDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, recurrencePattern: "weekly", recurrenceGroupID: groupID)
        context.insert(child2)

        let child3 = LocalTask(title: "Waesche waschen", dueDate: Date(), recurrencePattern: "weekly", recurrenceGroupID: groupID)
        context.insert(child3)
        try context.save()

        let deleted = RecurrenceService.deduplicateChildInstances(in: context)

        XCTAssertEqual(deleted, 0, "No duplicates — all have distinct dates")

        let remaining = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.recurrenceGroupID == groupID && !$0.isTemplate && !$0.isCompleted }
        ))
        XCTAssertEqual(remaining.count, 3, "All 3 children should remain (different dates)")
    }

    /// Completed Kinder duerfen nicht dedupliziert werden.
    /// Bricht wenn: Dedup auch completed Instanzen loescht.
    func test_deduplicateChildInstances_ignoresCompletedChildren() throws {
        let context = container.mainContext
        let groupID = UUID().uuidString
        let dueDate = Calendar.current.startOfDay(for: Date())

        let template = LocalTask(title: "Lesen", recurrencePattern: "daily", recurrenceGroupID: groupID)
        template.isTemplate = true
        context.insert(template)

        // 1 offenes + 1 erledigtes Kind mit gleichem Datum
        let openChild = LocalTask(title: "Lesen", dueDate: dueDate, recurrencePattern: "daily", recurrenceGroupID: groupID)
        context.insert(openChild)

        let completedChild = LocalTask(title: "Lesen", dueDate: dueDate, recurrencePattern: "daily", recurrenceGroupID: groupID)
        completedChild.isCompleted = true
        completedChild.completedAt = Date()
        context.insert(completedChild)
        try context.save()

        let deleted = RecurrenceService.deduplicateChildInstances(in: context)

        XCTAssertEqual(deleted, 0, "Completed child should not count as duplicate")
    }

    /// Voller Startup-Zyklus: migrate → dedup templates → dedup children → repair.
    /// Nach dem Zyklus darf pro Serie+Datum nur 1 offene Instanz existieren.
    /// Bricht wenn: Startup-Sequenz Kinder-Duplikate nicht bereinigt.
    func test_fullStartupCycle_noDuplicateChildrenAfterDedup() throws {
        let context = container.mainContext

        // Simuliere historische GroupID-Fragmentierung:
        // 3 completed Tasks mit VERSCHIEDENEN GroupIDs, alle "Fahrradkette reinigen"
        let groupA = UUID().uuidString
        let groupB = UUID().uuidString
        let groupC = UUID().uuidString
        let dueDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

        // Offene Kinder mit verschiedenen GroupIDs (vor Dedup)
        let childA = LocalTask(title: "Fahrradkette reinigen", dueDate: dueDate, recurrencePattern: "weekly", recurrenceGroupID: groupA)
        context.insert(childA)

        let childB = LocalTask(title: "Fahrradkette reinigen", dueDate: dueDate, recurrencePattern: "weekly", recurrenceGroupID: groupB)
        context.insert(childB)

        let childC = LocalTask(title: "Fahrradkette reinigen", dueDate: dueDate, recurrencePattern: "weekly", recurrenceGroupID: groupC)
        context.insert(childC)
        try context.save()

        // Voller Startup-Zyklus
        RecurrenceService.migrateToTemplateModel(in: context)
        RecurrenceService.deduplicateTemplates(in: context)
        RecurrenceService.deduplicateChildInstances(in: context)
        RecurrenceService.repairOrphanedRecurringSeries(in: context)

        // Nach dem Zyklus: nur 1 offene Instanz pro Datum
        let openChildren = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted && !$0.isTemplate }
        ))
        let fahrradketteChildren = openChildren.filter { $0.title == "Fahrradkette reinigen" }
        XCTAssertEqual(fahrradketteChildren.count, 1,
                       "After full startup cycle, only 1 open child per series+date should exist")
    }

    /// Idempotenz: Zweimal ausfuehren aendert nichts.
    func test_deduplicateChildInstances_idempotent() throws {
        let context = container.mainContext
        let groupID = UUID().uuidString
        let dueDate = Calendar.current.startOfDay(for: Date())

        let template = LocalTask(title: "Test", recurrencePattern: "daily", recurrenceGroupID: groupID)
        template.isTemplate = true
        context.insert(template)

        let child1 = LocalTask(title: "Test", dueDate: dueDate, recurrencePattern: "daily", recurrenceGroupID: groupID)
        context.insert(child1)

        let child2 = LocalTask(title: "Test", dueDate: dueDate, recurrencePattern: "daily", recurrenceGroupID: groupID)
        context.insert(child2)
        try context.save()

        let firstRun = RecurrenceService.deduplicateChildInstances(in: context)
        XCTAssertEqual(firstRun, 1, "First run should delete 1 duplicate")

        let secondRun = RecurrenceService.deduplicateChildInstances(in: context)
        XCTAssertEqual(secondRun, 0, "Second run should find no duplicates")
    }
}
