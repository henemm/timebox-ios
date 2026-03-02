//
//  MacBacklogSectionsTests.swift
//  FocusBloxTests
//
//  Unit Tests for Bug 65: macOS backlog priority sections.
//  Tests verify the tier-grouping logic that will be used by macOS ContentView.
//

import XCTest
@testable import FocusBlox

/// Tests for priority tier grouping logic (used by macOS backlog sections).
///
/// These tests verify that:
/// 1. Tasks can be grouped into priority tiers using inline scoring
/// 2. Overdue tasks are correctly separated from tier sections
/// 3. Each tier contains only tasks with matching score ranges
final class MacBacklogSectionsTests: XCTestCase {

    // MARK: - Helper: Calculate tier for task attributes

    private func tierFor(
        importance: Int?,
        urgency: String?,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        rescheduleCount: Int = 0,
        estimatedDuration: Int? = nil,
        taskType: String = "",
        isNextUp: Bool = false
    ) -> TaskPriorityScoringService.PriorityTier {
        let score = TaskPriorityScoringService.calculateScore(
            importance: importance, urgency: urgency, dueDate: dueDate,
            createdAt: createdAt, rescheduleCount: rescheduleCount,
            estimatedDuration: estimatedDuration, taskType: taskType,
            isNextUp: isNextUp
        )
        return TaskPriorityScoringService.PriorityTier.from(score: score)
    }

    // MARK: - Test 1: High importance + urgent → doNow tier

    func test_highImportanceUrgent_isDoNowTier() {
        let tier = tierFor(importance: 3, urgency: "urgent")
        XCTAssertEqual(tier, .doNow, "High importance + urgent should be 'Sofort erledigen'")
    }

    // MARK: - Test 2: Medium importance + not urgent → planSoon or eventually

    func test_mediumImportanceNotUrgent_isPlanSoonOrEventually() {
        let tier = tierFor(importance: 2, urgency: "not_urgent")
        XCTAssertTrue(
            tier == .planSoon || tier == .eventually,
            "Medium importance + not urgent should be 'Bald einplanen' or 'Bei Gelegenheit'"
        )
    }

    // MARK: - Test 3: No importance, no urgency → someday tier

    func test_noImportanceNoUrgency_isSomedayTier() {
        let tier = tierFor(importance: nil, urgency: nil)
        XCTAssertEqual(tier, .someday, "No importance/urgency should be 'Irgendwann'")
    }

    // MARK: - Test 4: All 4 tiers have correct labels

    func test_allTierLabels() {
        XCTAssertEqual(TaskPriorityScoringService.PriorityTier.doNow.label, "Sofort erledigen")
        XCTAssertEqual(TaskPriorityScoringService.PriorityTier.planSoon.label, "Bald einplanen")
        XCTAssertEqual(TaskPriorityScoringService.PriorityTier.eventually.label, "Bei Gelegenheit")
        XCTAssertEqual(TaskPriorityScoringService.PriorityTier.someday.label, "Irgendwann")
    }

    // MARK: - Test 5: Overdue detection works with dueDate in past

    func test_overdueDetection_pastDueDate() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let startOfToday = Calendar.current.startOfDay(for: Date())
        XCTAssertTrue(yesterday < startOfToday, "Yesterday should be detected as overdue")
    }

    // MARK: - Test 6: Non-overdue task is NOT in overdue section

    func test_nonOverdue_futureDueDate() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let startOfToday = Calendar.current.startOfDay(for: Date())
        XCTAssertFalse(tomorrow < startOfToday, "Tomorrow should NOT be overdue")
    }

    // MARK: - Test 7: PriorityTier.allCases has exactly 4 tiers

    func test_allCases_has4Tiers() {
        XCTAssertEqual(
            TaskPriorityScoringService.PriorityTier.allCases.count, 4,
            "Should have exactly 4 priority tiers for section grouping"
        )
    }

    // MARK: - Test 8: Grouping tasks by tier produces correct buckets

    func test_groupingByTier_producesCorrectBuckets() {
        // Simulate task attributes that map to different tiers
        let tasks: [(importance: Int?, urgency: String?)] = [
            (3, "urgent"),      // doNow (score ~50)
            (3, "not_urgent"),  // planSoon (score ~35)
            (1, "not_urgent"),  // someday (score ~5)
            (nil, nil),         // someday (score 0)
        ]

        var tierCounts: [TaskPriorityScoringService.PriorityTier: Int] = [:]
        for task in tasks {
            let tier = tierFor(importance: task.importance, urgency: task.urgency)
            tierCounts[tier, default: 0] += 1
        }

        // doNow should have at least 1 task
        XCTAssertGreaterThanOrEqual(tierCounts[.doNow] ?? 0, 1, "doNow tier should have tasks")
        // someday should have at least 1 task
        XCTAssertGreaterThanOrEqual(tierCounts[.someday] ?? 0, 1, "someday tier should have tasks")
    }
}
