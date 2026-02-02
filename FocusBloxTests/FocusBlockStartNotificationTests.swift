import XCTest
import UserNotifications
@testable import FocusBlox

/// Unit Tests for Focus Block Start Notification (Task 3)
@MainActor
final class FocusBlockStartNotificationTests: XCTestCase {

    // MARK: - Notification Content Tests

    /// GIVEN: A focus block starting in 30 minutes
    /// WHEN: Building notification request
    /// THEN: Title should be "startet gleich" and body should mention 5 minutes
    func testNotificationContentForFutureBlock() {
        let now = Date()
        let startDate = now.addingTimeInterval(30 * 60)

        let request = NotificationService.buildFocusBlockNotificationRequest(
            blockID: "test-1",
            blockTitle: "Focus Block 10:00",
            startDate: startDate,
            now: now
        )

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.content.title, "Focus Block startet gleich")
        XCTAssertTrue(request?.content.body.contains("Focus Block 10:00") ?? false)
        XCTAssertTrue(request?.content.body.contains("5 Minuten") ?? false)
    }

    /// GIVEN: A focus block starting in 3 minutes (< 5 min threshold)
    /// WHEN: Building notification request
    /// THEN: Title should be "startet jetzt" (notify at start, not 5 min before)
    func testNotificationAtStartIfLessThan5Min() {
        let now = Date()
        let startDate = now.addingTimeInterval(3 * 60)

        let request = NotificationService.buildFocusBlockNotificationRequest(
            blockID: "test-soon",
            blockTitle: "Focus Block Soon",
            startDate: startDate,
            now: now
        )

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.content.title, "Focus Block startet jetzt")
        XCTAssertTrue(request?.content.body.contains("Focus Block Soon") ?? false)
    }

    /// GIVEN: A focus block that already started (in the past)
    /// WHEN: Building notification request
    /// THEN: Should return nil (no notification for past blocks)
    func testNoNotificationForPastBlock() {
        let now = Date()
        let startDate = now.addingTimeInterval(-10 * 60)

        let request = NotificationService.buildFocusBlockNotificationRequest(
            blockID: "test-past",
            blockTitle: "Past Block",
            startDate: startDate,
            now: now
        )

        XCTAssertNil(request, "Should NOT create notification for past blocks")
    }

    /// GIVEN: A block ID "ABC-123"
    /// WHEN: Building notification request
    /// THEN: Identifier should be "focus-block-start-ABC-123"
    func testNotificationIdentifierFormat() {
        let now = Date()
        let startDate = now.addingTimeInterval(60 * 60)

        let request = NotificationService.buildFocusBlockNotificationRequest(
            blockID: "ABC-123",
            blockTitle: "Test",
            startDate: startDate,
            now: now
        )

        XCTAssertEqual(request?.identifier, "focus-block-start-ABC-123")
    }

    /// GIVEN: A focus block starting in 30 minutes
    /// WHEN: Building notification request
    /// THEN: Trigger time interval should be ~25 minutes (30 - 5 = 25 min before now)
    func testTriggerTimeIntervalFor5MinBefore() {
        let now = Date()
        let startDate = now.addingTimeInterval(30 * 60) // 30 min from now

        let request = NotificationService.buildFocusBlockNotificationRequest(
            blockID: "test-trigger",
            blockTitle: "Test",
            startDate: startDate,
            now: now
        )

        let trigger = request?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertNotNil(trigger)
        // Should fire 25 minutes from now (30 min start - 5 min before)
        XCTAssertEqual(trigger?.timeInterval ?? 0, 25 * 60, accuracy: 2.0)
    }
}
