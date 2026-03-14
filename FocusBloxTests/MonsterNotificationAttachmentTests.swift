import XCTest
import UserNotifications
@testable import FocusBlox

@MainActor
final class MonsterNotificationAttachmentTests: XCTestCase {

    // MARK: - Test Helpers

    private func earlyMorning() -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    }

    private func windowStart() -> Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
    }

    private func windowEnd() -> Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
    }

    // MARK: - buildIntentionReminderRequest with coach

    /// Verhalten: Builder akzeptiert coach-Parameter und gibt gueltigen Request zurueck.
    /// Bricht wenn: coach-Parameter aus buildIntentionReminderRequest entfernt wird.
    func test_buildIntentionReminderRequest_withCoach_returnsValidRequest() {
        let request = NotificationService.buildIntentionReminderRequest(
            hour: 8, minute: 0, coach: .feuer
        )
        XCTAssertEqual(request.identifier, "coach-intention-reminder")
        XCTAssertEqual(request.content.title, "Guten Morgen")
    }

    /// Verhalten: Ohne coach kein Attachment (Backward-Kompatibilitaet).
    /// Bricht wenn: Attachments auch ohne coach-Parameter gesetzt werden.
    func test_buildIntentionReminderRequest_withoutCoach_noAttachments() {
        let request = NotificationService.buildIntentionReminderRequest(
            hour: 8, minute: 0
        )
        XCTAssertTrue(request.content.attachments.isEmpty,
            "Without coach, no attachment should be set")
    }

    // MARK: - buildEveningReminderRequest with coach

    /// Verhalten: Builder akzeptiert coach-Parameter.
    /// Bricht wenn: coach-Parameter aus buildEveningReminderRequest entfernt wird.
    func test_buildEveningReminderRequest_withCoach_returnsValidRequest() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20, minute: 0, coach: .golem, now: earlyMorning()
        )
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.content.title, "Dein Abend-Spiegel wartet")
    }

    /// Verhalten: Ohne coach kein Attachment (Backward-Kompatibilitaet).
    /// Bricht wenn: Attachments auch ohne coach-Parameter gesetzt werden.
    func test_buildEveningReminderRequest_withoutCoach_noAttachments() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20, minute: 0, now: earlyMorning()
        )
        XCTAssertTrue(request?.content.attachments.isEmpty ?? true,
            "Without coach, no attachment should be set")
    }

    // MARK: - buildMonsterAttachment

    /// Verhalten: buildMonsterAttachment existiert und crasht nicht fuer jeden Coach.
    /// Bricht wenn: Methode entfernt/umbenannt wird oder ein Mapping fehlt.
    func test_buildMonsterAttachment_allCoaches_noCrash() {
        for coach in CoachType.allCases {
            // In unit tests UIImage(named:) returns nil → attachment is nil (safe fallback).
            // This validates the API exists and handles missing images gracefully.
            let attachment = NotificationService.buildMonsterAttachment(for: coach)
            _ = attachment
        }
    }

    // MARK: - buildDailyNudgeRequests

    /// Verhalten: Nudge-Requests werden korrekt fuer Troll-Coach erzeugt.
    /// Bricht wenn: buildDailyNudgeRequests die coach/gap Parameter nicht akzeptiert.
    func test_buildDailyNudgeRequests_troll_producesRequests() {
        let requests = NotificationService.buildDailyNudgeRequests(
            coach: .troll,
            gap: .procrastinatedTasksPending,
            windowStart: windowStart(),
            windowEnd: windowEnd(),
            maxCount: 2,
            now: earlyMorning()
        )
        XCTAssertEqual(requests.count, 2, "Troll with gap should produce 2 nudge requests")
    }
}
