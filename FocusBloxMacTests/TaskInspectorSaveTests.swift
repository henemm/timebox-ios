import XCTest
import SwiftData
@testable import FocusBloxMac

/// Bug #253: saveAndNotify() ruft sich selbst rekursiv auf → Stack Overflow
/// Diese Tests prüfen ob Task-Änderungen korrekt persistiert werden.
@MainActor
final class TaskInspectorSaveTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([LocalTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    /// Verhalten: taskType ändern und speichern → neuer Wert muss persistiert sein
    /// Bricht wenn: modelContext.save() nicht aufgerufen wird (z.B. Rekursion statt Save)
    func test_saveTaskType_persists() throws {
        let task = LocalTask(title: "Test-Task")
        task.taskType = "income"
        context.insert(task)
        try context.save()

        task.taskType = "maintenance"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(fetched.first?.taskType, "maintenance",
                       "taskType muss nach Save den neuen Wert haben")
    }

    /// Verhalten: importance ändern und speichern → neuer Wert muss persistiert sein
    /// Bricht wenn: Save-Funktion crasht statt zu speichern
    func test_saveImportance_persists() throws {
        let task = LocalTask(title: "Wichtiger Task")
        task.importance = 1
        context.insert(task)
        try context.save()

        task.importance = 3
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(fetched.first?.importance, 3,
                       "importance muss nach Save den neuen Wert haben")
    }

    /// Verhalten: Mehrere Saves hintereinander → kein Stack Overflow
    /// Bricht wenn: saveAndNotify() sich selbst rekursiv aufruft
    func test_multipleSaves_noStackOverflow() throws {
        let task = LocalTask(title: "Multi-Save")
        context.insert(task)
        try context.save()

        for i in 1...10 {
            task.importance = i % 4
            try context.save()
        }

        let fetched = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(fetched.count, 1, "Genau 1 Task nach 10 Saves")
    }
}
