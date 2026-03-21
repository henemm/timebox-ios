import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class LifecycleStatusTests: XCTestCase {

    var container: ModelContainer!
    var source: LocalTaskSource!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        source = LocalTaskSource(modelContext: container.mainContext)
    }

    override func tearDownWithError() throws {
        container = nil
        source = nil
    }

    // MARK: - Enum Values

    /// Verhalten: TaskLifecycleStatus Enum hat exakt 3 Cases mit korrekten rawValues
    /// Bricht wenn: TaskLifecycleStatus Enum nicht existiert oder Cases umbenannt werden
    func test_lifecycleStatusEnum_hasCorrectRawValues() {
        XCTAssertEqual(TaskLifecycleStatus.raw.rawValue, "raw")
        XCTAssertEqual(TaskLifecycleStatus.refined.rawValue, "refined")
        XCTAssertEqual(TaskLifecycleStatus.active.rawValue, "active")
    }

    /// Verhalten: Enum ist aus String initialisierbar (fuer CloudKit-Deserialisierung)
    /// Bricht wenn: TaskLifecycleStatus nicht String-RawRepresentable ist
    func test_lifecycleStatusEnum_initFromString() {
        XCTAssertEqual(TaskLifecycleStatus(rawValue: "raw"), .raw)
        XCTAssertEqual(TaskLifecycleStatus(rawValue: "refined"), .refined)
        XCTAssertEqual(TaskLifecycleStatus(rawValue: "active"), .active)
        XCTAssertNil(TaskLifecycleStatus(rawValue: "invalid"))
    }

    // MARK: - Default Value (Migration)

    /// Verhalten: Bestehende Tasks (ohne explizites lifecycleStatus) bekommen "active"
    /// Bricht wenn: Default-Wert in LocalTask.lifecycleStatus nicht "active" ist
    func test_existingTasks_defaultToActive() {
        let context = container.mainContext
        let task = LocalTask(title: "Existing Task")
        context.insert(task)

        XCTAssertEqual(task.lifecycleStatus, "active",
                       "Bestehende Tasks muessen Default 'active' haben fuer Rueckwaerts-Kompatibilitaet")
    }

    // MARK: - Fetch Filter

    /// Verhalten: fetchIncompleteTasks() schliesst Tasks mit lifecycleStatus "raw" aus
    /// Bricht wenn: Filter in LocalTaskSource.fetchIncompleteTasks() fehlt oder falsch ist
    func test_rawTasks_excludedFromFetch() async throws {
        let context = container.mainContext

        let rawTask = LocalTask(title: "Raw Task")
        rawTask.lifecycleStatus = TaskLifecycleStatus.raw.rawValue
        context.insert(rawTask)

        let activeTask = LocalTask(title: "Active Task")
        activeTask.lifecycleStatus = TaskLifecycleStatus.active.rawValue
        context.insert(activeTask)

        try context.save()

        let fetched = try await source.fetchIncompleteTasks()
        let titles = fetched.map(\.title)

        XCTAssertFalse(titles.contains("Raw Task"),
                       "Raw-Tasks duerfen NICHT in fetchIncompleteTasks() erscheinen")
        XCTAssertTrue(titles.contains("Active Task"),
                      "Active-Tasks muessen in fetchIncompleteTasks() erscheinen")
    }

    /// Verhalten: fetchIncompleteTasks() enthaelt Tasks mit lifecycleStatus "refined"
    /// Bricht wenn: Filter faelschlicherweise auch "refined" ausschliesst
    func test_refinedTasks_includedInFetch() async throws {
        let context = container.mainContext

        let refinedTask = LocalTask(title: "Refined Task")
        refinedTask.lifecycleStatus = TaskLifecycleStatus.refined.rawValue
        context.insert(refinedTask)

        try context.save()

        let fetched = try await source.fetchIncompleteTasks()
        let titles = fetched.map(\.title)

        XCTAssertTrue(titles.contains("Refined Task"),
                      "Refined-Tasks muessen in fetchIncompleteTasks() erscheinen")
    }

    // MARK: - PlanItem Mapping

    /// Verhalten: PlanItem(localTask:) uebernimmt lifecycleStatus vom LocalTask
    /// Bricht wenn: PlanItem.init(localTask:) das lifecycleStatus-Feld nicht kopiert
    func test_planItem_copiesLifecycleStatus() {
        let context = container.mainContext
        let task = LocalTask(title: "Test")
        task.lifecycleStatus = TaskLifecycleStatus.raw.rawValue
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.lifecycleStatus, "raw",
                       "PlanItem muss lifecycleStatus vom LocalTask uebernehmen")
    }

    // MARK: - createTask with lifecycleStatus

    /// Verhalten: createTask() mit lifecycleStatus-Parameter speichert den Wert
    /// Bricht wenn: createTask() den lifecycleStatus-Parameter nicht akzeptiert oder ignoriert
    func test_createTask_withRawStatus() async throws {
        let task = try await source.createTask(
            title: "Quick Dump Task",
            lifecycleStatus: TaskLifecycleStatus.raw.rawValue
        )

        XCTAssertEqual(task.lifecycleStatus, "raw",
                       "createTask mit lifecycleStatus 'raw' muss diesen Wert speichern")
    }
}
