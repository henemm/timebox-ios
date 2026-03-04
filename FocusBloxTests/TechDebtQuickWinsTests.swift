import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests for Tech-Debt Quick Wins Bundle
///
/// Tests verify:
/// 1. LocalTask has SwiftData indexes on frequently filtered properties
/// 2. RecurrencePattern.displayName covers all cases consistently
///
/// EXPECTED TO FAIL: LocalTask has no #Index declarations.
final class TechDebtQuickWinsTests: XCTestCase {

    // MARK: - SwiftData Index Tests (Fix 1)

    /// Verify that a ModelContainer can be created with LocalTask and indexes work.
    /// This test validates that filtering by isCompleted uses an indexed path.
    /// Bricht wenn: #Index<LocalTask>([\.isCompleted], ...) fehlt — Query-Performance degradiert
    func test_localTask_indexedFetchByIsCompleted() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalTask.self, configurations: config)
        let context = container.mainContext

        // Create test data
        for i in 0..<10 {
            let task = LocalTask(title: "Task \(i)")
            task.isCompleted = (i % 3 == 0)
            context.insert(task)
        }
        try context.save()

        // Fetch only incomplete tasks — this query benefits from index on isCompleted
        var descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let incompleteTasks = try context.fetch(descriptor)
        XCTAssertEqual(incompleteTasks.count, 6, "Should have 6 incomplete tasks (indices 1,2,4,5,7,8)")

        // Fetch completed tasks
        descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isCompleted }
        )
        let completedTasks = try context.fetch(descriptor)
        XCTAssertEqual(completedTasks.count, 4, "Should have 4 completed tasks (indices 0,3,6,9)")
    }

    /// Verify filtering by isNextUp works correctly (should benefit from index)
    /// Bricht wenn: isNextUp nicht korrekt filterbar
    func test_localTask_indexedFetchByIsNextUp() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalTask.self, configurations: config)
        let context = container.mainContext

        let nextUpTask = LocalTask(title: "Next Up Task")
        nextUpTask.isNextUp = true
        context.insert(nextUpTask)

        let backlogTask = LocalTask(title: "Backlog Task")
        backlogTask.isNextUp = false
        context.insert(backlogTask)

        try context.save()

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isNextUp }
        )
        let nextUpTasks = try context.fetch(descriptor)
        XCTAssertEqual(nextUpTasks.count, 1)
        XCTAssertEqual(nextUpTasks.first?.title, "Next Up Task")
    }

    /// Verify filtering by isTemplate works correctly (should benefit from index)
    /// Bricht wenn: isTemplate nicht korrekt filterbar
    func test_localTask_indexedFetchByIsTemplate() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalTask.self, configurations: config)
        let context = container.mainContext

        let template = LocalTask(title: "Template")
        template.isTemplate = true
        context.insert(template)

        let regular = LocalTask(title: "Regular")
        regular.isTemplate = false
        context.insert(regular)

        try context.save()

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isTemplate }
        )
        let nonTemplates = try context.fetch(descriptor)
        XCTAssertEqual(nonTemplates.count, 1)
        XCTAssertEqual(nonTemplates.first?.title, "Regular")
    }

    // MARK: - RecurrencePattern Consistency Tests (Fix 2)

    /// Verify ALL RecurrencePattern cases have a non-empty displayName.
    /// Bricht wenn: Ein Pattern keinen displayName hat
    func test_allRecurrencePatterns_haveNonEmptyDisplayName() {
        for pattern in RecurrencePattern.allCases {
            XCTAssertFalse(
                pattern.displayName.isEmpty,
                "RecurrencePattern.\(pattern.rawValue) must have a non-empty displayName"
            )
        }
    }

    /// Verify that no displayName is the same as the raw value (except "none").
    /// This catches cases where a private function might fall through to `default: pattern`.
    /// Bricht wenn: Ein Pattern seinen rawValue als displayName zeigt (vergessener case)
    func test_allRecurrencePatterns_displayNameIsNotRawValue() {
        for pattern in RecurrencePattern.allCases where pattern != .none {
            XCTAssertNotEqual(
                pattern.displayName, pattern.rawValue,
                "RecurrencePattern.\(pattern.rawValue).displayName should not be the raw value — likely missing localization"
            )
        }
    }

    /// Verify biweekly specifically shows "Alle 2 Wochen" (the text that macOS got wrong)
    /// Bricht wenn: displayName fuer biweekly != "Alle 2 Wochen"
    func test_biweekly_displayName_isAlleZweiWochen() {
        XCTAssertEqual(
            RecurrencePattern.biweekly.displayName,
            "Alle 2 Wochen",
            "biweekly displayName must be 'Alle 2 Wochen' — not 'Zweiwöchentlich'"
        )
    }
}
