import XCTest
import UserNotifications
@testable import FocusBlox

@MainActor
final class NotificationEveningReminderTests: XCTestCase {

    // MARK: - Test Helpers

    private func timeToday(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    // MARK: - Valid request

    /// Verhalten: Bei gueltigem Zeitfenster (now < scheduled time) wird ein Request zurueckgegeben.
    /// Bricht wenn: buildEveningReminderRequest entfernt oder Return-Typ geaendert wird.
    func test_buildRequest_returnsValidRequest_whenBeforeScheduledTime() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20,
            minute: 0,
            now: timeToday(hour: 15)
        )
        XCTAssertNotNil(request, "Should return a request when current time is before scheduled time")
    }

    // MARK: - Time-already-passed guard

    /// Verhalten: Wenn die eingestellte Uhrzeit heute schon vorbei ist → nil.
    /// Bricht wenn: der Zeitvergleichs-Guard (currentHour > hour) entfernt wird.
    func test_buildRequest_returnsNil_whenTimeAlreadyPassed() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20,
            minute: 0,
            now: timeToday(hour: 20, minute: 30)
        )
        XCTAssertNil(request, "Should return nil when scheduled time has already passed")
    }

    /// Verhalten: Exakte Uhrzeit = schon vorbei → nil.
    /// Bricht wenn: >= zu > geaendert wird (Boundary-Fehler).
    func test_buildRequest_returnsNil_whenExactTime() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20,
            minute: 0,
            now: timeToday(hour: 20, minute: 0)
        )
        XCTAssertNil(request, "Should return nil when current time equals scheduled time")
    }

    /// Verhalten: Eine Minute vor der eingestellten Zeit → gueltig.
    /// Bricht wenn: die Grenzwert-Logik fehlerhaft ist.
    func test_buildRequest_returnsRequest_oneMinuteBefore() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20,
            minute: 0,
            now: timeToday(hour: 19, minute: 59)
        )
        XCTAssertNotNil(request, "Should return a request one minute before scheduled time")
    }

    // MARK: - Identifier

    /// Verhalten: Identifier ist exakt "coach-evening-reminder".
    /// Bricht wenn: die eveningReminderID Konstante geaendert wird.
    func test_buildRequest_hasCorrectIdentifier() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20,
            minute: 0,
            now: timeToday(hour: 15)
        )
        XCTAssertEqual(request?.identifier, "coach-evening-reminder")
    }

    // MARK: - Content

    /// Verhalten: Title und Body sind korrekt deutsch.
    /// Bricht wenn: die Content-Strings geaendert werden.
    func test_buildRequest_hasCorrectContent() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20,
            minute: 0,
            now: timeToday(hour: 15)
        )
        XCTAssertEqual(request?.content.title, "Dein Abend-Spiegel wartet")
        XCTAssertEqual(request?.content.body, "Wie war dein Tag? Schau kurz rein.")
        XCTAssertNotNil(request?.content.sound, "Should have a sound")
    }

    // MARK: - Trigger

    /// Verhalten: Trigger ist ein UNCalendarNotificationTrigger mit korrekter Uhrzeit.
    /// Bricht wenn: ein anderer Trigger-Typ verwendet wird oder hour/minute falsch gesetzt.
    func test_buildRequest_triggerIsCalendarWithCorrectTime() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 21,
            minute: 30,
            now: timeToday(hour: 15)
        )
        guard let trigger = request?.trigger as? UNCalendarNotificationTrigger else {
            XCTFail("Trigger should be UNCalendarNotificationTrigger")
            return
        }
        XCTAssertEqual(trigger.dateComponents.hour, 21)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
    }

    /// Verhalten: Trigger ist repeating (taeglich).
    /// Bricht wenn: repeats auf false gesetzt wird.
    func test_buildRequest_triggerRepeats() {
        let request = NotificationService.buildEveningReminderRequest(
            hour: 20,
            minute: 0,
            now: timeToday(hour: 15)
        )
        guard let trigger = request?.trigger as? UNCalendarNotificationTrigger else {
            XCTFail("Trigger should be UNCalendarNotificationTrigger")
            return
        }
        XCTAssertTrue(trigger.repeats, "Evening reminder should repeat daily")
    }
}
