import XCTest
import UserNotifications
@testable import FocusBlox

final class NotificationDailyNudgeTests: XCTestCase {

    // MARK: - Test Helpers

    private func windowStart(hour: Int = 10) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
    }

    private func windowEnd(hour: Int = 18) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
    }

    private func earlyMorning() -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    }

    private func lateEvening() -> Date {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
    }

    // MARK: - Survival returns empty

    /// Verhalten: Survival erzeugt KEINE Notifications — absolute Ruhe.
    /// Bricht wenn: der .survival Guard in buildDailyNudgeRequests entfernt wird.
    func test_buildDailyNudgeRequests_survival_returnsEmpty() {
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

    // MARK: - Count matches maxCount

    /// Verhalten: maxCount=2 erzeugt genau 2 Notification-Requests.
    /// Bricht wenn: die Schleifen-Logik die maxCount nicht respektiert.
    func test_buildDailyNudgeRequests_maxCount2_returnsTwoRequests() {
        let requests = NotificationService.buildDailyNudgeRequests(
            intention: .bhag,
            gap: .noBhagBlockCreated,
            windowStart: windowStart(),
            windowEnd: windowEnd(),
            maxCount: 2,
            now: earlyMorning()
        )
        XCTAssertEqual(requests.count, 2)
    }

    /// Verhalten: maxCount=1 erzeugt genau 1 Notification-Request.
    /// Bricht wenn: Minimum auf > 1 gesetzt oder maxCount ignoriert wird.
    func test_buildDailyNudgeRequests_maxCount1_returnsOneRequest() {
        let requests = NotificationService.buildDailyNudgeRequests(
            intention: .fokus,
            gap: .noFocusBlockPlanned,
            windowStart: windowStart(),
            windowEnd: windowEnd(),
            maxCount: 1,
            now: earlyMorning()
        )
        XCTAssertEqual(requests.count, 1)
    }

    // MARK: - Window validation

    /// Verhalten: Wenn Zeitfenster bereits vorbei → leeres Array.
    /// Bricht wenn: die windowEnd <= now Pruefung fehlt.
    func test_buildDailyNudgeRequests_whenWindowAlreadyPast_returnsEmpty() {
        let requests = NotificationService.buildDailyNudgeRequests(
            intention: .bhag,
            gap: .noBhagBlockCreated,
            windowStart: windowStart(hour: 10),
            windowEnd: windowEnd(hour: 18),
            maxCount: 2,
            now: lateEvening()
        )
        XCTAssertTrue(requests.isEmpty, "No notifications after window has passed")
    }

    // MARK: - Content correctness

    /// Verhalten: BHAG/noBhagBlock hat den korrekten Notification-Text.
    /// Bricht wenn: der Text-Mapping fuer .noBhagBlockCreated geaendert wird.
    func test_buildDailyNudgeRequests_bhagNoBhagBlock_hasCorrectBodyText() {
        let requests = NotificationService.buildDailyNudgeRequests(
            intention: .bhag,
            gap: .noBhagBlockCreated,
            windowStart: windowStart(),
            windowEnd: windowEnd(),
            maxCount: 1,
            now: earlyMorning()
        )
        XCTAssertFalse(requests.isEmpty)
        XCTAssertEqual(
            requests[0].content.body,
            "Du wolltest das grosse Ding anpacken. Wann legst du los?"
        )
    }

    // MARK: - Identifier format

    /// Verhalten: Identifier folgen dem Schema "coach-nudge-N".
    /// Bricht wenn: das Prefix oder die Nummerierung geaendert wird.
    func test_buildDailyNudgeRequests_identifiersHaveCorrectPrefix() {
        let requests = NotificationService.buildDailyNudgeRequests(
            intention: .bhag,
            gap: .noBhagBlockCreated,
            windowStart: windowStart(),
            windowEnd: windowEnd(),
            maxCount: 2,
            now: earlyMorning()
        )
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].identifier, "coach-nudge-0")
        XCTAssertEqual(requests[1].identifier, "coach-nudge-1")
    }

    // MARK: - Even distribution

    /// Verhalten: 3 Notifications in 8h-Fenster sind gleichmaessig verteilt (~2h40min Abstand).
    /// Bricht wenn: die Verteilungs-Logik nicht gleichmaessig aufteilt.
    func test_buildDailyNudgeRequests_fireDatesAreEvenlyDistributed() {
        let requests = NotificationService.buildDailyNudgeRequests(
            intention: .balance,
            gap: .onlySingleCategory,
            windowStart: windowStart(hour: 10),
            windowEnd: windowEnd(hour: 18),
            maxCount: 3,
            now: earlyMorning()
        )
        XCTAssertEqual(requests.count, 3)

        // Extract fire dates from time interval triggers
        let fireDates: [Date] = requests.compactMap { request in
            guard let trigger = request.trigger as? UNTimeIntervalNotificationTrigger else {
                return nil
            }
            return earlyMorning().addingTimeInterval(trigger.timeInterval)
        }
        XCTAssertEqual(fireDates.count, 3, "All requests should have time interval triggers")

        // Check spacing between consecutive notifications (tolerance: 60 seconds)
        let gap1 = fireDates[1].timeIntervalSince(fireDates[0])
        let gap2 = fireDates[2].timeIntervalSince(fireDates[1])
        XCTAssertEqual(gap1, gap2, accuracy: 60, "Gaps between notifications should be equal")
    }
}
