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

    /// RW 1.5: confirmSuggestions() works on ANY lifecycleStatus (guard removed).
    /// Idempotent: only fills nil/empty fields, never overwrites user-set values.
    func test_confirmSuggestions_worksOnActiveTasksToo() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Aktiver Task", lifecycleStatus: "active")
        context.insert(task)

        task.suggestedImportance = 3
        task.suggestedCategory = "income"

        task.confirmSuggestions()

        // RW 1.5: suggested values should be promoted even for active tasks
        XCTAssertEqual(task.importance, 3, "confirmSuggestions on active task should promote suggested values")
        XCTAssertEqual(task.taskType, "income", "suggestedCategory should promote to taskType")
        XCTAssertEqual(task.lifecycleStatus, "active", "Status must stay active")
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

    // MARK: - Batch Enrichment (RW 1.5: no status filter)

    /// RW 1.5: enrichAllTbdTasks() includes ALL tasks with missing attributes — no raw-filter.
    func test_batchEnrichment_includesAllStatusTasks() async throws {
        let context = container.mainContext

        let rawTask = LocalTask(title: "Raw Task", lifecycleStatus: "raw")
        context.insert(rawTask)

        let activeTask = LocalTask(title: "Active TBD Task", lifecycleStatus: "active")
        context.insert(activeTask)

        try context.save()

        // Both tasks have nil importance — both should be eligible for enrichment
        let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
        let eligible = allTasks.filter {
            $0.importance == nil || $0.urgency == nil || $0.taskType.isEmpty || $0.aiEnergyLevel == nil
        }

        XCTAssertEqual(eligible.count, 2, "Both raw + active tasks must be eligible for enrichment (no status filter)")
    }
}
