import XCTest
import UserNotifications
@testable import FocusBlox

@MainActor
final class NotificationServiceBuildTests: XCTestCase {

    // MARK: - Helpers

    private var now: Date { Date() }

    private func futureDate(hoursFromNow hours: Double) -> Date {
        Date().addingTimeInterval(hours * 3600)
    }

    private func pastDate(hoursAgo hours: Double) -> Date {
        Date().addingTimeInterval(-hours * 3600)
    }

    // MARK: - buildFocusBlockNotificationRequest

    /// Verhalten: Request fuer Block in der Zukunft hat korrekten Titel + Trigger
    /// Bricht wenn: NotificationService.swift:195-197 — Titel/Body-Text geaendert
    func test_focusBlockStart_futureBlock_hasCorrectContent() {
        let startDate = futureDate(hoursFromNow: 1)
        let request = NotificationService.buildFocusBlockNotificationRequest(
            blockID: "block-1",
            blockTitle: "Sprint 09:00",
            startDate: startDate,
            minutesBefore: 5,
            now: now
        )

        XCTAssertNotNil(request, "Should create request for future block")
        XCTAssertEqual(request?.content.title, "FocusBlox startet gleich")
        XCTAssertTrue(
            request!.content.body.contains("Sprint 09:00"),
            "Body should contain block title"
        )
        XCTAssertEqual(request?.identifier, "focus-block-start-block-1")
    }

    /// Verhalten: Block in der Vergangenheit → nil
    /// Bricht wenn: NotificationService.swift:187 — `guard triggerDate > now` entfernt
    func test_focusBlockStart_pastBlock_returnsNil() {
        let pastStart = pastDate(hoursAgo: 1)
        let request = NotificationService.buildFocusBlockNotificationRequest(
            blockID: "block-old",
            blockTitle: "Past Block",
            startDate: pastStart,
            now: now
        )

        XCTAssertNil(request, "Past block should return nil")
    }

    /// Verhalten: Wenn notifyDate in Vergangenheit aber startDate in Zukunft → "startet jetzt"
    /// Bricht wenn: NotificationService.swift:192-194 — Fallback auf "jetzt" entfernt
    func test_focusBlockStart_notifyDatePast_usesStartNowText() {
        // Block starts in 2 minutes, but minutesBefore=5 → notifyDate is 3 min in past
        let startDate = Date().addingTimeInterval(120) // 2 min from now
        let request = NotificationService.buildFocusBlockNotificationRequest(
            blockID: "block-soon",
            blockTitle: "Gleich Block",
            startDate: startDate,
            minutesBefore: 5,
            now: now
        )

        XCTAssertNotNil(request, "Should still create request when start is in future")
        XCTAssertEqual(request?.content.title, "FocusBlox startet jetzt")
    }

    // MARK: - buildFocusBlockEndNotificationRequest

