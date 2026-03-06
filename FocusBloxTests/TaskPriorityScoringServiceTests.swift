import XCTest
@testable import FocusBlox

final class TaskPriorityScoringServiceTests: XCTestCase {

    // MARK: - Eisenhower Score

    func test_eisenhowerScore_importance3_urgent_returns50() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: 3, urgency: "urgent"), 50)
    }

    func test_eisenhowerScore_importance3_notUrgent_returns38() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: 3, urgency: "not_urgent"), 38)
    }

    func test_eisenhowerScore_importance2_urgent_returns35() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: 2, urgency: "urgent"), 35)
    }

    func test_eisenhowerScore_importance1_urgent_returns30() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: 1, urgency: "urgent"), 30)
    }

    func test_eisenhowerScore_importance2_notUrgent_returns20() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: 2, urgency: "not_urgent"), 20)
    }

    func test_eisenhowerScore_importance1_notUrgent_returns10() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: 1, urgency: "not_urgent"), 10)
    }

    func test_eisenhowerScore_onlyImportance_returns15() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: 2, urgency: nil), 15)
    }

    func test_eisenhowerScore_onlyUrgent_returns25() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: nil, urgency: "urgent"), 25)
    }

    func test_eisenhowerScore_onlyNotUrgent_returns8() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: nil, urgency: "not_urgent"), 8)
    }

    func test_eisenhowerScore_neitherSet_returns0() {
        XCTAssertEqual(TaskPriorityScoringService.eisenhowerScore(importance: nil, urgency: nil), 0)
    }

    // MARK: - Deadline Score

    func test_deadlineScore_overdue_returns25() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(TaskPriorityScoringService.deadlineScore(dueDate: yesterday, now: now), 25)
    }

    func test_deadlineScore_today_returns25() {
        let now = Date()
        XCTAssertEqual(TaskPriorityScoringService.deadlineScore(dueDate: now, now: now), 25)
    }

    func test_deadlineScore_tomorrow_returns22() {
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        XCTAssertEqual(TaskPriorityScoringService.deadlineScore(dueDate: tomorrow, now: now), 22)
    }

    func test_deadlineScore_3daysOut_returns18() {
        let now = Date()
        let threeDays = Calendar.current.date(byAdding: .day, value: 3, to: now)!
        XCTAssertEqual(TaskPriorityScoringService.deadlineScore(dueDate: threeDays, now: now), 18)
    }

    func test_deadlineScore_5daysOut_returns12() {
        let now = Date()
        let fiveDays = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        XCTAssertEqual(TaskPriorityScoringService.deadlineScore(dueDate: fiveDays, now: now), 12)
    }

    func test_deadlineScore_10daysOut_returns6() {
        let now = Date()
        let tenDays = Calendar.current.date(byAdding: .day, value: 10, to: now)!
        XCTAssertEqual(TaskPriorityScoringService.deadlineScore(dueDate: tenDays, now: now), 6)
    }

    func test_deadlineScore_noDueDate_returns0() {
        XCTAssertEqual(TaskPriorityScoringService.deadlineScore(dueDate: nil, now: Date()), 0)
    }

    // MARK: - Neglect Score

    func test_neglectScore_brandNew_noReschedules_returns0() {
        let now = Date()
        XCTAssertEqual(TaskPriorityScoringService.neglectScore(createdAt: now, rescheduleCount: 0, now: now), 0)
    }

    func test_neglectScore_30daysOld_noReschedules_returns10() {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        XCTAssertEqual(TaskPriorityScoringService.neglectScore(createdAt: thirtyDaysAgo, rescheduleCount: 0, now: now), 10)
    }

    func test_neglectScore_15daysOld_5reschedules_returns10() {
        let now = Date()
        let fifteenDaysAgo = Calendar.current.date(byAdding: .day, value: -15, to: now)!
        // Age: 15 * 10 / 30 = 5, Reschedule: min(5, 5) = 5 → total 10
        XCTAssertEqual(TaskPriorityScoringService.neglectScore(createdAt: fifteenDaysAgo, rescheduleCount: 5, now: now), 10)
    }

    // MARK: - Completeness Score

    func test_completenessScore_allFieldsSet_returns5() {
        XCTAssertEqual(
            TaskPriorityScoringService.completenessScore(
                importance: 3, urgency: "urgent", duration: 30, taskType: "work"
            ), 5
        )
    }

    func test_completenessScore_noFieldsSet_returns0() {
        XCTAssertEqual(
            TaskPriorityScoringService.completenessScore(
                importance: nil, urgency: nil, duration: nil, taskType: ""
            ), 0
        )
    }

    // MARK: - Next Up Bonus

    func test_nextUpBonus_true_returns5() {
        XCTAssertEqual(TaskPriorityScoringService.nextUpBonus(isNextUp: true), 5)
    }

    func test_nextUpBonus_false_returns0() {
        XCTAssertEqual(TaskPriorityScoringService.nextUpBonus(isNextUp: false), 0)
    }

    // MARK: - Calculate Score (Composite)

    func test_calculateScore_compositeAllComponents() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!

        let score = TaskPriorityScoringService.calculateScore(
            importance: 3,
            urgency: "urgent",
            dueDate: yesterday,
            createdAt: thirtyDaysAgo,
            rescheduleCount: 3,
            estimatedDuration: 30,
            taskType: "work",
            isNextUp: true,
            now: now
        )

        // eisenhower(3, urgent) = 50
        // deadline(yesterday) = 25
        // neglect(30 days, 3 reschedules) = 10 + 3 = 13
        // completeness(all 4) = 5
        // nextUp = 5
        // Total = 98, capped at 100
        XCTAssertEqual(score, 98)
    }

    func test_calculateScore_cappedAt100() {
        let now = Date()
        let longAgo = Calendar.current.date(byAdding: .day, value: -60, to: now)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        let score = TaskPriorityScoringService.calculateScore(
            importance: 3,
            urgency: "urgent",
            dueDate: yesterday,
            createdAt: longAgo,
            rescheduleCount: 10,
            estimatedDuration: 30,
            taskType: "work",
            isNextUp: true,
            now: now
        )

        // eisenhower=50 + deadline=25 + neglect=15 + completeness=5 + nextUp=5 = 100
        XCTAssertEqual(score, 100)
    }

    // MARK: - PriorityTier.from

    func test_priorityTier_score75_isDoNow() {
        XCTAssertEqual(TaskPriorityScoringService.PriorityTier.from(score: 75), .doNow)
    }

    func test_priorityTier_score40_isPlanSoon() {
        XCTAssertEqual(TaskPriorityScoringService.PriorityTier.from(score: 40), .planSoon)
    }

    func test_priorityTier_score20_isEventually() {
        XCTAssertEqual(TaskPriorityScoringService.PriorityTier.from(score: 20), .eventually)
    }

    func test_priorityTier_score5_isSomeday() {
        XCTAssertEqual(TaskPriorityScoringService.PriorityTier.from(score: 5), .someday)
    }
}
