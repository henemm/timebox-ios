import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests für FEATURE_031: SprintPickerSheet Logik
/// Testet den Next-Up Filter der im SprintPickerSheet verwendet wird.
/// In RED Phase: Tests kompilieren, schlagen aber fehl weil SprintPickerSheet nicht existiert.
@MainActor
final class SprintPickerTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([LocalTask.self, TaskMetadata.self, TaskFailureRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    /// Verhalten: SprintPickerSheet existiert als View-Typ
    /// Bricht wenn: SprintPickerSheet.swift gelöscht oder umbenannt wird
    func test_sprintPickerSheet_typeExists() throws {
        // SprintPickerSheet muss als Typ existieren und eine statische filterNextUpTasks Methode haben.
        // Wir prüfen das, indem wir den Typ direkt referenzieren.
        // RED: Kompiliert nicht → Typ existiert nicht
        let viewType = String(describing: SprintPickerSheet.self)
        XCTAssertEqual(viewType, "SprintPickerSheet", "SprintPickerSheet muss als View existieren")
    }

    /// Verhalten: filterNextUpTasks gibt nur isNextUp=true, !isCompleted Tasks zurück
    /// Bricht wenn: SprintPickerSheet.filterNextUpTasks — Predicate ändert sich
    func test_filterNextUpTasks_returnsOnlyActiveNextUp() throws {
        let nextUpTask = LocalTask(title: "Next Up Task", importance: 2, estimatedDuration: 30, urgency: "urgent")
        nextUpTask.isNextUp = true

        let backlogTask = LocalTask(title: "Backlog Task", importance: 1, estimatedDuration: 15, urgency: "not_urgent")
        backlogTask.isNextUp = false

        let completedNextUp = LocalTask(title: "Done Task", importance: 3, estimatedDuration: 20, urgency: "urgent")
        completedNextUp.isNextUp = true
        completedNextUp.isCompleted = true

        context.insert(nextUpTask)
        context.insert(backlogTask)
        context.insert(completedNextUp)
        try context.save()

        // RED: SprintPickerSheet.filterNextUpTasks existiert nicht → Build Failure
        let filtered = SprintPickerSheet.filterNextUpTasks(from: context)

        XCTAssertEqual(filtered.count, 1, "Nur aktive Next-Up Tasks")
        XCTAssertEqual(filtered.first?.title, "Next Up Task")
    }

    /// Verhalten: Filter schließt Template-Tasks aus
    /// Bricht wenn: SprintPickerSheet.filterNextUpTasks — isTemplate-Check fehlt
    func test_filterNextUpTasks_excludesTemplates() throws {
        let template = LocalTask(title: "Weekly Template", importance: 2, estimatedDuration: 30, urgency: "urgent")
        template.isNextUp = true
        template.isTemplate = true

        let normalTask = LocalTask(title: "Normal Task", importance: 2, estimatedDuration: 30, urgency: "urgent")
        normalTask.isNextUp = true

        context.insert(template)
        context.insert(normalTask)
        try context.save()

        let filtered = SprintPickerSheet.filterNextUpTasks(from: context)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Normal Task")
    }
}
