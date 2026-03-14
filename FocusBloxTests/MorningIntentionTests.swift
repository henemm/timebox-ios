import XCTest
@testable import FocusBlox

final class MorningIntentionTests: XCTestCase {

    // MARK: - CoachType Tests

    func test_allCases_have4Coaches() {
        XCTAssertEqual(CoachType.allCases.count, 4)
    }

    func test_eachCoach_hasDisplayNameAndIcon() {
        for coach in CoachType.allCases {
            XCTAssertFalse(coach.displayName.isEmpty, "\(coach.rawValue) should have a displayName")
            XCTAssertFalse(coach.icon.isEmpty, "\(coach.rawValue) should have an icon")
        }
    }

    func test_trollCoach_properties() {
        let coach = CoachType.troll
        XCTAssertEqual(coach.displayName, "Troll")
        XCTAssertEqual(coach.subtitle, "Der Aufräumer")
    }

    func test_feuerCoach_properties() {
        let coach = CoachType.feuer
        XCTAssertEqual(coach.displayName, "Feuer")
        XCTAssertEqual(coach.subtitle, "Der Herausforderer")
    }

    func test_euleCoach_properties() {
        let coach = CoachType.eule
        XCTAssertEqual(coach.displayName, "Eule")
        XCTAssertEqual(coach.subtitle, "Der Fokussierer")
    }

    func test_golemCoach_properties() {
        let coach = CoachType.golem
        XCTAssertEqual(coach.displayName, "Golem")
        XCTAssertEqual(coach.subtitle, "Der Balancer")
    }

    // MARK: - DailyCoachSelection Tests

    func test_emptySelection_isSetFalse() {
        let selection = DailyCoachSelection(date: "2026-03-14", coach: nil)
        XCTAssertFalse(selection.isSet)
    }

    func test_selectionWithCoach_isSetTrue() {
        let selection = DailyCoachSelection(date: "2026-03-14", coach: .troll)
        XCTAssertTrue(selection.isSet)
    }

    func test_todayKey_format() {
        let key = DailyCoachSelection.todayKey()
        XCTAssertTrue(key.hasPrefix("dailyCoach_"))
        let datePart = key.replacingOccurrences(of: "dailyCoach_", with: "")
        XCTAssertEqual(datePart.count, 10, "Date part should be YYYY-MM-DD format")
        XCTAssertTrue(datePart.contains("-"), "Date should contain dashes")
    }

    func test_saveAndLoad_roundtrip() {
        var selection = DailyCoachSelection(date: DailyCoachSelection.todayDateString(), coach: .feuer)
        selection.save()

        let loaded = DailyCoachSelection.load()
        XCTAssertEqual(loaded.coach, .feuer)
        XCTAssertTrue(loaded.isSet)
    }

    // MARK: - Notification Reminder Tests

    @MainActor
    func test_buildIntentionReminderRequest_correctID() {
        let request = NotificationService.buildIntentionReminderRequest(hour: 7, minute: 0)
        XCTAssertEqual(request.identifier, "coach-intention-reminder")
    }

    @MainActor
    func test_buildIntentionReminderRequest_correctTrigger() {
        let request = NotificationService.buildIntentionReminderRequest(hour: 8, minute: 30)
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        XCTAssertNotNil(trigger, "Trigger should be UNCalendarNotificationTrigger")
        XCTAssertTrue(trigger!.repeats, "Trigger should repeat daily")
        XCTAssertEqual(trigger!.dateComponents.hour, 8)
        XCTAssertEqual(trigger!.dateComponents.minute, 30)
    }

    @MainActor
    func test_buildIntentionReminderRequest_correctContent() {
        let request = NotificationService.buildIntentionReminderRequest(hour: 7, minute: 0)
        XCTAssertEqual(request.content.title, "Guten Morgen")
        XCTAssertEqual(request.content.body, "Was soll heute zählen?")
    }
}
