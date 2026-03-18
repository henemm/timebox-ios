import XCTest

/// UI Tests for BUG_109: Next Up section should sort tasks by priority score descending.
///
/// The Next Up section in BacklogView currently displays tasks in arbitrary
/// SwiftData query order instead of sorting by priorityScore descending.
/// These tests verify that the highest-score tasks appear first in Next Up.
///
/// Mock data (isNextUp=true):
/// - [MOCK] Lohnsteuererklaerung einreichen: importance=3, urgent → score ~85
/// - [MOCK] Task 1 #30min: importance=3, urgent → score ~58
/// - [MOCK] Task 2 #15min: importance=2, not_urgent → score ~28
/// - [MOCK] Task 3 #45min: importance=1, not_urgent → score ~18
///
/// Expected order after fix (descending by score):
///   Lohnsteuererklaerung (85) → Task 1 (58) → Task 2 (28) → Task 3 (18)
final class NextUpSortOrderUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Find task titles in Next Up section, ordered by Y position (top to bottom).
    /// Next Up section elements all have identifier 'nextUpSection'.
    /// Task titles contain "[MOCK]" prefix and are StaticText elements.
    private func nextUpTaskTitlesInOrder() -> [String] {
        // Wait for tasks to load
        let firstTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'nextUpSection' AND label BEGINSWITH '[MOCK]'")
        ).firstMatch
        guard firstTitle.waitForExistence(timeout: 8) else { return [] }

        let titleElements = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'nextUpSection' AND label BEGINSWITH '[MOCK]'")
        )

        // Collect titles with their Y positions for ordering
        var titlesWithY: [(title: String, y: CGFloat)] = []
        for i in 0..<titleElements.count {
            let element = titleElements.element(boundBy: i)
            if element.exists {
                titlesWithY.append((element.label, element.frame.minY))
            }
        }

        // Sort by Y position (top to bottom) and return just titles
        return titlesWithY
            .sorted { $0.y < $1.y }
            .map(\.title)
    }

    // MARK: - Tests

    /// GIVEN: App launched with mock data (4 Next Up tasks with different scores)
    /// WHEN: Backlog is displayed in Priority mode (default)
    /// THEN: Next Up tasks should be sorted by priority score descending
    ///       (Lohnsteuererklaerung first, Task 3 last)
    func testNextUpTasksSortedByScoreDescending() throws {
        let titles = nextUpTaskTitlesInOrder()

        XCTAssertGreaterThanOrEqual(titles.count, 4,
            "Should have 4 Next Up task titles, found \(titles.count): \(titles)")

        // Expected descending order by score:
        // 1. Lohnsteuererklaerung (score ~85)
        // 2. Task 1 #30min (score ~58)
        // 3. Task 2 #15min (score ~28)
        // 4. Task 3 #45min (score ~18)

        // The highest-score task should be first
        XCTAssertTrue(titles[0].contains("Lohnsteuererklaerung"),
            "First Next Up task should be Lohnsteuererklaerung (highest score ~85), " +
            "but found: \(titles[0]). Full order: \(titles)")

        // Task 1 (score ~58) should come before Task 3 (score ~18)
        let task1Index = titles.firstIndex(where: { $0.contains("Task 1") })
        let task3Index = titles.firstIndex(where: { $0.contains("Task 3") })

        XCTAssertNotNil(task1Index, "Task 1 should be in Next Up")
        XCTAssertNotNil(task3Index, "Task 3 should be in Next Up")

        if let t1 = task1Index, let t3 = task3Index {
            XCTAssertLessThan(t1, t3,
                "Task 1 (score ~58) should appear BEFORE Task 3 (score ~18) in Next Up. " +
                "Full order: \(titles)")
        }

        // Task 3 (lowest score) should be last
        XCTAssertTrue(titles.last?.contains("Task 3") == true,
            "Last Next Up task should be Task 3 (lowest score ~18), " +
            "but found: \(titles.last ?? "nil"). Full order: \(titles)")
    }
}
