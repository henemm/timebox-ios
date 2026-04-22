import XCTest
@testable import FocusBlox

/// Tests for capacity-based suggestion limiting (Feature #237)
///
/// Validates that NextUpSuggestionService limits suggestions based on
/// BehavioralProfile.avgTasksPerDay minus already planned tasks.
@MainActor
final class CapacityLimitTests: XCTestCase {

    // MARK: - capacityBasedMax Tests

    func test_capacityBasedMax_withProfile_limitsToRemainingCapacity() {
        // avgTasks=4, planned=3 → max 1
        let result = NextUpSuggestionService.capacityBasedMax(
            profile: makeProfile(avgTasksPerDay: 4.0),
            alreadyPlanned: 3,
            meetingLoad: .low
        )
        XCTAssertEqual(result, 1)
    }

    func test_capacityBasedMax_withProfile_nothingPlanned() {
        // avgTasks=4, planned=0 → max 4 (meetingMax for low=5, capacity=4 → 4)
        let result = NextUpSuggestionService.capacityBasedMax(
            profile: makeProfile(avgTasksPerDay: 4.0),
            alreadyPlanned: 0,
            meetingLoad: .low
        )
        XCTAssertEqual(result, 4)
    }

    func test_capacityBasedMax_overPlanned_returnsZero() {
        // avgTasks=4, planned=5 → 0
        let result = NextUpSuggestionService.capacityBasedMax(
            profile: makeProfile(avgTasksPerDay: 4.0),
            alreadyPlanned: 5,
            meetingLoad: .low
        )
        XCTAssertEqual(result, 0)
    }

    func test_capacityBasedMax_meetingLoadCaps() {
        // avgTasks=10, planned=0 → capacity=10, but high load caps at 3
        let result = NextUpSuggestionService.capacityBasedMax(
            profile: makeProfile(avgTasksPerDay: 10.0),
            alreadyPlanned: 0,
            meetingLoad: .high
        )
        XCTAssertEqual(result, 3)
    }

    func test_capacityBasedMax_nilProfile_fallsBackToMeetingLoad() {
        // No avgTasksPerDay → fallback to meeting-based limits
        let result = NextUpSuggestionService.capacityBasedMax(
            profile: makeProfile(avgTasksPerDay: nil),
            alreadyPlanned: 0,
            meetingLoad: .medium
        )
        XCTAssertEqual(result, 4)
    }

    // MARK: - Helpers

    private func makeProfile(avgTasksPerDay: Double?) -> BehavioralProfile {
        BehavioralProfile(
            computedAt: Date(),
            categoryTimeAffinity: nil,
            avgTasksPerDay: avgTasksPerDay,
            avgMinutesPerDay: nil,
            estimationFactor: nil,
            capacityByMeetingLoad: nil,
            procrastinationPatterns: nil
        )
    }
}
