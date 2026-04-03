import XCTest
import UserNotifications
@testable import FocusBlox

/// TDD RED: Intentionsbasierte Nudge-Inhalte (#170 letzter Teil).
/// Tests MÜSSEN FEHLSCHLAGEN — intentionText-Parameter existiert noch nicht.
@MainActor
final class SmartNotificationEngineIntentionTests: XCTestCase {

    override func setUpWithError() throws {
        UserDefaults.standard.set(2, forKey: "nudgeDailyBudget")
        UserDefaults.standard.set(9, forKey: "morningReminderHour")
        UserDefaults.standard.set(20, forKey: "eveningReflectionHour")
        UserDefaults.standard.set(false, forKey: "nudgeSilenceOnSuccess")
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "nudgeDailyBudget")
        UserDefaults.standard.removeObject(forKey: "morningReminderHour")
        UserDefaults.standard.removeObject(forKey: "eveningReflectionHour")
        UserDefaults.standard.removeObject(forKey: "nudgeSilenceOnSuccess")
    }

    // MARK: - Intention-Based Content

    /// Verhalten: Mit Intention → Nudge-Body referenziert die Intention.
    /// Bricht wenn: intentionText-Parameter fehlt oder Body statisch bleibt.
    func test_nudge_withIntention_bodyReferencesIntention() {
        let now = makeTime(hour: 8, minute: 0)
        let intention = "Fokus auf das Projektkonzept"

        let requests = SmartNotificationEngine.buildNudgeRequests(
            now: now,
            completedTodayCount: 0,
            intentionText: intention
        )

        XCTAssertGreaterThan(requests.count, 0, "Mit Intention sollte mindestens 1 Nudge kommen")

        for request in requests {
            let body = request.content.body
            // Body muss die Intention referenzieren (nicht wortwörtlich, aber enthalten)
            XCTAssertTrue(
                body.localizedCaseInsensitiveContains("Projektkonzept"),
                "Nudge-Body '\(body)' sollte die Intention referenzieren"
            )
        }
    }

    /// Verhalten: Ohne Intention (nil) → keine Nudges.
    /// Bricht wenn: buildNudgeRequests weiterhin statische Texte liefert ohne Intention.
    func test_nudge_withoutIntention_returnsEmpty() {
        let now = makeTime(hour: 8, minute: 0)

        let requests = SmartNotificationEngine.buildNudgeRequests(
            now: now,
            completedTodayCount: 0,
            intentionText: nil
        )

        XCTAssertEqual(requests.count, 0,
            "Ohne Intention sollten keine Nudges gesendet werden")
    }

    /// Verhalten: Leerer Intentions-Text → keine Nudges (wie nil).
    /// Bricht wenn: Leerer String nicht wie nil behandelt wird.
    func test_nudge_emptyIntention_returnsEmpty() {
        let now = makeTime(hour: 8, minute: 0)

        let requests = SmartNotificationEngine.buildNudgeRequests(
            now: now,
            completedTodayCount: 0,
            intentionText: ""
        )

        XCTAssertEqual(requests.count, 0,
            "Leerer Intentions-Text sollte keine Nudges erzeugen")
    }

    /// Verhalten: Nudge-Body ist nicht wortwörtliches Echo der Intention.
    /// Bricht wenn: Body == intentionText (kein Mehrwert, fühlt sich wie Spam an).
    func test_nudge_bodyIsNotVerbatimEcho() {
        let now = makeTime(hour: 8, minute: 0)
        let intention = "Fokus auf das Projektkonzept"

        let requests = SmartNotificationEngine.buildNudgeRequests(
            now: now,
            completedTodayCount: 0,
            intentionText: intention
        )

        for request in requests {
            XCTAssertNotEqual(request.content.body, intention,
                "Nudge-Body darf nicht wortwörtlich die Intention wiederholen")
        }
    }

    /// Verhalten: Nudge-Body ist kurz genug für Sperrbildschirm (max 100 Zeichen).
    /// Bricht wenn: Templates zu lang sind.
    func test_nudge_bodyIsShortEnough() {
        let now = makeTime(hour: 8, minute: 0)
        let intention = "Fokus auf das Projektkonzept"

        let requests = SmartNotificationEngine.buildNudgeRequests(
            now: now,
            completedTodayCount: 0,
            intentionText: intention
        )

        for request in requests {
            XCTAssertLessThanOrEqual(request.content.body.count, 100,
                "Nudge-Body '\(request.content.body)' ist zu lang für Sperrbildschirm (\(request.content.body.count) Zeichen)")
        }
    }

    // MARK: - NotificationContentService

    /// Verhalten: generateNudgeContent liefert Content mit Intentions-Referenz.
    /// Bricht wenn: Methode nicht existiert.
    func test_nudgeContent_withIntention_containsReference() {
        let content = NotificationContentService.generateNudgeContent(
            intentionText: "Fokus auf Frontend-Refactoring"
        )

        XCTAssertFalse(content.title.isEmpty, "Title darf nicht leer sein")
        XCTAssertFalse(content.body.isEmpty, "Body darf nicht leer sein")
        XCTAssertTrue(
            content.body.contains("Frontend-Refactoring"),
            "Body '\(content.body)' sollte Intention referenzieren"
        )
    }

    /// Verhalten: Verschiedene Aufrufe liefern verschiedene Templates (Variation).
    /// Bricht wenn: Immer derselbe Text kommt.
    func test_nudgeContent_hasVariation() {
        let bodies = (0..<3).map { index in
            NotificationContentService.generateNudgeContent(
                intentionText: "Fokus auf Tests",
                slotIndex: index
            ).body
        }

        let unique = Set(bodies)
        XCTAssertGreaterThan(unique.count, 1,
            "Nudge-Templates sollten variieren, aber alle sind gleich: \(bodies.first ?? "")")
    }

    // MARK: - Helpers

    private func makeTime(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }
}
