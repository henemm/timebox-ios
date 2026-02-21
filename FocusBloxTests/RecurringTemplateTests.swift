import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for the Recurring Task Template (Mother/Child) architecture.
/// Templates are persistent "mother" instances that represent a recurring series.
/// Child instances appear in Backlog/Priority when due.
@MainActor
final class RecurringTemplateTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        // Reset migration key so migration tests can run
        UserDefaults.standard.removeObject(forKey: "recurringTemplateMigrationDone")
    }

    override func tearDownWithError() throws {
        container = nil
        UserDefaults.standard.removeObject(forKey: "recurringTemplateMigrationDone")
    }

    // MARK: - Model Tests

    /// Bricht wenn: LocalTask.swift — isTemplate default geaendert
    func test_localTask_isTemplate_defaultFalse() {
        let task = LocalTask(title: "Test Task")
        XCTAssertFalse(task.isTemplate, "New tasks should not be templates by default")
    }

    /// Bricht wenn: LocalTask.swift — isVisibleInBacklog guard fuer isTemplate entfernt
    func test_template_notVisibleInBacklog() {
        let task = LocalTask(title: "Template Task", recurrencePattern: "daily")
        task.isTemplate = true
        XCTAssertFalse(task.isVisibleInBacklog, "Templates should never be visible in backlog")
    }

    /// Bricht wenn: LocalTask.swift — isVisibleInBacklog false fuer alle recurring
    func test_childTask_visibleInBacklog() {
        let task = LocalTask(title: "Child Task", dueDate: Date(), recurrencePattern: "daily")
        task.isTemplate = false
        XCTAssertTrue(task.isVisibleInBacklog, "Child tasks due today should be visible")
    }

    // MARK: - Migration Tests

    /// Bricht wenn: RecurrenceService.migrateToTemplateModel nicht Template erstellt
    func test_migrateToTemplateModel_createsTemplate() throws {
        let context = container.mainContext
        let groupID = UUID().uuidString
        let task = LocalTask(
            title: "Daily Task",
            dueDate: Date(),
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        context.insert(task)
        try context.save()

        RecurrenceService.migrateToTemplateModel(in: context)

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.recurrenceGroupID == groupID && $0.isTemplate == true }
        )
        let templates = try context.fetch(descriptor)
        XCTAssertEqual(templates.count, 1, "Migration should create exactly one template per series")
        XCTAssertNil(templates.first?.dueDate, "Template should have no due date")
    }

    /// Bricht wenn: migrateToTemplateModel erstellt doppelte Templates
    func test_migrateToTemplateModel_idempotent() throws {
        let context = container.mainContext
        let groupID = UUID().uuidString
        let template = LocalTask(title: "Template", recurrencePattern: "daily", recurrenceGroupID: groupID)
        template.isTemplate = true
        context.insert(template)

        let child = LocalTask(title: "Template", dueDate: Date(), recurrencePattern: "daily", recurrenceGroupID: groupID)
        context.insert(child)
        try context.save()

        RecurrenceService.migrateToTemplateModel(in: context)

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.recurrenceGroupID == groupID && $0.isTemplate == true }
        )
        let templates = try context.fetch(descriptor)
        XCTAssertEqual(templates.count, 1, "Migration should not create duplicate templates")
    }

    // MARK: - Spawning Tests

    /// Bricht wenn: RecurrenceService.createNextInstance nicht Template als Quelle nutzt
    func test_createNextInstance_usesTemplate() throws {
        let context = container.mainContext
        let groupID = UUID().uuidString
        let template = LocalTask(
            title: "Read Book",
            importance: 2,
            tags: ["learning"],
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        template.isTemplate = true
        context.insert(template)

        let child = LocalTask(
            title: "Read Book",
            dueDate: Date(),
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        child.importance = nil  // Child has different attributes
        child.isCompleted = true
        child.completedAt = Date()
        context.insert(child)
        try context.save()

        let newInstance = RecurrenceService.createNextInstance(from: child, in: context)

        XCTAssertNotNil(newInstance)
        XCTAssertEqual(newInstance?.importance, 2, "Should copy importance from template, not completed child")
        XCTAssertEqual(newInstance?.tags, ["learning"], "Should copy tags from template")
        XCTAssertFalse(newInstance?.isTemplate ?? true, "New instance should not be a template")
    }

    // MARK: - Completion Tests

    /// Bricht wenn: SyncEngine.completeTask guard fuer isTemplate entfernt
    func test_completeTask_templateCannotBeCompleted() throws {
        let context = container.mainContext
        let groupID = UUID().uuidString
        let template = LocalTask(title: "Template", recurrencePattern: "daily", recurrenceGroupID: groupID)
        template.isTemplate = true
        context.insert(template)
        try context.save()

        let syncEngine = SyncEngine(
            taskSource: LocalTaskSource(modelContext: context),
            modelContext: context
        )

        try syncEngine.completeTask(itemID: template.id)

        XCTAssertFalse(template.isCompleted, "Templates should not be completable")
    }

    // MARK: - Delete Template Tests

    /// Bricht wenn: SyncEngine.deleteRecurringTemplate nicht Template+offene Kinder loescht
    func test_deleteRecurringTemplate_deletesTemplateAndOpenChildren() throws {
        let context = container.mainContext
        let groupID = UUID().uuidString
        let template = LocalTask(title: "Series", recurrencePattern: "daily", recurrenceGroupID: groupID)
        template.isTemplate = true
        context.insert(template)

        let openChild = LocalTask(title: "Series", dueDate: Date(), recurrencePattern: "daily", recurrenceGroupID: groupID)
        context.insert(openChild)

        let completedChild = LocalTask(title: "Series", recurrencePattern: "daily", recurrenceGroupID: groupID)
        completedChild.isCompleted = true
        completedChild.completedAt = Date()
        context.insert(completedChild)
        try context.save()

        let syncEngine = SyncEngine(
            taskSource: LocalTaskSource(modelContext: context),
            modelContext: context
        )

        try syncEngine.deleteRecurringTemplate(groupID: groupID)

        let remaining = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.recurrenceGroupID == groupID }
        ))
        XCTAssertEqual(remaining.count, 1, "Only completed child should remain")
        XCTAssertTrue(remaining.first?.isCompleted ?? false, "Remaining task should be the completed one")
    }

    // MARK: - PlanItem Tests

    /// Bricht wenn: PlanItem.init(localTask:) isTemplate nicht durchreicht
    func test_planItem_reflectsIsTemplate() {
        let task = LocalTask(title: "Template", recurrencePattern: "daily")
        task.isTemplate = true
        let planItem = PlanItem(localTask: task)
        XCTAssertTrue(planItem.isTemplate, "PlanItem should reflect isTemplate from LocalTask")
    }
}
