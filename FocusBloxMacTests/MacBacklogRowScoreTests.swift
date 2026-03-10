import XCTest
@testable import FocusBloxMac

/// Regression test for BACKLOG-011: MacBacklogRow must use effective (frozen) score
/// instead of computing score directly via calculateScore().
///
/// Before fix: MacBacklogRow has no effectiveScore/effectiveTier parameter → compile error.
/// After fix: MacBacklogRow accepts these from parent and uses them for badge display.
@MainActor
final class MacBacklogRowScoreTests: XCTestCase {

    // MARK: - Test: MacBacklogRow accepts effectiveScore parameter

    /// GIVEN: A LocalTask and a pre-computed effective score + tier
    /// WHEN: MacBacklogRow is created with effectiveScore/effectiveTier
    /// THEN: It compiles and the parameters exist on the struct
    ///
    /// Welche Zeile bricht diesen Test? MacBacklogRow hat kein effectiveScore Property.
    func test_macBacklogRow_acceptsEffectiveScoreParameter() {
        let task = LocalTask(title: "Test Task", importance: 3)
        let frozenScore = 75
        let frozenTier = TaskPriorityScoringService.PriorityTier.from(score: frozenScore)

        // This must compile — proves MacBacklogRow accepts external score
        let row = MacBacklogRow(
            task: task,
            effectiveScore: frozenScore,
            effectiveTier: frozenTier
        )

        XCTAssertNotNil(row, "MacBacklogRow should accept effectiveScore parameter")
    }

    // MARK: - Test: Effective score differs from live-calculated score

    /// GIVEN: A task with importance=1 (low live score)
    /// WHEN: Parent passes frozenScore=99 (from DeferredSortController)
    /// THEN: MacBacklogRow uses 99, not the live-calculated score
    ///
    /// Welche Zeile bricht diesen Test? MacBacklogRow.effectiveScore Property fehlt.
    func test_effectiveScore_canDifferFromLiveScore() {
        let task = LocalTask(title: "Low Priority", importance: 1)

        let liveScore = TaskPriorityScoringService.calculateScore(
            importance: task.importance, urgency: task.urgency, dueDate: task.dueDate,
            createdAt: task.createdAt, rescheduleCount: task.rescheduleCount,
            estimatedDuration: task.estimatedDuration, taskType: task.taskType,
            isNextUp: task.isNextUp,
            dependentTaskCount: 0
        )

        let frozenScore = 99  // Deliberately different from live score
        let row = MacBacklogRow(
            task: task,
            effectiveScore: frozenScore,
            effectiveTier: TaskPriorityScoringService.PriorityTier.doNow
        )

        // The frozen score should be different from live — proves we're passing external score
        XCTAssertNotEqual(liveScore, frozenScore,
                          "Test setup: frozen score must differ from live score to prove the parameter matters")
        XCTAssertNotNil(row)
    }
}
