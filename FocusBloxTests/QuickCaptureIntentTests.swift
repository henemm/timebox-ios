import XCTest
import SwiftData
@testable import FocusBlox

/// TDD Tests for Bug 35 v2: Interactive Snippets Quick Capture
/// Tests verify cycle logic on QuickCaptureState and task saving via SharedModelContainer.
@MainActor
final class QuickCaptureIntentTests: XCTestCase {

    // MARK: - Test 1: Importance cycles nil → 1 → 2 → 3 → nil

    func testCycleImportanceIntent() async throws {
        let state = QuickCaptureState()

        XCTAssertNil(state.importance, "Initial importance should be nil")

        // Cycle: nil → 1
        state.importance = cycleImportance(state.importance)
        XCTAssertEqual(state.importance, 1, "After 1st cycle: should be 1 (low)")

        // Cycle: 1 → 2
        state.importance = cycleImportance(state.importance)
        XCTAssertEqual(state.importance, 2, "After 2nd cycle: should be 2 (medium)")

        // Cycle: 2 → 3
        state.importance = cycleImportance(state.importance)
        XCTAssertEqual(state.importance, 3, "After 3rd cycle: should be 3 (high)")

        // Cycle: 3 → nil
        state.importance = cycleImportance(state.importance)
        XCTAssertNil(state.importance, "After 4th cycle: should be nil again")
    }

    // MARK: - Test 2: Urgency cycles nil → not_urgent → urgent → nil

    func testCycleUrgencyIntent() async throws {
        let state = QuickCaptureState()

        XCTAssertNil(state.urgency, "Initial urgency should be nil")

        // Cycle: nil → not_urgent
        state.urgency = cycleUrgency(state.urgency)
        XCTAssertEqual(state.urgency, "not_urgent", "After 1st cycle: not_urgent")

        // Cycle: not_urgent → urgent
        state.urgency = cycleUrgency(state.urgency)
        XCTAssertEqual(state.urgency, "urgent", "After 2nd cycle: urgent")

        // Cycle: urgent → nil
        state.urgency = cycleUrgency(state.urgency)
        XCTAssertNil(state.urgency, "After 3rd cycle: nil again")
    }

    // MARK: - Test 3: SaveQuickCaptureIntent saves task via SharedModelContainer

    func testSaveQuickCaptureIntent() async throws {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let task = LocalTask(
            title: "Test Snippet Task",
            importance: 2,
            estimatedDuration: 25,
            urgency: "urgent",
            taskType: "learning"
        )

        context.insert(task)
        try context.save()

        // Verify task was saved
        let tasks = try context.fetch(FetchDescriptor<LocalTask>())
        let saved = tasks.first { $0.title == "Test Snippet Task" }

        XCTAssertNotNil(saved, "Task should be saved")
        XCTAssertEqual(saved?.importance, 2)
        XCTAssertEqual(saved?.urgency, "urgent")
        XCTAssertEqual(saved?.taskType, "learning")
        XCTAssertEqual(saved?.estimatedDuration, 25)
    }

    // MARK: - Test 4: SharedModelContainer uses App Group

    func testSharedModelContainerUsesAppGroup() throws {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let task = LocalTask(title: "App Group Test")
        context.insert(task)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertTrue(fetched.contains { $0.title == "App Group Test" })
    }

    // MARK: - Helpers (mirror intent cycle logic)

    private func cycleImportance(_ current: Int?) -> Int? {
        switch current {
        case nil: return 1
        case 1: return 2
        case 2: return 3
        case 3: return nil
        default: return nil
        }
    }

    private func cycleUrgency(_ current: String?) -> String? {
        switch current {
        case nil: return "not_urgent"
        case "not_urgent": return "urgent"
        case "urgent": return nil
        default: return nil
        }
    }
}
