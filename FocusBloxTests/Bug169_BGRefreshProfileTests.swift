import XCTest
import SwiftData
import UserNotifications
@testable import FocusBlox

/// TDD RED Tests for Bug #169: BGAppRefreshTask Dead Code + Profil-Beschreibung unklar
/// Diese Tests MÜSSEN FEHLSCHLAGEN bis der Fix implementiert ist.
@MainActor
final class Bug169_BGRefreshProfileTests: XCTestCase {

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "notificationProfile")
        UserDefaults.standard.removeObject(forKey: "dueDateMorningReminderEnabled")
        UserDefaults.standard.removeObject(forKey: "dueDateAdvanceReminderEnabled")
    }

    // MARK: - Fix 1: buildReviewRequests plant 7 Tage im Voraus

    /// Bricht wenn: budgetReview noch 2 ist (aktuell). Muss 14 sein (7 Tage × 2 Notifications).
    /// Welche Zeile bricht diesen Test? SmartNotificationEngine.swift Zeile 43: `static let budgetReview: Int = 2`
    func test_budgetReview_is14() {
        XCTAssertEqual(SmartNotificationEngine.budgetReview, 14,
                       "budgetReview must be 14 (7 days × morning + evening)")
    }

    /// Bricht wenn: buildReviewRequests nur 2 Requests liefert (heute + morgen).
    /// Muss 14 liefern (7 Tage Morning + Evening).
    /// Welche Zeile bricht diesen Test? SmartNotificationEngine.swift Zeilen 311-354: Nur heute/morgen-Loop
    func test_buildReviewRequests_earlyMorning_returns14() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // 06:00 — alle 7 Tage Morning (08:00) + Evening (20:00) liegen in der Zukunft
        let now = cal.date(bySettingHour: 6, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)

        XCTAssertEqual(requests.count, 14,
                       "At 06:00, should plan 7 days of morning + evening = 14 requests. Got \(requests.count)")
    }

    /// Bricht wenn: buildReviewRequests keine Requests für Tag+3 liefert.
    /// Welche Zeile bricht diesen Test? SmartNotificationEngine.swift: Kein Loop über mehrere Tage
    func test_buildReviewRequests_containsDay3Identifier() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 6, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)
        let ids = requests.map(\.identifier)

        // Tag+3 sollte dabei sein
        let day3 = cal.date(byAdding: .day, value: 3, to: today)!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let day3Str = formatter.string(from: day3)

        let hasDay3Morning = ids.contains("focusblox.morning.\(day3Str)")
        let hasDay3Evening = ids.contains("focusblox.review.\(day3Str)")

        XCTAssertTrue(hasDay3Morning,
                      "Should contain morning notification for day+3 (\(day3Str)). IDs: \(ids)")
        XCTAssertTrue(hasDay3Evening,
                      "Should contain evening notification for day+3 (\(day3Str)). IDs: \(ids)")
    }

    /// Bricht wenn: buildReviewRequests um 21:00 nur 1 Request liefert (nur morgen Morning).
    /// Um 21:00: heute Morning + Evening vorbei, 6 weitere Tage komplett = 12.
    /// Welche Zeile bricht diesen Test? SmartNotificationEngine.swift: Kein Multi-Day-Loop
    func test_buildReviewRequests_lateEvening_returns12() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // 21:00 — heute Morning (08:00) und Evening (20:00) vorbei, 6 weitere Tage komplett
        let now = cal.date(bySettingHour: 21, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)

        // Erwartet: 6× Morning (morgen bis Tag+6) + 6× Evening (morgen bis Tag+6) = 12
        XCTAssertEqual(requests.count, 12,
                       "At 21:00, should have 6 mornings + 6 evenings = 12. Got \(requests.count)")
    }

    // MARK: - Fix 1: Integration mit buildAllRequests

    /// Bricht wenn: buildAllRequests mit balanced-Profil nur 2 Review-Requests hat.
    /// Soll mindestens 10 haben (7 Tage Morning + Evening minus vergangene).
    /// Welche Zeile bricht diesen Test? SmartNotificationEngine.swift Zeile 93: budgetReview cap
    func test_buildAllRequests_balanced_hasMultiDayReviews() async throws {
        UserDefaults.standard.set(false, forKey: "dueDateMorningReminderEnabled")
        UserDefaults.standard.set(false, forKey: "dueDateAdvanceReminderEnabled")

        let container = try makeTestContainer()
        let repo = makeMockRepo(blocks: [])

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced, container: container, eventKitRepo: repo
        )

        let reviewIDs = requests.filter {
            $0.identifier.hasPrefix("focusblox.review.") || $0.identifier.hasPrefix("focusblox.morning.")
        }

        XCTAssertGreaterThan(reviewIDs.count, 2,
                             "Balanced profile should have >2 review requests (multi-day). Got \(reviewIDs.count)")
    }

    // MARK: - Fix 2: BGAppRefreshTask — Strukturelle Tests

    /// Bricht wenn: bgTaskIdentifier nicht korrekt definiert ist.
    /// Dieser Test ist ein Basis-Check — sollte NICHT fehlschlagen.
    func test_bgTaskIdentifier_exists() {
        XCTAssertEqual(SmartNotificationEngine.bgTaskIdentifier,
                       "com.henning.focusblox.notification-refresh")
    }

    // MARK: - Fix 3: Gesamt-Budget bleibt <= 64 auch mit 14 Review-Slots

    /// Bricht wenn: Nach budgetReview-Erhöhung auf 14 das Gesamt-Budget > 64 wird.
    /// Budget: Timer(4) + Tasks(20) + Review(14) + Nudges(10) = 48 — passt.
    /// Welche Zeile bricht diesen Test? SmartNotificationEngine.swift: Budget-Summe
    func test_totalBudgetSum_fitsIn64() {
        let total = SmartNotificationEngine.budgetTimers
            + SmartNotificationEngine.budgetTasks
            + SmartNotificationEngine.budgetReview
            + SmartNotificationEngine.budgetNudges

        XCTAssertLessThanOrEqual(total, 64,
                                  "Sum of all budgets (\(total)) must fit within iOS 64-notification limit")
    }

    // MARK: - Helpers

    private func makeTestContainer(with tasks: [LocalTask] = []) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalTask.self, configurations: config)
        let context = container.mainContext
        for task in tasks {
            context.insert(task)
        }
        try context.save()
        return container
    }

    private func makeMockRepo(blocks: [FocusBlock]) -> MockEventKitRepository {
        let repo = MockEventKitRepository()
        repo.mockFocusBlocks = blocks
        return repo
    }
}
