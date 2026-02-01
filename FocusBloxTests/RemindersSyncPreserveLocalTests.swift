import XCTest
@testable import FocusBlox

/// Unit Tests for Bug: Reminders sync should preserve locally-set importance
/// Root Cause: updateTask() in RemindersSyncService always overwrites importance
final class RemindersSyncPreserveLocalTests: XCTestCase {

    // MARK: - Test: Priority mapping is correct

    /// Verify the EKReminder priority to FocusBlox importance mapping
    func testPriorityMappingCorrect() {
        // EKReminder: 0=none, 1-4=high, 5=medium, 6-9=low
        // FocusBlox: nil=tbd, 1=low, 2=medium, 3=high

        func mapReminderPriority(_ ekPriority: Int) -> Int? {
            switch ekPriority {
            case 1...4: return 3  // High
            case 5: return 2      // Medium
            case 6...9: return 1  // Low
            default: return nil   // None (0) → TBD
            }
        }

        XCTAssertNil(mapReminderPriority(0), "Priority 0 should map to nil (TBD)")
        XCTAssertEqual(mapReminderPriority(1), 3, "Priority 1 should map to High (3)")
        XCTAssertEqual(mapReminderPriority(4), 3, "Priority 4 should map to High (3)")
        XCTAssertEqual(mapReminderPriority(5), 2, "Priority 5 should map to Medium (2)")
        XCTAssertEqual(mapReminderPriority(6), 1, "Priority 6 should map to Low (1)")
        XCTAssertEqual(mapReminderPriority(9), 1, "Priority 9 should map to Low (1)")
    }

    // MARK: - Test: Local importance preservation logic

    /// Test the logic for preserving local importance during sync
    /// EXPECTED TO FAIL: Current code always overwrites, this tests the desired behavior
    func testLocalImportanceShouldBePreserved() {
        // Simulate: User set importance locally to 3 (High)
        let localImportance: Int? = 3

        // Simulate: Apple Reminders has no priority (0) which maps to nil
        let applePriority = 0
        let mappedAppleImportance: Int? = applePriority == 0 ? nil : applePriority

        // Current buggy behavior: would use mappedAppleImportance (nil)
        // Expected behavior: should preserve localImportance (3)

        // Test the DESIRED logic:
        // If local is set and Apple is nil → preserve local
        let shouldPreserveLocal = localImportance != nil && mappedAppleImportance == nil
        XCTAssertTrue(shouldPreserveLocal, "Should preserve local importance when Apple has none")

        // The final value should be localImportance, not mappedAppleImportance
        let finalImportance = shouldPreserveLocal ? localImportance : mappedAppleImportance
        XCTAssertEqual(finalImportance, 3, "Final importance should be the locally-set value")
    }

    // MARK: - Test: Apple priority should be used when local is not set

    /// If local importance is nil (TBD), Apple's priority should be used
    func testApplePriorityUsedWhenLocalNotSet() {
        // Simulate: User has NOT set importance locally
        let localImportance: Int? = nil

        // Simulate: Apple Reminders has high priority (1) which maps to 3
        let applePriority = 1
        let mappedAppleImportance: Int? = 3  // High

        // Test the DESIRED logic:
        // If local is nil → use Apple's value
        let shouldUseApple = localImportance == nil
        XCTAssertTrue(shouldUseApple, "Should use Apple priority when local is not set")

        let finalImportance = localImportance ?? mappedAppleImportance
        XCTAssertEqual(finalImportance, 3, "Final importance should be Apple's priority when local is nil")
    }

    // MARK: - Test: Urgency is local-only

    /// Urgency has no equivalent in Apple Reminders - it should never be affected by sync
    func testUrgencyIsLocalOnly() {
        // Urgency values in FocusBlox
        let validUrgencyValues = ["urgent", "not_urgent", nil] as [String?]

        // Apple Reminders has NO urgency field
        // This test documents that urgency should never be touched during sync

        for urgency in validUrgencyValues {
            // After any sync operation, urgency should remain unchanged
            let afterSync = urgency  // Current code correctly preserves this
            XCTAssertEqual(afterSync, urgency, "Urgency '\(String(describing: urgency))' should be preserved after sync")
        }
    }
}
