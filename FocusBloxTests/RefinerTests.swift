import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class RefinerTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - confirmSuggestions() Tests

    /// Verhalten: confirmSuggestions() kopiert alle suggested*-Werte in Hauptfelder und setzt Status auf "active"
    /// Bricht wenn: LocalTask.confirmSuggestions() entfernt wird oder suggested*→Hauptfeld-Mapping fehlt
    func test_confirmSuggestions_promotesAllSuggestedFieldsToMainFields() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Mama anrufen wegen Geburtstagsfeier", lifecycleStatus: "raw")
        context.insert(task)

        task.suggestedCategory = "giving_back"
        task.suggestedDuration = 15
        task.suggestedImportance = 2
        task.suggestedUrgency = "not_urgent"
        task.suggestedEnergyLevel = "low"

        task.confirmSuggestions()

        XCTAssertEqual(task.taskType, "giving_back", "suggestedCategory should promote to taskType")
        XCTAssertEqual(task.estimatedDuration, 15, "suggestedDuration should promote to estimatedDuration")
        XCTAssertEqual(task.importance, 2, "suggestedImportance should promote to importance")
        XCTAssertEqual(task.urgency, "not_urgent", "suggestedUrgency should promote to urgency")
        XCTAssertEqual(task.aiEnergyLevel, "low", "suggestedEnergyLevel should promote to aiEnergyLevel")
        XCTAssertEqual(task.lifecycleStatus, "active", "lifecycleStatus should transition to active")
    }

    /// Verhalten: confirmSuggestions() ueberschreibt KEINE bereits gesetzten Hauptfelder
    /// Bricht wenn: Guard-Bedingung (if importance == nil) in confirmSuggestions() entfernt wird
    func test_confirmSuggestions_doesNotOverwriteUserSetMainFields() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Steuer machen", importance: 1, lifecycleStatus: "raw")
        task.urgency = "urgent"
        task.taskType = "income"
        context.insert(task)

        task.suggestedImportance = 3
        task.suggestedUrgency = "not_urgent"
        task.suggestedCategory = "maintenance"
        task.suggestedDuration = 60
        task.suggestedEnergyLevel = "high"

        task.confirmSuggestions()

        XCTAssertEqual(task.importance, 1, "User-set importance=1 must NOT be overwritten by suggestion=3")
        XCTAssertEqual(task.urgency, "urgent", "User-set urgency must NOT be overwritten")
        XCTAssertEqual(task.taskType, "income", "User-set taskType must NOT be overwritten")
        // Fields that WERE nil should be promoted:
        XCTAssertEqual(task.estimatedDuration, 60, "nil estimatedDuration should get suggested value")
        XCTAssertEqual(task.aiEnergyLevel, "high", "nil aiEnergyLevel should get suggested value")
    }

    /// Verhalten: confirmSuggestions() ist ein No-Op wenn lifecycleStatus != "raw"
    /// Bricht wenn: Guard (lifecycleStatus == .raw) in confirmSuggestions() entfernt wird
    func test_confirmSuggestions_isNoOpForNonRawTasks() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Aktiver Task", lifecycleStatus: "active")
        context.insert(task)

        task.suggestedImportance = 3
        task.suggestedCategory = "income"

        task.confirmSuggestions()

        // Main fields should NOT be changed (guard returns early)
        XCTAssertNil(task.importance, "confirmSuggestions on active task must be no-op")
        XCTAssertEqual(task.taskType, "", "taskType must remain empty for active task")
        XCTAssertEqual(task.lifecycleStatus, "active", "Status must stay active, not re-set")
    }

    /// Verhalten: confirmSuggestions() clampt importance auf 1-3
    /// Bricht wenn: max(1, min(3, imp)) Clamping in confirmSuggestions() entfernt wird
    func test_confirmSuggestions_clampsImportanceTo1Through3() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test", lifecycleStatus: "raw")
        context.insert(task)

        task.suggestedImportance = 5  // out of range

        task.confirmSuggestions()

        XCTAssertEqual(task.importance, 3, "Out-of-range importance=5 should be clamped to 3")
    }

    // MARK: - suggested* Field Existence Tests

    /// Verhalten: LocalTask hat suggestedCategory Feld
    /// Bricht wenn: suggestedCategory Property von LocalTask entfernt wird
    func test_localTask_hasSuggestedCategoryField() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test", lifecycleStatus: "raw")
        context.insert(task)

        XCTAssertNil(task.suggestedCategory, "suggestedCategory should default to nil")
        task.suggestedCategory = "income"
        XCTAssertEqual(task.suggestedCategory, "income")
    }

    /// Verhalten: Suggested-Felder schreiben NICHT in Hauptfelder
    /// Bricht wenn: suggestedImportance und importance versehentlich das gleiche Feld sind
    func test_suggestedFields_areIndependentFromMainFields() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test", lifecycleStatus: "raw")
        context.insert(task)

        task.suggestedImportance = 3
        task.suggestedUrgency = "urgent"
        task.suggestedCategory = "income"

        // Main fields must still be nil/empty
        XCTAssertNil(task.importance, "Setting suggestedImportance must NOT affect importance")
        XCTAssertNil(task.urgency, "Setting suggestedUrgency must NOT affect urgency")
        XCTAssertEqual(task.taskType, "", "Setting suggestedCategory must NOT affect taskType")
    }

    // MARK: - Batch Enrichment Guard

    /// Verhalten: enrichAllTbdTasks() ueberspringt .raw Tasks
    /// Bricht wenn: Guard `task.lifecycleStatus != "raw"` aus performBatchEnrichment() entfernt wird
    func test_batchEnrichment_skipsRawTasks() async throws {
        let context = container.mainContext

        // Raw task — should be skipped by batch enrichment
        let rawTask = LocalTask(title: "Raw Task", lifecycleStatus: "raw")
        context.insert(rawTask)

        // Active TBD task — should be eligible for enrichment
        let activeTask = LocalTask(title: "Active TBD Task", lifecycleStatus: "active")
        context.insert(activeTask)

        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        _ = await service.enrichAllTbdTasks()

        // Raw task's main fields must remain nil (was skipped)
        XCTAssertNil(rawTask.importance, "Raw task must be skipped by batch enrichment")
        XCTAssertNil(rawTask.urgency, "Raw task must be skipped by batch enrichment")
    }
}