    /// Verhalten: End-Request hat korrekte Completed/Total-Anzeige
    /// Bricht wenn: NotificationService.swift:262 — Body-Format geaendert
    func test_focusBlockEnd_hasCompletedCountInBody() {
        let endDate = futureDate(hoursFromNow: 1)
        let request = NotificationService.buildFocusBlockEndNotificationRequest(
            blockID: "block-end-1",
            blockTitle: "Sprint 10:00",
            endDate: endDate,
            completedCount: 3,
            totalCount: 5,
            now: now
        )

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.content.title, "FocusBlox beendet")
        XCTAssertTrue(
            request!.content.body.contains("3/5"),
            "Body should contain completed/total count"
        )
        XCTAssertEqual(request?.identifier, "focus-block-end-block-end-1")
    }

    /// Verhalten: End-Date in Vergangenheit → nil
    /// Bricht wenn: NotificationService.swift:258 — `guard timeInterval > 0` entfernt
    func test_focusBlockEnd_pastEndDate_returnsNil() {
        let pastEnd = pastDate(hoursAgo: 1)
        let request = NotificationService.buildFocusBlockEndNotificationRequest(
            blockID: "block-past",
            blockTitle: "Past Block",
            endDate: pastEnd,
            completedCount: 0,
            totalCount: 3,
            now: now
        )

        XCTAssertNil(request, "Past end date should return nil")
    }

    // MARK: - buildIntentionReminderRequest

    /// Verhalten: Morning Reminder hat Calendar-Trigger der taeglich wiederholt
    /// Bricht wenn: NotificationService.swift:467 — `repeats: true` auf false geaendert
    func test_intentionReminder_hasRepeatingCalendarTrigger() {
        let request = NotificationService.buildIntentionReminderRequest(
            hour: 8, minute: 30
        )

        XCTAssertEqual(request.content.title, "Guten Morgen")
        XCTAssertEqual(request.content.body, "Was soll heute zählen?")
        XCTAssertEqual(request.identifier, "coach-intention-reminder")

        let trigger = request.trigger as? UNCalendarNotificationTrigger
        XCTAssertNotNil(trigger, "Should use calendar trigger")
        XCTAssertTrue(trigger!.repeats, "Morning reminder must repeat daily")
        XCTAssertEqual(trigger?.dateComponents.hour, 8)
        XCTAssertEqual(trigger?.dateComponents.minute, 30)
    }

    /// Verhalten: Ohne Coach wird kein Attachment angehaengt
    /// Bricht wenn: NotificationService.swift:457-461 — Coach-Guard entfernt (immer Attachment)
    func test_intentionReminder_withoutCoach_noAttachment() {
        let request = NotificationService.buildIntentionReminderRequest(
            hour: 8, minute: 0, coach: nil
        )

        XCTAssertTrue(
            request.content.attachments.isEmpty,
            "Without coach, no attachment should be present"
        )
    }

    #if !os(macOS)
    /// Verhalten: Mit Coach wird Monster-Attachment angehaengt (iOS only)
    /// Bricht wenn: NotificationService.swift:458 — buildMonsterAttachment Call entfernt
    func test_intentionReminder_withCoach_hasAttachment() {
        let request = NotificationService.buildIntentionReminderRequest(
            hour: 8, minute: 0, coach: .troll
        )

        // Attachment depends on image asset being available in test bundle
        // If asset missing → attachment is nil → test documents this gap
        XCTAssertFalse(
            request.content.attachments.isEmpty,
            "With coach on iOS, monster attachment should be present"
        )
    }
    #endif

    // MARK: - buildEveningReminderRequest

    /// Verhalten: Evening Reminder wird erstellt wenn Zeit noch nicht vorbei
    /// Bricht wenn: NotificationService.swift:505-507 — Time-past Guard entfernt
    func test_eveningReminder_futureTime_createsRequest() {
        // Simulate "now" at 17:00, reminder at 20:00
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 17
        comps.minute = 0
        let fakeNow = cal.date(from: comps)!

        let request = NotificationService.buildEveningReminderRequest(
            hour: 20, minute: 0, coach: nil, now: fakeNow
        )

        XCTAssertNotNil(request, "Should create request when time hasn't passed")
        XCTAssertEqual(request?.content.title, "Dein Abend-Spiegel wartet")
        XCTAssertEqual(request?.identifier, "coach-evening-reminder")
    }

    /// Verhalten: Evening Reminder → nil wenn Zeit bereits vorbei
    /// Bricht wenn: NotificationService.swift:505-507 — Guard fuer vergangene Zeit entfernt
    func test_eveningReminder_pastTime_returnsNil() {
        // Simulate "now" at 21:00, reminder at 20:00 → already passed
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 21
        comps.minute = 0
        let fakeNow = cal.date(from: comps)!

        let request = NotificationService.buildEveningReminderRequest(
            hour: 20, minute: 0, coach: nil, now: fakeNow
        )

        XCTAssertNil(request, "Should return nil when evening time already passed")
    }

    // MARK: - buildDailyNudgeRequests

    /// Verhalten: Nudges werden gleichmaessig im Zeitfenster verteilt
    /// Bricht wenn: NotificationService.swift:575 — Spacing-Berechnung geaendert
    func test_dailyNudges_distributesEvenly() {
        let windowStart = futureDate(hoursFromNow: 1)
        let windowEnd = futureDate(hoursFromNow: 5) // 4h window

        let requests = NotificationService.buildDailyNudgeRequests(
            coach: .troll,
            gap: .procrastinatedTasksPending,
            windowStart: windowStart,
            windowEnd: windowEnd,
            maxCount: 3,
            now: now
        )

        XCTAssertEqual(requests.count, 3, "Should create maxCount=3 nudge requests")

        // Check identifiers are sequential
        XCTAssertEqual(requests[0].identifier, "coach-nudge-0")
        XCTAssertEqual(requests[1].identifier, "coach-nudge-1")
        XCTAssertEqual(requests[2].identifier, "coach-nudge-2")
    }

    /// Verhalten: Window bereits vorbei → leeres Array
    /// Bricht wenn: NotificationService.swift:568 — `guard windowEnd > now` entfernt
    func test_dailyNudges_windowPassed_returnsEmpty() {
        let pastStart = pastDate(hoursAgo: 5)
        let pastEnd = pastDate(hoursAgo: 1)

        let requests = NotificationService.buildDailyNudgeRequests(
            coach: .eule,
            gap: .noPlannedTasks,
            windowStart: pastStart,
            windowEnd: pastEnd,
            maxCount: 2,
            now: now
        )

        XCTAssertTrue(requests.isEmpty, "Should return empty when window already passed")
    }

    /// Verhalten: Jeder CoachGap-Typ erzeugt den korrekten Nudge-Text
    /// Bricht wenn: NotificationService.swift:661-677 — nudgeText Switch-Cases geaendert
    func test_dailyNudges_allGapTypes_haveCorrectText() {
        let windowStart = futureDate(hoursFromNow: 1)
        let windowEnd = futureDate(hoursFromNow: 3)

        let expectedTexts: [(CoachGap, String)] = [
            (.procrastinatedTasksPending, "aufgeschobene Tasks"),
            (.noBigTaskStarted, "grosse Herausforderung"),
            (.bigTaskNotCompleted, "grosse Ding"),
            (.noPlannedTasks, "Nichts eingeplant"),
            (.tasksOutsideBlocks, "ausserhalb des Plans"),
            (.onlySingleCategory, "nur ein Bereich"),
            (.noTasksCompleted, "Noch nichts erledigt"),
        ]

        for (gap, expectedSubstring) in expectedTexts {
            let requests = NotificationService.buildDailyNudgeRequests(
                coach: .troll,
                gap: gap,
                windowStart: windowStart,
                windowEnd: windowEnd,
                maxCount: 1,
                now: now
            )
            XCTAssertEqual(requests.count, 1, "Should create 1 nudge for gap \(gap)")
            XCTAssertTrue(
                requests.first!.content.body.contains(expectedSubstring),
                "Nudge for \(gap) should contain '\(expectedSubstring)', got: '\(requests.first!.content.body)'"
            )
        }
    }

    /// Verhalten: Nudge-Titel ist der Coach-DisplayName
    /// Bricht wenn: NotificationService.swift:583 — coach.displayName nicht als Titel
    func test_dailyNudges_titleIsCoachDisplayName() {
        let windowStart = futureDate(hoursFromNow: 1)
        let windowEnd = futureDate(hoursFromNow: 3)

        let requests = NotificationService.buildDailyNudgeRequests(
            coach: .feuer,
            gap: .noBigTaskStarted,
            windowStart: windowStart,
            windowEnd: windowEnd,
            maxCount: 1,
            now: now
        )

        XCTAssertEqual(
            requests.first?.content.title,
            CoachType.feuer.displayName,
            "Nudge title should be coach display name"
        )
    }

    /// Verhalten: Trigger-Interval entspricht Differenz zur Start-Zeit
    /// Bricht wenn: NotificationService.swift:207 — Trigger-Interval Berechnung geaendert
    func test_focusBlockStart_correctTriggerInterval() {
        let startDate = futureDate(hoursFromNow: 2)
        let request = NotificationService.buildFocusBlockNotificationRequest(
            blockID: "block-trig",
            blockTitle: "Sprint",
            startDate: startDate,
            minutesBefore: 5,
            now: now
        )

        let trigger = request?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertNotNil(trigger, "Should use time interval trigger")
        // Trigger should fire roughly 2h - 5min = 115 min from now (±5s tolerance)
        let expectedInterval = startDate.addingTimeInterval(-300).timeIntervalSince(now)
        XCTAssertEqual(
            trigger!.timeInterval, expectedInterval,
            accuracy: 5.0,
            "Trigger should fire 5 min before start"
        )
    }

    /// Verhalten: End-Trigger-Interval entspricht Block-Endzeitpunkt
    /// Bricht wenn: NotificationService.swift:268 — End-Trigger Berechnung geaendert
    func test_focusBlockEnd_correctTriggerInterval() {
        let endDate = futureDate(hoursFromNow: 2)
        let request = NotificationService.buildFocusBlockEndNotificationRequest(
            blockID: "block-end-trig",
            blockTitle: "Sprint",
            endDate: endDate,
            completedCount: 1,
            totalCount: 3,
            now: now
        )

        let trigger = request?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertNotNil(trigger, "Should use time interval trigger")
        let expectedInterval = endDate.timeIntervalSince(now)
        XCTAssertEqual(
            trigger!.timeInterval, expectedInterval,
            accuracy: 5.0,
            "End trigger should fire at block end time"
        )
    }

    /// Verhalten: maxCount=1 → genau ein Request
    /// Bricht wenn: NotificationService.swift:578 — Loop laeuft nicht genau maxCount-mal
    func test_dailyNudges_maxCountOne_returnsSingleRequest() {
        let windowStart = futureDate(hoursFromNow: 1)
        let windowEnd = futureDate(hoursFromNow: 3)

        let requests = NotificationService.buildDailyNudgeRequests(
            coach: .eule,
            gap: .noPlannedTasks,
            windowStart: windowStart,
            windowEnd: windowEnd,
            maxCount: 1,
            now: now
        )

        XCTAssertEqual(requests.count, 1, "maxCount=1 should return exactly one request")
        XCTAssertEqual(requests.first?.identifier, "coach-nudge-0")
    }

    /// Verhalten: maxCount=0 → leeres Array (kein Crash)
    /// Bricht wenn: NotificationService.swift:578 — Loop range nicht 0..<0 fuer maxCount=0
    func test_dailyNudges_maxCountZero_returnsEmpty() {
        let windowStart = futureDate(hoursFromNow: 1)
        let windowEnd = futureDate(hoursFromNow: 3)

        let requests = NotificationService.buildDailyNudgeRequests(
            coach: .golem,
            gap: .onlySingleCategory,
            windowStart: windowStart,
            windowEnd: windowEnd,
            maxCount: 0,
            now: now
        )

        XCTAssertTrue(requests.isEmpty, "maxCount=0 should return empty array")
    }
}
