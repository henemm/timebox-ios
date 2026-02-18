import XCTest
import UserNotifications
@testable import FocusBlox

/// Unit Tests for Due Date Notification scheduling (build*Request pure functions)
/// TDD RED: These tests MUST FAIL because the methods don't exist yet
@MainActor
final class DueDateNotificationTests: XCTestCase {

    // MARK: - Morning Request Tests

    /// GIVEN: dueDate tomorrow 18:00, morningHour 9, morningMinute 0
    /// WHEN: buildDueDateMorningRequest()
    /// THEN: Request with CalendarTrigger for tomorrow 09:00
    func testBuildDueDateMorningRequest_normalCase() {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let dueDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow)!

        let request = NotificationService.buildDueDateMorningRequest(
            taskID: "task-1",
            title: "Steuererklärung",
            dueDate: dueDate,
            morningHour: 9,
            morningMinute: 0,
            now: now
        )

        XCTAssertNotNil(request, "Should create morning notification for future dueDate")
        XCTAssertEqual(request?.identifier, "due-date-morning-task-1")
        XCTAssertEqual(request?.content.title, "Heute fällig")
        XCTAssertTrue(request?.content.body.contains("Steuererklärung") ?? false)

        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        XCTAssertNotNil(trigger, "Should use CalendarNotificationTrigger")
        XCTAssertEqual(trigger?.dateComponents.hour, 9)
        XCTAssertEqual(trigger?.dateComponents.minute, 0)
        XCTAssertFalse(trigger?.repeats ?? true, "Should not repeat")
    }

    /// GIVEN: dueDate yesterday
    /// WHEN: buildDueDateMorningRequest()
    /// THEN: nil (past dueDate)
    func testBuildDueDateMorningRequest_pastDueDate() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-24 * 60 * 60)

        let request = NotificationService.buildDueDateMorningRequest(
            taskID: "task-past",
            title: "Verpasst",
            dueDate: yesterday,
            morningHour: 9,
            morningMinute: 0,
            now: now
        )

        XCTAssertNil(request, "Should NOT create notification for past dueDate")
    }

    /// GIVEN: dueDate today 08:00, morningHour 9
    /// WHEN: buildDueDateMorningRequest()
    /// THEN: nil (morning time 09:00 is AFTER dueDate 08:00)
    func testBuildDueDateMorningRequest_morningAfterDueDate() {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let dueDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)!

        let request = NotificationService.buildDueDateMorningRequest(
            taskID: "task-early",
            title: "Früher Termin",
            dueDate: dueDate,
            morningHour: 9,
            morningMinute: 0,
            now: now
        )

        XCTAssertNil(request, "Should NOT create morning notification when morning time is after dueDate")
    }

    // MARK: - Advance Request Tests

    /// GIVEN: dueDate in 2 hours, advanceMinutes 60
    /// WHEN: buildDueDateAdvanceRequest()
    /// THEN: Request with TimeIntervalTrigger for ~1h from now
    func testBuildDueDateAdvanceRequest_normalCase() {
        let now = Date()
        let dueDate = now.addingTimeInterval(2 * 60 * 60) // 2 hours from now

        let request = NotificationService.buildDueDateAdvanceRequest(
            taskID: "task-2",
            title: "Meeting Vorbereitung",
            dueDate: dueDate,
            advanceMinutes: 60,
            now: now
        )

        XCTAssertNotNil(request, "Should create advance notification for future dueDate")
        XCTAssertEqual(request?.identifier, "due-date-advance-task-2")
        XCTAssertTrue(request?.content.body.contains("Meeting Vorbereitung") ?? false)

        let trigger = request?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertNotNil(trigger, "Should use TimeIntervalNotificationTrigger")
        // Should fire in ~1h (dueDate minus 60min advance = 1h from now)
        XCTAssertEqual(trigger?.timeInterval ?? 0, 60 * 60, accuracy: 5.0)
        XCTAssertFalse(trigger?.repeats ?? true, "Should not repeat")
    }

    /// GIVEN: dueDate yesterday
    /// WHEN: buildDueDateAdvanceRequest()
    /// THEN: nil (past dueDate)
    func testBuildDueDateAdvanceRequest_pastDueDate() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-24 * 60 * 60)

        let request = NotificationService.buildDueDateAdvanceRequest(
            taskID: "task-past-2",
            title: "Verpasst",
            dueDate: yesterday,
            advanceMinutes: 60,
            now: now
        )

        XCTAssertNil(request, "Should NOT create notification for past dueDate")
    }

    /// GIVEN: dueDate in 30 min, advanceMinutes 60
    /// WHEN: buildDueDateAdvanceRequest()
    /// THEN: nil (advance time larger than remaining time → fire date in past)
    func testBuildDueDateAdvanceRequest_advanceLargerThanRemaining() {
        let now = Date()
        let dueDate = now.addingTimeInterval(30 * 60) // 30 min from now

        let request = NotificationService.buildDueDateAdvanceRequest(
            taskID: "task-soon",
            title: "Gleich fällig",
            dueDate: dueDate,
            advanceMinutes: 60, // 1h advance but only 30min left
            now: now
        )

        XCTAssertNil(request, "Should NOT create notification when advance time > remaining time")
    }

    // MARK: - Notification ID Format Tests

    /// GIVEN: taskID "ABC-123"
    /// WHEN: building morning and advance requests
    /// THEN: IDs follow schema "due-date-morning-ABC-123" / "due-date-advance-ABC-123"
    func testNotificationIdentifierFormat() {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let dueDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow)!

        let morningReq = NotificationService.buildDueDateMorningRequest(
            taskID: "ABC-123",
            title: "Test",
            dueDate: dueDate,
            morningHour: 9,
            morningMinute: 0,
            now: now
        )

        let advanceReq = NotificationService.buildDueDateAdvanceRequest(
            taskID: "ABC-123",
            title: "Test",
            dueDate: dueDate,
            advanceMinutes: 60,
            now: now
        )

        XCTAssertEqual(morningReq?.identifier, "due-date-morning-ABC-123")
        XCTAssertEqual(advanceReq?.identifier, "due-date-advance-ABC-123")
    }
}
