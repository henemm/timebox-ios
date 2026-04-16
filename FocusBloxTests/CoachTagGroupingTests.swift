import XCTest
import SwiftData
@testable import FocusBlox

/// TDD RED Tests for Coach Tag-Grouping (#236)
/// Tests MUST FAIL initially — tagClusterGroups does not exist yet.
@MainActor
final class CoachTagGroupingTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - Helpers

    private func makePlanItem(title: String, tags: [String] = []) -> PlanItem {
        let task = LocalTask(title: title, importance: 1)
        task.tags = tags
        container.mainContext.insert(task)
        return PlanItem(localTask: task)
    }

    // MARK: - Tag-Cluster Erkennung

    /// GIVEN: 3 Tasks mit Tag #computer, 2 ohne
    /// WHEN: tagClusterGroups wird aufgerufen
    /// THEN: 1 Cluster mit 3 Tasks für #computer
    func test_findsCluster_whenTwoOrMoreTasksShareTag() {
        let tasks = [
            makePlanItem(title: "Mail checken", tags: ["computer"]),
            makePlanItem(title: "Rechnung bezahlen", tags: ["computer"]),
            makePlanItem(title: "Code Review", tags: ["computer"]),
            makePlanItem(title: "Sport machen", tags: ["fitness"]),
            makePlanItem(title: "Einkaufen", tags: ["errands"]),
        ]

        let result = NextUpSuggestionService.tagClusterGroups(from: tasks)

        XCTAssertEqual(result.clusters.count, 1, "Genau 1 Tag-Cluster erwartet")
        XCTAssertEqual(result.clusters.first?.tag, "computer")
        XCTAssertEqual(result.clusters.first?.tasks.count, 3)
        XCTAssertEqual(result.remaining.count, 2, "2 Tasks ohne Cluster")
    }

    /// GIVEN: Tasks ohne gemeinsame Tags
    /// WHEN: tagClusterGroups wird aufgerufen
    /// THEN: Kein Cluster, alle Tasks in remaining
    func test_noCluster_whenNoSharedTags() {
        let tasks = [
            makePlanItem(title: "Task A", tags: ["alpha"]),
            makePlanItem(title: "Task B", tags: ["beta"]),
            makePlanItem(title: "Task C", tags: ["gamma"]),
        ]

        let result = NextUpSuggestionService.tagClusterGroups(from: tasks)

        XCTAssertTrue(result.clusters.isEmpty, "Kein Cluster bei unterschiedlichen Tags")
        XCTAssertEqual(result.remaining.count, 3)
    }

    /// GIVEN: Tasks ohne Tags
    /// WHEN: tagClusterGroups wird aufgerufen
    /// THEN: Kein Cluster, alle Tasks in remaining
    func test_noCluster_whenNoTags() {
        let tasks = [
            makePlanItem(title: "Task A"),
            makePlanItem(title: "Task B"),
        ]

        let result = NextUpSuggestionService.tagClusterGroups(from: tasks)

        XCTAssertTrue(result.clusters.isEmpty)
        XCTAssertEqual(result.remaining.count, 2)
    }

    /// GIVEN: Genau 2 Tasks mit gleichem Tag (Minimum)
    /// WHEN: tagClusterGroups wird aufgerufen
    /// THEN: 1 Cluster mit 2 Tasks
    func test_clusterAtMinimumThreshold_twoTasks() {
        let tasks = [
            makePlanItem(title: "Task A", tags: ["computer"]),
            makePlanItem(title: "Task B", tags: ["computer"]),
        ]

        let result = NextUpSuggestionService.tagClusterGroups(from: tasks)

        XCTAssertEqual(result.clusters.count, 1)
        XCTAssertEqual(result.clusters.first?.tasks.count, 2)
    }

    // MARK: - Größter Cluster gewinnt

    /// GIVEN: 3 Tasks mit #computer, 2 Tasks mit #fitness
    /// WHEN: tagClusterGroups wird aufgerufen
    /// THEN: Nur 1 Cluster (#computer, der größte), #fitness-Tasks in remaining
    func test_largestClusterWins_onlyOneCluster() {
        let tasks = [
            makePlanItem(title: "Mail", tags: ["computer"]),
            makePlanItem(title: "Code", tags: ["computer"]),
            makePlanItem(title: "Backup", tags: ["computer"]),
            makePlanItem(title: "Joggen", tags: ["fitness"]),
            makePlanItem(title: "Yoga", tags: ["fitness"]),
        ]

        let result = NextUpSuggestionService.tagClusterGroups(from: tasks)

        XCTAssertEqual(result.clusters.count, 1, "Nur der größte Cluster")
        XCTAssertEqual(result.clusters.first?.tag, "computer")
        XCTAssertEqual(result.clusters.first?.tasks.count, 3)
        XCTAssertEqual(result.remaining.count, 2, "Fitness-Tasks in remaining")
    }

    /// GIVEN: 2 Tags mit gleicher Anzahl Tasks
    /// WHEN: tagClusterGroups wird aufgerufen
    /// THEN: Alphabetisch erster Tag gewinnt
    func test_tiebreaker_alphabeticalFirst() {
        let tasks = [
            makePlanItem(title: "Task A", tags: ["beta"]),
            makePlanItem(title: "Task B", tags: ["beta"]),
            makePlanItem(title: "Task C", tags: ["alpha"]),
            makePlanItem(title: "Task D", tags: ["alpha"]),
        ]

        let result = NextUpSuggestionService.tagClusterGroups(from: tasks)

        XCTAssertEqual(result.clusters.count, 1)
        XCTAssertEqual(result.clusters.first?.tag, "alpha", "Alphabetisch erster Tag bei Gleichstand")
    }

    // MARK: - Task-Zuordnung (kein Doppel)

    /// GIVEN: Task mit mehreren Tags, einer davon bildet Cluster
    /// WHEN: tagClusterGroups wird aufgerufen
    /// THEN: Task erscheint im Cluster, NICHT in remaining
    func test_taskWithMultipleTags_appearsOnlyOnce() {
        let tasks = [
            makePlanItem(title: "Multi-Tag", tags: ["computer", "urgent"]),
            makePlanItem(title: "Auch Computer", tags: ["computer"]),
            makePlanItem(title: "Solo", tags: ["errands"]),
        ]

        let result = NextUpSuggestionService.tagClusterGroups(from: tasks)

        XCTAssertEqual(result.clusters.first?.tasks.count, 2)
        XCTAssertEqual(result.remaining.count, 1)
        XCTAssertEqual(result.remaining.first?.title, "Solo")
    }

    // MARK: - Coaching-Text

    /// GIVEN: Cluster mit 3 Tasks und Tag #computer
    /// WHEN: tagClusterCoachText wird aufgerufen
    /// THEN: Text enthält Anzahl und Tag-Name
    func test_coachText_containsCountAndTag() {
        let text = NextUpSuggestionService.tagClusterCoachText(tag: "computer", count: 3)

        XCTAssertTrue(text.contains("3"), "Text muss Anzahl enthalten")
        XCTAssertTrue(text.contains("#computer"), "Text muss Tag mit # enthalten")
        XCTAssertTrue(text.contains("Rutsch") || text.contains("zusammen"),
                      "Text muss Bündelungs-Hinweis enthalten")
    }

    /// GIVEN: Cluster mit 2 Tasks
    /// WHEN: tagClusterCoachText wird aufgerufen
    /// THEN: Text passt zur Anzahl 2
    func test_coachText_worksWithTwoTasks() {
        let text = NextUpSuggestionService.tagClusterCoachText(tag: "fitness", count: 2)

        XCTAssertTrue(text.contains("2"))
        XCTAssertTrue(text.contains("#fitness"))
    }
}
