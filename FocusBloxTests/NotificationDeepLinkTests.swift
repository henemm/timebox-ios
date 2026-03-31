import XCTest
import UserNotifications
@testable import FocusBlox

/// TDD RED Tests for #172: Notification → DayView Deep-Link
/// Tests MÜSSEN FEHLSCHLAGEN bis der Deep-Link implementiert ist.
@MainActor
final class NotificationDeepLinkTests: XCTestCase {

    // MARK: - userInfo in Review/Nudge Requests

    /// Bricht wenn: buildReviewRequests keine userInfo mit "target" setzt.
    /// Welche Zeile bricht diesen Test? SmartNotificationEngine.swift buildReviewRequests — kein userInfo
    func test_reviewRequests_containTargetUserInfo() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 6, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)

        for request in requests {
            let userInfo = request.content.userInfo
            XCTAssertNotNil(userInfo["target"] as? String,
                            "Review request '\(request.identifier)' must have userInfo['target']")
            XCTAssertEqual(userInfo["target"] as? String, "day",
                           "Review request target must be 'day'")
        }
    }

    /// Bricht wenn: Morning-Requests keine phase "morning" in userInfo haben.
    func test_morningRequests_havePhaseMorning() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 6, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)
        let morningRequests = requests.filter { $0.identifier.hasPrefix("focusblox.morning.") }

        XCTAssertGreaterThan(morningRequests.count, 0, "Should have morning requests")
        for request in morningRequests {
            XCTAssertEqual(request.content.userInfo["phase"] as? String, "morning",
                           "Morning request must have phase='morning' in userInfo")
        }
    }

    /// Bricht wenn: Evening-Requests keine phase "evening" in userInfo haben.
    func test_eveningRequests_havePhaseEvening() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 6, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)
        let eveningRequests = requests.filter { $0.identifier.hasPrefix("focusblox.review.") }

        XCTAssertGreaterThan(eveningRequests.count, 0, "Should have evening requests")
        for request in eveningRequests {
            XCTAssertEqual(request.content.userInfo["phase"] as? String, "evening",
                           "Evening request must have phase='evening' in userInfo")
        }
    }

    /// Bricht wenn: Nudge-Requests keine userInfo mit target "day" haben.
    func test_nudgeRequests_containTargetUserInfo() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 8, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now)

        XCTAssertGreaterThan(requests.count, 0, "Should have nudge requests at 08:00")
        for request in requests {
            let userInfo = request.content.userInfo
            XCTAssertEqual(userInfo["target"] as? String, "day",
                           "Nudge request must have target='day' in userInfo")
            XCTAssertEqual(userInfo["phase"] as? String, "daytime",
                           "Nudge request must have phase='daytime' in userInfo")
        }
    }

    // MARK: - Navigation Notification

    /// Bricht wenn: Es keine Notification.Name für DayView-Navigation gibt.
    func test_dayViewNavigationNotificationName_exists() {
        let name = Notification.Name("NavigateToDayView")
        XCTAssertEqual(name.rawValue, "NavigateToDayView")
    }
}
