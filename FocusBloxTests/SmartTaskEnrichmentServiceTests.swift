import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class SmartTaskEnrichmentServiceTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        // Ensure AI enrichment is enabled for tests
        UserDefaults.standard.set(true, forKey: "aiScoringEnabled")
    }

    override func tearDownWithError() throws {
        container = nil
        UserDefaults.standard.removeObject(forKey: "aiScoringEnabled")
    }

    // MARK: - Guard Conditions

    /// GIVEN: AI enrichment is disabled via settings
    /// WHEN: enrichTask() is called
    /// THEN: Task attributes should remain unchanged (nil)
    func test_enrichTask_skipsWhenDisabled() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task")
        context.insert(task)
        try context.save()

        // Disable enrichment
        UserDefaults.standard.set(false, forKey: "aiScoringEnabled")

        let service = SmartTaskEnrichmentService(modelContext: context)
        await service.enrichTask(task)

        // Attributes should remain nil (enrichment was skipped)
        XCTAssertNil(task.importance, "Importance should remain nil when enrichment is disabled")
        XCTAssertNil(task.urgency, "Urgency should remain nil when enrichment is disabled")
    }

    /// GIVEN: A task with user-set importance
    /// WHEN: enrichTask() is called
    /// THEN: User-set importance should NOT be overwritten
    func test_enrichTask_preservesUserSetImportance() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Important Meeting", importance: 3)
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        await service.enrichTask(task)

        XCTAssertEqual(task.importance, 3, "User-set importance should be preserved")
    }

    /// GIVEN: A task with user-set urgency
    /// WHEN: enrichTask() is called
    /// THEN: User-set urgency should NOT be overwritten
    func test_enrichTask_preservesUserSetUrgency() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Routine Task", urgency: "not_urgent")
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        await service.enrichTask(task)

        XCTAssertEqual(task.urgency, "not_urgent", "User-set urgency should be preserved")
    }

    /// GIVEN: A task with user-set taskType
    /// WHEN: enrichTask() is called
    /// THEN: User-set taskType should NOT be overwritten
    func test_enrichTask_preservesUserSetTaskType() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Study Swift", taskType: "learning")
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        await service.enrichTask(task)

        XCTAssertEqual(task.taskType, "learning", "User-set taskType should be preserved")
    }

    // MARK: - Batch Enrichment Filter

    /// GIVEN: Incomplete tasks — some with attributes, some without
    /// WHEN: enrichAllTbdTasks() is called with enrichment disabled
    /// THEN: Should return 0 (no tasks enriched)
    func test_enrichAllTbdTasks_returnsZeroWhenDisabled() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task without attributes")
        context.insert(task)
        try context.save()

        UserDefaults.standard.set(false, forKey: "aiScoringEnabled")

        let service = SmartTaskEnrichmentService(modelContext: context)
        let count = await service.enrichAllTbdTasks()

        XCTAssertEqual(count, 0, "Should return 0 when enrichment is disabled")
    }

    // MARK: - Availability

    /// GIVEN: SmartTaskEnrichmentService
    /// WHEN: Checking isAvailable
    /// THEN: Should return consistent Bool
    func test_isAvailable_returnsConsistentBool() {
        let first = SmartTaskEnrichmentService.isAvailable
        let second = SmartTaskEnrichmentService.isAvailable
        XCTAssertEqual(first, second, "isAvailable should return consistent results")
    }

    // MARK: - Similar-Task Context (Feature B)

    /// Verhalten: fetchRecentTaskContext() gibt String mit Task-Infos zurueck wenn Tasks mit Attributen existieren
    /// Bricht wenn: SmartTaskEnrichmentService.fetchRecentTaskContext() entfernt wird oder leeren String liefert
    func test_fetchRecentTaskContext_returnsContextWithAttributes() async throws {
        let context = container.mainContext

        let task1 = LocalTask(title: "Lohnsteuer abgeben", importance: 3, urgency: "urgent", taskType: "income")
        context.insert(task1)
        let task2 = LocalTask(title: "Wohnung putzen", importance: 1, taskType: "maintenance")
        context.insert(task2)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let result = service.fetchRecentTaskContext()

        XCTAssertTrue(result.contains("Lohnsteuer"), "Context should contain task title 'Lohnsteuer'")
        XCTAssertTrue(result.contains("income"), "Context should contain taskType 'income'")
        XCTAssertTrue(result.contains("Wohnung putzen"), "Context should contain task title 'Wohnung putzen'")
    }

    /// Verhalten: fetchRecentTaskContext() ignoriert Tasks ohne jegliche Attribute
    /// Bricht wenn: Fetch-Filter keine Attribut-Filterung hat
    func test_fetchRecentTaskContext_ignoresTasksWithoutAttributes() async throws {
        let context = container.mainContext

        let emptyTask = LocalTask(title: "Leere Task")
        context.insert(emptyTask)
        let richTask = LocalTask(title: "Steuer machen", importance: 3, taskType: "income")
        context.insert(richTask)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let result = service.fetchRecentTaskContext()

        XCTAssertTrue(result.contains("Steuer machen"), "Context should contain rich task")
        XCTAssertFalse(result.contains("Leere Task"), "Context should NOT contain empty task")
    }

    /// Verhalten: fetchRecentTaskContext() gibt leeren String zurueck wenn keine Tasks mit Attributen existieren
    /// Bricht wenn: Methode auch ohne passende Tasks Text generiert
    func test_fetchRecentTaskContext_returnsEmptyWhenNoAttributedTasks() async throws {
        let context = container.mainContext

        let task = LocalTask(title: "Irgendwas")
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let result = service.fetchRecentTaskContext()

        XCTAssertTrue(result.isEmpty, "Context should be empty when no tasks have attributes")
    }

    /// Verhalten: buildPrompt() enthaelt "Bestehende Tasks" Block wenn Kontext vorhanden
    /// Bricht wenn: buildPrompt() den Kontext-Block nicht einbaut
    func test_buildPrompt_includesSimilarTaskContext() async throws {
        let context = container.mainContext

        let existing = LocalTask(title: "Steuererklaerung", importance: 3, taskType: "income")
        context.insert(existing)
        let newTask = LocalTask(title: "Lohnsteuer abgeben")
        context.insert(newTask)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        let prompt = service.buildPrompt(for: newTask)

        XCTAssertTrue(prompt.contains("Bestehende Tasks"), "Prompt should contain similar task context header")
        XCTAssertTrue(prompt.contains("Steuererklaerung"), "Prompt should include existing task title")
    }

    // MARK: - createTask Enrichment Integration

    /// GIVEN: A task created via LocalTaskSource.createTask() with no attributes
    /// WHEN: AI enrichment is available and enabled
    /// THEN: The returned task should have enriched attributes (importance, urgency, taskType)
    /// NOTE: This test validates the FIX — enrichment integrated into createTask()
    func test_createTask_enrichesAttributes_whenAvailable() async throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)

        let task = try await source.createTask(title: "Steuererklarung abgeben")

        if SmartTaskEnrichmentService.isAvailable {
            // After createTask(), enrichment should have run
            // Task should have AI-filled attributes
            XCTAssertNotNil(task.importance, "Importance should be enriched after createTask()")
            XCTAssertNotNil(task.urgency, "Urgency should be enriched after createTask()")
            XCTAssertFalse(task.taskType.isEmpty, "TaskType should be enriched after createTask()")
        } else {
            // If AI is not available, attributes remain nil — this is correct behavior
            XCTAssertNil(task.importance, "Importance should be nil when AI is not available")
        }
    }

    /// GIVEN: A task created via createTask() with user-provided importance
    /// WHEN: Enrichment runs
    /// THEN: User-provided importance should be preserved, other fields enriched
    func test_createTask_preservesUserAttributes_whileEnrichingOthers() async throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)

        let task = try await source.createTask(
            title: "Einkaufen gehen",
            importance: 2,
            urgency: "not_urgent"
        )

        // User-set values must be preserved regardless of AI availability
        XCTAssertEqual(task.importance, 2, "User-set importance must be preserved")
        XCTAssertEqual(task.urgency, "not_urgent", "User-set urgency must be preserved")

        if SmartTaskEnrichmentService.isAvailable {
            // taskType was not user-set, so enrichment should fill it
            XCTAssertFalse(task.taskType.isEmpty || task.taskType == "maintenance",
                          "taskType should be enriched when user didn't set it")
        }
    }
}
