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
