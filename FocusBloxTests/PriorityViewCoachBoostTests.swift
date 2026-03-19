import Testing
import Foundation
@testable import FocusBlox

/// FEATURE_026: Tests for Priority View unified scoring & coach boost
struct PriorityViewCoachBoostTests {

    // MARK: - Date.isOverdue Tests

    @Test func dateIsOverdue_yesterday_returnsTrue() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(yesterday.isOverdue == true)
    }

    @Test func dateIsOverdue_today_returnsFalse() {
        let today = Calendar.current.startOfDay(for: Date())
        #expect(today.isOverdue == false)
    }

    @Test func dateIsOverdue_tomorrow_returnsFalse() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(tomorrow.isOverdue == false)
    }

    @Test func dateIsOverdue_lastWeek_returnsTrue() {
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        #expect(lastWeek.isOverdue == true)
    }

    // MARK: - Coach Boost Value Tests

    @Test func coachBoostValue_is15() {
        #expect(TaskPriorityScoringService.coachBoostValue == 15)
    }

    @Test func coachBoostValue_cappedAt100() {
        // A task with score 90 + boost 15 should be capped at 100
        let boostedScore = min(100, 90 + TaskPriorityScoringService.coachBoostValue)
        #expect(boostedScore == 100)
    }

    @Test func coachBoostValue_addsToLowScore() {
        // A task with score 20 + boost 15 = 35
        let boostedScore = min(100, 20 + TaskPriorityScoringService.coachBoostValue)
        #expect(boostedScore == 35)
    }
}
