import XCTest
import SwiftData
@testable import FocusBloxMac

/// Tests für Bug: Wiederkehrender Task nach manuellem Löschen dauerhaft eingefroren.
/// Root Cause: lastSkippedDate blockiert repairOrphanedRecurringSeries() permanent,
/// statt nur für einen Zyklus.
@MainActor
final class RecurrenceServiceRepairTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([LocalTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func makeTemplate(
        groupID: String,
        pattern: String = "daily",
        weekdays: [Int]? = nil,
        lastSkippedDate: Date? = nil
    ) -> LocalTask {
        let template = LocalTask(title: "Klavier spielen", importance: 1)
        template.recurrencePattern = pattern
        template.recurrenceWeekdays = weekdays
        template.recurrenceGroupID = groupID
        template.isTemplate = true
        template.lastSkippedDate = lastSkippedDate
        context.insert(template)
        return template
    }

    // MARK: - AC-1: Einmaliges Löschen blockiert nicht dauerhaft

    /// Szenario: Daily-Task wurde vor 36 Stunden gelöscht (lastSkippedDate = vor 36h).
    /// Letzte Completion: vor 3 Tagen.
    /// Erwartung: repairOrphanedRecurringSeries() erstellt eine neue Instanz,
    /// weil 36h > 24h (ein daily-Zyklus) — die Grenze ist überschritten.
    /// Beweist die neue Zyklus-Logik: AC-1 (>Zyklus → repair) + lastSkippedDate-Reset.
    func testRepairAfterSingleDeletion_weeklyTask_repairsAfterOneCycle() throws {
        let groupID = UUID().uuidString
        let now = Date()
        let thirtySixHoursAgo = now.addingTimeInterval(-36 * 3600)
        let threeDaysAgo = now.addingTimeInterval(-3 * 86400)

        let template = makeTemplate(
            groupID: groupID,
            pattern: "daily",
            weekdays: nil,
            lastSkippedDate: thirtySixHoursAgo
        )

        let child = LocalTask(title: "Klavier spielen", importance: 1)
        child.recurrencePattern = "daily"
        child.recurrenceWeekdays = nil
        child.recurrenceGroupID = groupID
        child.isTemplate = false
        child.isCompleted = true
        child.completedAt = threeDaysAgo
        child.dueDate = threeDaysAgo
        context.insert(child)
        try context.save()

        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)

        XCTAssertGreaterThan(repaired, 0, "Nach einem vollen Zyklus muss die Serie repariert werden")

        let fetchedTemplate = try XCTUnwrap(
            RecurrenceService.findTemplate(groupID: groupID, in: context),
            "Template muss noch existieren"
        )
        XCTAssertNil(fetchedTemplate.lastSkippedDate, "lastSkippedDate muss nach Repair auf nil gesetzt werden")

        _ = template
    }

    // MARK: - AC-2: Zeitnahes Löschen wird korrekt blockiert

    /// Szenario: Daily-Task wurde vor 12 Stunden gelöscht (lastSkippedDate = vor 12h).
    /// Letzte Completion: vor 2 Tagen.
    /// Erwartung: Keine neue Instanz — 12h < 24h (noch im Zyklus).
    /// Beweist den Boundary: AC-1 (36h → repaired) vs AC-2 (12h → blockiert).
    func testRepairAfterSingleDeletion_weeklyTask_blocksBeforeOneCycle() throws {
        let groupID = UUID().uuidString
        let now = Date()
        let twelveHoursAgo = now.addingTimeInterval(-12 * 3600)
        let twoDaysAgo = now.addingTimeInterval(-2 * 86400)

        _ = makeTemplate(
            groupID: groupID,
            pattern: "daily",
            weekdays: nil,
            lastSkippedDate: twelveHoursAgo
        )

        let child = LocalTask(title: "Klavier spielen", importance: 1)
        child.recurrencePattern = "daily"
        child.recurrenceWeekdays = nil
        child.recurrenceGroupID = groupID
        child.isTemplate = false
        child.isCompleted = true
        child.completedAt = twoDaysAgo
        child.dueDate = twoDaysAgo
        context.insert(child)
        try context.save()

        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)

        XCTAssertEqual(repaired, 0, "Innerhalb desselben Zyklus darf keine neue Instanz erstellt werden")
    }

    // MARK: - AC-3: Serie ohne je Completion wird nach Zyklus repariert

    /// Szenario: Daily-Task, noch NIE abgeschlossen (completedAt == nil),
    /// wurde vor 36 Stunden gelöscht (lastSkippedDate = vor 36h).
    /// Erwartung: Repair erlaubt, weil 36h > 24h (ein daily-Zyklus abgelaufen).
    func testRepairWithNilCompletedAt_repairsAfterOneCycle() throws {
        let groupID = UUID().uuidString
        let now = Date()
        let thirtySixHoursAgo = now.addingTimeInterval(-36 * 3600)
        let threeDaysAgo = now.addingTimeInterval(-3 * 86400)

        _ = makeTemplate(
            groupID: groupID,
            pattern: "daily",
            weekdays: nil,
            lastSkippedDate: thirtySixHoursAgo
        )

        let child = LocalTask(title: "Klavier spielen", importance: 1)
        child.recurrencePattern = "daily"
        child.recurrenceWeekdays = nil
        child.recurrenceGroupID = groupID
        child.isTemplate = false
        child.isCompleted = true
        child.completedAt = nil
        child.dueDate = threeDaysAgo
        context.insert(child)
        try context.save()

        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)

        XCTAssertGreaterThan(repaired, 0, "Serie ohne completedAt muss nach Zyklus-Ablauf repariert werden")
    }
}
