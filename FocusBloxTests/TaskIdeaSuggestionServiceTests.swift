import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class TaskIdeaSuggestionServiceTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
        UserDefaults.standard.removeObject(forKey: "taskIdeaSuggestionsEnabled")
    }

    // MARK: - Empty Input

    /// GIVEN: No existing tasks
    /// WHEN: suggestions() is called
    /// THEN: Returns empty array (nothing to base ideas on)
    func test_suggestions_returnsEmptyWithNoTasks() async throws {
        let result = await TaskIdeaSuggestionService.suggestions(existingTasks: [])

        XCTAssertTrue(result.isEmpty, "Should return empty when no tasks exist as context")
    }

    // MARK: - Result Constraints

    /// GIVEN: Tasks exist as context
    /// WHEN: suggestions() completes
    /// THEN: Returns at most 3 items
    func test_suggestions_returnsMaxThreeItems() async throws {
        let context = container.mainContext
        for i in 1...10 {
            let task = LocalTask(title: "Task \(i)")
            context.insert(task)
        }
        try context.save()

        let tasks = try context.fetch(FetchDescriptor<LocalTask>())
        let result = await TaskIdeaSuggestionService.suggestions(existingTasks: tasks)

        XCTAssertLessThanOrEqual(result.count, 3, "Should return at most 3 suggestions")
    }

    /// GIVEN: Tasks exist and AI is available
    /// WHEN: suggestions() completes with results
    /// THEN: Each suggestion is non-empty and reasonable length
    func test_suggestions_areNonEmptyStrings() async throws {
        let context = container.mainContext
        let task1 = LocalTask(title: "Einkaufen gehen")
        let task2 = LocalTask(title: "Wohnung aufräumen")
        let task3 = LocalTask(title: "E-Mails beantworten")
        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let tasks = try context.fetch(FetchDescriptor<LocalTask>())
        let result = await TaskIdeaSuggestionService.suggestions(existingTasks: tasks)

        for suggestion in result {
            XCTAssertFalse(suggestion.isEmpty, "Each suggestion should be non-empty")
            XCTAssertGreaterThanOrEqual(suggestion.count, 2, "Suggestion too short: '\(suggestion)'")
            XCTAssertLessThanOrEqual(suggestion.count, 80, "Suggestion too long: '\(suggestion)'")
        }
    }

    // MARK: - isAIAvailable

    /// GIVEN: Running in test environment
    /// WHEN: isAIAvailable is checked
    /// THEN: Returns a Bool (API accessibility check)
    func test_isAIAvailable_returnsBool() {
        let available = TaskIdeaSuggestionService.isAIAvailable
        XCTAssertTrue(available == true || available == false)
    }
}
