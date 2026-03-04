import XCTest
import UserNotifications
@testable import FocusBlox

@MainActor
final class BadgeOverdueNotificationTests: XCTestCase {

    // MARK: - categoryIdentifier + userInfo on Due Date Notifications

    /// Verhalten: Morning-Request muss categoryIdentifier + userInfo["taskID"] enthalten
    /// Bricht wenn: buildDueDateMorningRequest() KEIN content.categoryIdentifier setzt
    ///   und KEIN content.userInfo = ["taskID": taskID] setzt
    func test_morningRequest_hasCategoryAndUserInfo() {
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let dueDate = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow)!

        let request = NotificationService.buildDueDateMorningRequest(
            taskID: "task-123",
            title: "Test Task",
            dueDate: dueDate,
            morningHour: 9,
            morningMinute: 0,
            now: now
        )

        XCTAssertNotNil(request, "Request should not be nil for valid future dueDate")
        XCTAssertEqual(
            request?.content.categoryIdentifier,
            "DUE_DATE_INTERACTIVE",
            "Morning request must have interactive category for action buttons"
        )
        XCTAssertEqual(
            request?.content.userInfo["taskID"] as? String,
            "task-123",
            "Morning request must include taskID in userInfo for action handling"
        )
    }

    /// Verhalten: Advance-Request muss categoryIdentifier + userInfo["taskID"] enthalten
    /// Bricht wenn: buildDueDateAdvanceRequest() KEIN content.categoryIdentifier setzt
    ///   und KEIN content.userInfo = ["taskID": taskID] setzt
    func test_advanceRequest_hasCategoryAndUserInfo() {
        let now = Date()
        let dueDate = now.addingTimeInterval(2 * 3600) // 2 hours from now

        let request = NotificationService.buildDueDateAdvanceRequest(
            taskID: "task-456",
            title: "Advance Task",
            dueDate: dueDate,
            advanceMinutes: 60,
            now: now
        )

        XCTAssertNotNil(request, "Request should not be nil for valid future dueDate")
        XCTAssertEqual(
            request?.content.categoryIdentifier,
            "DUE_DATE_INTERACTIVE",
            "Advance request must have interactive category for action buttons"
        )
        XCTAssertEqual(
            request?.content.userInfo["taskID"] as? String,
            "task-456",
            "Advance request must include taskID in userInfo for action handling"
        )
    }

    // MARK: - Category Registration

    /// Verhalten: Nach App-Start muss DUE_DATE_INTERACTIVE Category mit 3 Actions registriert sein
    /// Bricht wenn: registerDueDateActions() nicht existiert oder nicht aufgerufen wird
    func test_dueDateCategory_isRegistered() async {
        let categories = await UNUserNotificationCenter.current().notificationCategories()

        let dueDateCategory = categories.first { $0.identifier == "DUE_DATE_INTERACTIVE" }
        XCTAssertNotNil(dueDateCategory, "DUE_DATE_INTERACTIVE category must be registered")

        let actionIDs = dueDateCategory?.actions.map(\.identifier) ?? []
        XCTAssertTrue(actionIDs.contains("ACTION_NEXT_UP"), "Must have NextUp action")
        XCTAssertTrue(actionIDs.contains("ACTION_POSTPONE"), "Must have Postpone action")
        XCTAssertTrue(actionIDs.contains("ACTION_COMPLETE"), "Must have Complete action")
        XCTAssertEqual(dueDateCategory?.actions.count, 3, "Must have exactly 3 actions")
    }
}
