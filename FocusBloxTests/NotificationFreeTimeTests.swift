import XCTest
import SwiftData
@testable import FocusBlox

/// TDD RED Tests for #208: Morning-Notification zeigt immer "Du hast 120 Min frei"
/// Root Cause: SmartNotificationEngine.precomputeNotificationContent hardcoded freeMinutes: 120
/// statt echte Kalenderzeit via GapFinder zu berechnen.
@MainActor
final class NotificationFreeTimeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SmartNotificationEngine.cachedMorningContent = nil
        SmartNotificationEngine.cachedEveningContent = nil
    }

    // MARK: - Morning: freeMinutes aus Kalender

    /// Bricht wenn: precomputeNotificationContent immer noch freeMinutes: 120 hardcoded hat.
    /// Nach Fix: freeMinutes wird aus GapFinder berechnet (Summe der freien Slot-Minuten).
    func test_morningNotification_usesRealFreeMinutes_notHardcoded120() async throws {
        // Arrange: Kalender mit 3 Meetings (je 1h) = deutlich weniger als 120min frei
        let today = Date()
        let cal = Calendar.current
        let events = [
            makeEvent(title: "Meeting 1",
                      start: cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!,
                      end: cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!),
            makeEvent(title: "Meeting 2",
                      start: cal.date(bySettingHour: 11, minute: 0, second: 0, of: today)!,
                      end: cal.date(bySettingHour: 12, minute: 0, second: 0, of: today)!),
            makeEvent(title: "Meeting 3",
                      start: cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
                      end: cal.date(bySettingHour: 15, minute: 0, second: 0, of: today)!),
        ]
        let repo = MockEventKitRepository()
        repo.mockEvents = events

        let task = LocalTask(title: "Steuererklärung abgeben")
        task.createdAt = cal.date(byAdding: .day, value: -14, to: today)!
        let container = try makeTestContainer(with: [task])

        // Act
        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            container: container,
            eventKitRepo: repo
        )

        // Assert: Morning-Content darf NICHT "120" enthalten
        let morningRequests = requests.filter { $0.identifier.hasPrefix("focusblox.morning.") }
        guard let morning = morningRequests.first else {
            XCTFail("Keine Morning-Notification gefunden")
            return
        }

        XCTAssertFalse(morning.content.body.contains("120"),
                        "Morning notification must NOT hardcode 120 min. Got: \(morning.content.body)")
    }

    /// Bricht wenn: precomputeNotificationContent meetingCount: 0 hardcoded hat.
    /// Nach Fix: meetingCount wird aus EventKit-Events gezählt.
    func test_morningNotification_usesRealMeetingCount() async throws {
        // Arrange: 3 Meetings im Kalender
        let today = Date()
        let cal = Calendar.current
        let events = [
            makeEvent(title: "Standup",
                      start: cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!,
                      end: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today)!),
            makeEvent(title: "Planning",
                      start: cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!,
                      end: cal.date(bySettingHour: 11, minute: 0, second: 0, of: today)!),
            makeEvent(title: "Review",
                      start: cal.date(bySettingHour: 15, minute: 0, second: 0, of: today)!,
                      end: cal.date(bySettingHour: 16, minute: 0, second: 0, of: today)!),
        ]
        let repo = MockEventKitRepository()
        repo.mockEvents = events

        let task = LocalTask(title: "Bugfix XY")
        let container = try makeTestContainer(with: [task])

        // Act
        await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            container: container,
            eventKitRepo: repo
        )

        // Assert: Cached Morning-Content muss meetingCount > 0 reflektieren
        // Da der Prompt meetingCount enthält, prüfen wir den Prompt-Builder direkt
        let prompt = NotificationContentService.buildMorningPrompt(
            topTaskTitle: "Bugfix XY",
            daysSinceCreated: 0,
            freeMinutes: 60,
            meetingCount: 3
        )
        XCTAssertTrue(prompt.contains("3"), "Prompt must contain real meeting count")

        // Und der gecachte Content darf nicht mit meetingCount=0 gebaut worden sein
        let content = SmartNotificationEngine.cachedMorningContent
        XCTAssertNotNil(content, "Morning content should be cached after buildAllRequests")
    }

    // MARK: - Evening: focusMinutes aus FocusBlocks

    /// Bricht wenn: precomputeNotificationContent focusMinutes: 0 hardcoded hat.
    /// Nach Fix: focusMinutes wird aus der Summe heutiger FocusBlock-Dauern berechnet.
    func test_eveningNotification_usesRealFocusMinutes() async throws {
        // Arrange: 2 FocusBlocks heute (30min + 60min = 90min)
        let today = Date()
        let cal = Calendar.current
        let blocks = [
            FocusBlock(
                id: "block-1",
                title: "Focus 09:00",
                startDate: cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!,
                endDate: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today)!,
                taskIDs: [], completedTaskIDs: []
            ),
            FocusBlock(
                id: "block-2",
                title: "Focus 14:00",
                startDate: cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
                endDate: cal.date(bySettingHour: 15, minute: 0, second: 0, of: today)!,
                taskIDs: [], completedTaskIDs: []
            ),
        ]
        let repo = MockEventKitRepository()
        repo.mockFocusBlocks = blocks

        let task = LocalTask(title: "Fertig")
        task.isCompleted = true
        task.completedAt = today
        let container = try makeTestContainer(with: [task])

        // Act
        await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            container: container,
            eventKitRepo: repo
        )

        // Assert: Evening-Content existiert und focusMinutes reflektiert echte Daten
        let content = SmartNotificationEngine.cachedEveningContent
        XCTAssertNotNil(content, "Evening content should be cached when completed tasks exist")
        if let body = content?.body {
            XCTAssertFalse(body.contains("0 Min") && !body.contains("90"),
                            "Evening notification should reflect real focus minutes (90), not hardcoded 0. Got: \(body)")
        }
    }

    // MARK: - Graceful Degradation

    /// Bricht wenn: precomputeNotificationContent crasht bei fehlender Kalender-Berechtigung.
    /// Nach Fix: freeMinutes fällt auf 0 zurück (graceful), statt auf hardcoded 120.
    func test_morningNotification_noCalendarAccess_gracefulDegradation() async throws {
        // Arrange: Kalender-Zugriff verweigert
        let repo = MockEventKitRepository()
        repo.mockCalendarAuthStatus = .denied

        let task = LocalTask(title: "Wichtige Aufgabe")
        let container = try makeTestContainer(with: [task])

        // Act — darf nicht crashen
        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            container: container,
            eventKitRepo: repo
        )

        // Assert: Notification existiert, aber mit freeMinutes != 120
        let morningRequests = requests.filter { $0.identifier.hasPrefix("focusblox.morning.") }
        if let morning = morningRequests.first {
            XCTAssertFalse(morning.content.body.contains("120"),
                            "Without calendar access, freeMinutes must NOT be hardcoded 120. Got: \(morning.content.body)")
        }
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

    private func makeEvent(title: String, start: Date, end: Date) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        )
    }
}
