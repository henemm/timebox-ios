import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for template deduplication logic.
/// Root cause: Historical GroupID generation at 3 different code paths created
/// multiple templates for the same logical series (e.g. "Zehnagel" had 4 templates).
/// The dedup function consolidates them into one template per series.
@MainActor
final class TemplateDedupTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - Dedup Core Logic

    /// Bricht wenn: deduplicateTemplates() nicht existiert oder Duplikate nicht loescht
    /// Reproduziert: "Zehnagel" mit 4 Templates → soll auf 1 reduziert werden
    func test_deduplicateTemplates_reducesDuplicatesToOne() throws {
        let context = container.mainContext

        // 4 templates for "Zehnagel" with different GroupIDs (real scenario from diagnostics)
        for i in 0..<4 {
            let t = LocalTask(title: "Zehnagel", recurrencePattern: "weekly", recurrenceGroupID: "group-\(i)")
            t.isTemplate = true
            context.insert(t)
        }
        try context.save()

        let deleted = RecurrenceService.deduplicateTemplates(in: context)

        let remaining = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isTemplate && $0.title == "Zehnagel" }
        ))
        XCTAssertEqual(remaining.count, 1, "Only 1 template should survive dedup")
        XCTAssertEqual(deleted, 3, "3 duplicates should be deleted")
    }

    /// Bricht wenn: deduplicateTemplates() das aelteste statt neueste Template behaelt
    /// Neuestes Template hat die aktuellsten Recurrence-Einstellungen
    func test_deduplicateTemplates_keepsNewestTemplate() throws {
        let context = container.mainContext

        let old = LocalTask(title: "Test", recurrencePattern: "daily", recurrenceGroupID: "old-group")
        old.isTemplate = true
        old.createdAt = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        context.insert(old)

        let newest = LocalTask(title: "Test", recurrencePattern: "custom", recurrenceInterval: 3, recurrenceGroupID: "new-group")
        newest.isTemplate = true
        newest.createdAt = Date()
        context.insert(newest)

        try context.save()

        RecurrenceService.deduplicateTemplates(in: context)

        let remaining = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isTemplate && $0.title == "Test" }
        ))
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.recurrencePattern, "custom",
                       "Survivor should be the newest template (current pattern)")
        XCTAssertEqual(remaining.first?.recurrenceGroupID, "new-group")
    }

    /// Bricht wenn: deduplicateTemplates() Kinder nicht auf Survivor-GroupID migriert
    /// KRITISCH: Ohne Migration brechen 5 von 6 GroupID-abhaengigen Flows
    func test_deduplicateTemplates_reassignsChildrenToSurvivor() throws {
        let context = container.mainContext

        // Survivor template (newest)
        let survivor = LocalTask(title: "Serie", recurrencePattern: "daily", recurrenceGroupID: "survivor-gid")
        survivor.isTemplate = true
        survivor.createdAt = Date()
        context.insert(survivor)

        // Duplicate template (older) with children
        let duplicate = LocalTask(title: "Serie", recurrencePattern: "daily", recurrenceGroupID: "old-gid")
        duplicate.isTemplate = true
        duplicate.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        context.insert(duplicate)

        // Children belonging to the duplicate
        let child1 = LocalTask(title: "Serie", dueDate: Date(), recurrencePattern: "daily", recurrenceGroupID: "old-gid")
        context.insert(child1)
        let child2 = LocalTask(title: "Serie", recurrencePattern: "daily", recurrenceGroupID: "old-gid")
        child2.isCompleted = true
        context.insert(child2)

        try context.save()

        RecurrenceService.deduplicateTemplates(in: context)

        // Both children should now have the survivor's GroupID
        XCTAssertEqual(child1.recurrenceGroupID, "survivor-gid",
                       "Open child must be reassigned to survivor GroupID")
        XCTAssertEqual(child2.recurrenceGroupID, "survivor-gid",
                       "Completed child must also be reassigned to survivor GroupID")
    }

    /// Bricht wenn: deduplicateTemplates() Templates ohne Duplikate loescht
    func test_deduplicateTemplates_noDuplicates_noOp() throws {
        let context = container.mainContext

        let t1 = LocalTask(title: "Serie A", recurrencePattern: "daily", recurrenceGroupID: "a")
        t1.isTemplate = true
        context.insert(t1)

        let t2 = LocalTask(title: "Serie B", recurrencePattern: "weekly", recurrenceGroupID: "b")
        t2.isTemplate = true
        context.insert(t2)

        try context.save()

        let deleted = RecurrenceService.deduplicateTemplates(in: context)

        XCTAssertEqual(deleted, 0, "No duplicates → nothing deleted")
        let count = try context.fetchCount(FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isTemplate }
        ))
        XCTAssertEqual(count, 2, "Both templates should remain")
    }

    /// Bricht wenn: deduplicateTemplates() nach title+pattern statt nur title gruppiert
    /// Real-World: "1 Blink lesen" hat Templates unter "daily" UND "custom" — gleiche Serie!
    func test_deduplicateTemplates_mergesAcrossPatterns() throws {
        let context = container.mainContext

        // Old pattern: daily
        let oldDaily = LocalTask(title: "1 Blink lesen", recurrencePattern: "daily", recurrenceGroupID: "daily-gid")
        oldDaily.isTemplate = true
        oldDaily.createdAt = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        context.insert(oldDaily)

        // Current pattern: custom every 3 days
        let newCustom = LocalTask(title: "1 Blink lesen", recurrencePattern: "custom", recurrenceInterval: 3, recurrenceGroupID: "custom-gid")
        newCustom.isTemplate = true
        newCustom.createdAt = Date()
        context.insert(newCustom)

        try context.save()

        RecurrenceService.deduplicateTemplates(in: context)

        let remaining = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isTemplate && $0.title == "1 Blink lesen" }
        ))
        XCTAssertEqual(remaining.count, 1,
                       "Templates with same title but different patterns should be merged")
        XCTAssertEqual(remaining.first?.recurrencePattern, "custom",
                       "Newest pattern (custom) should survive")
    }

    // MARK: - Next-Up Filter Tests

    /// Bricht wenn: Template mit isNextUp=true in Next-Up-Listen auftaucht
    /// Templates gehoeren NUR in die Wiederkehrend-View, nicht in Next-Up
    func test_template_withNextUp_shouldNotBeVisibleInBacklog() {
        let template = LocalTask(title: "Template", recurrencePattern: "daily")
        template.isTemplate = true
        template.isNextUp = true

        // isVisibleInBacklog already correctly excludes templates
        XCTAssertFalse(template.isVisibleInBacklog,
                       "Templates must never appear in backlog, even with isNextUp=true")
    }
}
