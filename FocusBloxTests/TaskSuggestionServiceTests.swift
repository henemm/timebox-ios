import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class TaskSuggestionServiceTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        UserDefaults.standard.set(true, forKey: "taskSuggestionsEnabled")
    }

    override func tearDownWithError() throws {
        container = nil
        UserDefaults.standard.removeObject(forKey: "taskSuggestionsEnabled")
    }

    // MARK: - Prefix Matching

    /// GIVEN: Tasks "Zahnarzt Termin", "Zahnarzt anrufen" exist
    /// WHEN: User types "Zahn"
    /// THEN: Both tasks appear as suggestions
    func test_suggestions_prefixMatch() async throws {
        let context = container.mainContext
        let task1 = LocalTask(title: "Zahnarzt Termin")
        let task2 = LocalTask(title: "Zahnarzt anrufen")
        let task3 = LocalTask(title: "Einkaufen gehen")
        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let service = TaskSuggestionService(modelContext: context)
        let results = await service.suggestions(for: "Zahn")

        XCTAssertEqual(results.count, 2, "Should find 2 tasks starting with 'Zahn'")
        let titles = results.map(\.title)
        XCTAssertTrue(titles.contains("Zahnarzt Termin"))
        XCTAssertTrue(titles.contains("Zahnarzt anrufen"))
    }

    /// GIVEN: Tasks exist
    /// WHEN: User types only 1 character
    /// THEN: No suggestions (minimum 2 chars required)
    func test_suggestions_ignoresShortInput() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Zahnarzt Termin")
        context.insert(task)
        try context.save()

        let service = TaskSuggestionService(modelContext: context)
        let results = await service.suggestions(for: "Z")

        XCTAssertTrue(results.isEmpty, "Should return empty for single character input")
    }

    // MARK: - Contains Matching

    /// GIVEN: Task "Team Meeting vorbereiten" exists
    /// WHEN: User types "Meeting"
    /// THEN: Task appears (contains match)
    func test_suggestions_containsMatch() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Team Meeting vorbereiten")
        context.insert(task)
        try context.save()

        let service = TaskSuggestionService(modelContext: context)
        let results = await service.suggestions(for: "Meeting")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Team Meeting vorbereiten")
    }

    // MARK: - Completed Tasks

    /// GIVEN: A completed task "Wochenbericht" exists
    /// WHEN: User types "Wochen"
    /// THEN: Completed task appears with isCompleted=true
    func test_suggestions_includesCompletedTasks() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Wochenbericht schreiben")
        task.isCompleted = true
        task.completedAt = Date()
        context.insert(task)
        try context.save()

        let service = TaskSuggestionService(modelContext: context)
        let results = await service.suggestions(for: "Wochen")

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.isCompleted == true, "Should indicate task was completed")
    }

    // MARK: - Max Results

    /// GIVEN: 10 tasks with prefix "Test"
    /// WHEN: User types "Test"
    /// THEN: Max 5 suggestions returned
    func test_suggestions_maxFiveResults() async throws {
        let context = container.mainContext
        for i in 1...10 {
            let task = LocalTask(title: "Test Aufgabe \(i)")
            context.insert(task)
        }
        try context.save()

        let service = TaskSuggestionService(modelContext: context)
        let results = await service.suggestions(for: "Test")

        XCTAssertLessThanOrEqual(results.count, 5, "Should return max 5 suggestions")
    }

    // MARK: - Case Insensitive

    /// GIVEN: Task "EINKAUFEN" exists
    /// WHEN: User types "einkauf"
    /// THEN: Match found (case insensitive)
    func test_suggestions_caseInsensitive() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "EINKAUFEN gehen")
        context.insert(task)
        try context.save()

        let service = TaskSuggestionService(modelContext: context)
        let results = await service.suggestions(for: "einkauf")

        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Duplicate Detection

    /// GIVEN: Task "Zahnarzt Termin vereinbaren" exists
    /// WHEN: User enters "Zahnarzt Termin vereinbaren" (exact match)
    /// THEN: Duplicate detected with similarity > 0.8
    func test_findDuplicate_exactMatch() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Zahnarzt Termin vereinbaren")
        context.insert(task)
        try context.save()

        let service = TaskSuggestionService(modelContext: context)
        let duplicate = await service.findDuplicate(for: "Zahnarzt Termin vereinbaren")

        XCTAssertNotNil(duplicate, "Should detect exact duplicate")
        XCTAssertGreaterThan(duplicate!.similarity, 0.8)
    }

    /// GIVEN: Task "Zahnarzt Termin" exists
    /// WHEN: User enters "Zahnarzt Termin vereinbaren" (very similar)
    /// THEN: Duplicate detected
    func test_findDuplicate_highSimilarity() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Zahnarzt Termin")
        context.insert(task)
        try context.save()

        let service = TaskSuggestionService(modelContext: context)
        let duplicate = await service.findDuplicate(for: "Zahnarzt Termin vereinbaren")

        XCTAssertNotNil(duplicate, "Should detect near-duplicate")
        XCTAssertGreaterThan(duplicate!.similarity, 0.8)
    }

    /// GIVEN: Task "Einkaufen" exists
    /// WHEN: User enters "Zahnarzt Termin"
    /// THEN: No duplicate (completely different)
    func test_findDuplicate_noDuplicate() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Einkaufen gehen")
        context.insert(task)
        try context.save()

        let service = TaskSuggestionService(modelContext: context)
        let duplicate = await service.findDuplicate(for: "Zahnarzt Termin")

        XCTAssertNil(duplicate, "Should not detect duplicate for different tasks")
    }

    // MARK: - Settings Toggle

    /// GIVEN: taskSuggestionsEnabled is false
    /// WHEN: suggestions() is called
    /// THEN: Empty results
    func test_suggestions_disabledWhenToggleOff() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Zahnarzt Termin")
        context.insert(task)
        try context.save()

        UserDefaults.standard.set(false, forKey: "taskSuggestionsEnabled")

        let service = TaskSuggestionService(modelContext: context)
        let results = await service.suggestions(for: "Zahn")

        XCTAssertTrue(results.isEmpty, "Should return empty when feature is disabled")
    }

    /// GIVEN: taskSuggestionsEnabled is false
    /// WHEN: findDuplicate() is called
    /// THEN: nil (no duplicate check)
    func test_findDuplicate_disabledWhenToggleOff() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Zahnarzt Termin")
        context.insert(task)
        try context.save()

        UserDefaults.standard.set(false, forKey: "taskSuggestionsEnabled")

        let service = TaskSuggestionService(modelContext: context)
        let duplicate = await service.findDuplicate(for: "Zahnarzt Termin")

        XCTAssertNil(duplicate, "Should return nil when feature is disabled")
    }
}
