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

    // MARK: - buildIntentionReminderRequest with intention (RED: parameter doesn't exist yet)

    /// Verhalten: Builder akzeptiert neuen intention-Parameter und gibt gueltigen Request zurueck.
    /// Bricht wenn: intention-Parameter aus buildIntentionReminderRequest entfernt wird.
    func test_buildIntentionReminderRequest_withIntention_returnsValidRequest() {
        let request = NotificationService.buildIntentionReminderRequest(
            hour: 8, minute: 0, intention: .bhag
        )
        XCTAssertEqual(request.identifier, "coach-intention-reminder")
        XCTAssertEqual(request.content.title, "Guten Morgen")
    }

    /// Verhalten: Ohne intention kein Attachment (Backward-Kompatibilitaet).
    /// Bricht wenn: Attachments auch ohne intention-Parameter gesetzt werden.
    func test_buildIntentionReminderRequest_withoutIntention_noAttachments() {
        let request = NotificationService.buildIntentionReminderRequest(
            hour: 8, minute: 0
        )
        XCTAssertTrue(request.content.attachments.isEmpty,
            "Without intention, no attachment should be set")
    }

    // MARK: - buildEveningReminderRequest with intention (RED: parameter doesn't exist yet)

    /// Verhalten: Builder akzeptiert neuen intention-Parameter.
    /// Bricht wenn: intention-Parameter aus buildEveningReminderRequest entfernt wird.
    func test_buildEveningReminderRequest_withIntention_returnsValidRequest() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20, minute: 0, intention: .connection, now: earlyMorning()
        )
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.content.title, "Dein Abend-Spiegel wartet")
    }

    /// Verhalten: Ohne intention kein Attachment (Backward-Kompatibilitaet).
    /// Bricht wenn: Attachments auch ohne intention-Parameter gesetzt werden.
    func test_buildEveningReminderRequest_withoutIntention_noAttachments() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20, minute: 0, now: earlyMorning()
        )
        XCTAssertTrue(request?.content.attachments.isEmpty ?? true,
            "Without intention, no attachment should be set")
    }

    // MARK: - buildMonsterAttachment (RED: method doesn't exist yet)

    /// Verhalten: buildMonsterAttachment existiert und crasht nicht fuer jede Intention.
    /// Bricht wenn: Methode entfernt/umbenannt wird oder ein Mapping fehlt.
    func test_buildMonsterAttachment_allIntentions_noCrash() {
        for option in IntentionOption.allCases {
            // In unit tests UIImage(named:) returns nil → attachment is nil (safe fallback).
            // This validates the API exists and handles missing images gracefully.
            let attachment = NotificationService.buildMonsterAttachment(for: option)
            _ = attachment
        }
    }

    // MARK: - Regression: Survival still returns empty

    /// Verhalten: Survival erzeugt weiterhin keine Requests (Attachment-Code aendert nichts).
    /// Bricht wenn: der .survival Guard entfernt wird.
    func test_buildDailyNudgeRequests_survival_stillReturnsEmpty() {
        let requests = NotificationService.buildDailyNudgeRequests(
            intention: .survival,
            gap: .noBhagBlockCreated,
            windowStart: windowStart(),
            windowEnd: windowEnd(),
            maxCount: 2,
            now: earlyMorning()
        )
        XCTAssertTrue(requests.isEmpty, "Survival must never produce notifications")
    }
}
