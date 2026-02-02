import Testing
@testable import FocusBlox

/// Tests for iOS Reminder priority mapping
/// EKReminder: 0=none, 1-4=high, 5=medium, 6-9=low
/// FocusBlox: 1=low, 2=medium, 3=high
struct ReminderPriorityMappingTests {

    @Test func testHighPriorityMapping() {
        // EKReminder 1-4 = high → FocusBlox 3
        #expect(mapReminderPriority(1) == 3)
        #expect(mapReminderPriority(2) == 3)
        #expect(mapReminderPriority(3) == 3)
        #expect(mapReminderPriority(4) == 3)
    }

    @Test func testMediumPriorityMapping() {
        // EKReminder 5 = medium → FocusBlox 2
        #expect(mapReminderPriority(5) == 2)
    }

    @Test func testLowPriorityMapping() {
        // EKReminder 6-9 = low → FocusBlox 1
        #expect(mapReminderPriority(6) == 1)
        #expect(mapReminderPriority(7) == 1)
        #expect(mapReminderPriority(8) == 1)
        #expect(mapReminderPriority(9) == 1)
    }

    @Test func testNonePriorityMapping() {
        // EKReminder 0 = none → FocusBlox 2 (default to medium)
        #expect(mapReminderPriority(0) == 2)
    }

    @Test func testReverseMapping() {
        // FocusBlox → EKReminder
        #expect(mapToReminderPriority(3) == 1)  // High
        #expect(mapToReminderPriority(2) == 5)  // Medium
        #expect(mapToReminderPriority(1) == 9)  // Low
    }
}

// MARK: - Functions to test (will be moved to RemindersSyncService)

func mapReminderPriority(_ ekPriority: Int) -> Int {
    switch ekPriority {
    case 1...4: return 3  // High
    case 5: return 2      // Medium
    case 6...9: return 1  // Low
    default: return 2     // None (0) → default to Medium
    }
}

func mapToReminderPriority(_ focusBloxPriority: Int) -> Int {
    switch focusBloxPriority {
    case 3: return 1  // High
    case 2: return 5  // Medium
    case 1: return 9  // Low
    default: return 0 // None
    }
}
