import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests fuer DayView Evening Mode — Segment-Mapping-Logik
/// Testet buildEveningSegments() und minutesFromMidnight() pure functions.
@MainActor
final class DayViewEveningTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, TaskMetadata.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Helper

    private func makePlanItem(
        title: String,
        completedAt: Date? = nil,
        isCompleted: Bool = false,
        scheduledDate: Date? = nil,
        scheduledDuration: Int? = nil,
        estimatedDuration: Int? = nil,
        isNextUp: Bool = false
    ) -> PlanItem {
        let task = LocalTask(title: title, importance: 2, estimatedDuration: estimatedDuration, urgency: "not_urgent")
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.scheduledDate = scheduledDate
        task.scheduledDuration = scheduledDuration
        task.isNextUp = isNextUp
        context.insert(task)
        return PlanItem(localTask: task)
    }

    private func makeCalendarEvent(
        title: String,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0
    ) -> CalendarEvent {
        let cal = Calendar.current
        let today = Date()
        let start = cal.date(bySettingHour: startHour, minute: startMinute, second: 0, of: today)!
        let end = cal.date(bySettingHour: endHour, minute: endMinute, second: 0, of: today)!
        return CalendarEvent(
            id: UUID().uuidString, title: title,
            startDate: start, endDate: end,
            isAllDay: false, calendarColor: nil, notes: nil
        )
    }

    // MARK: - buildEveningSegments: CalendarEvent → gray segment

    /// Verhalten: Ein Kalender-Event erzeugt ein .calendar Segment (grau) mit korrekten Zeiten
    /// Bricht wenn: buildEveningSegments() CalendarEvents nicht in .calendar Segmente mappt
    func test_buildSegments_calendarEvent_producesCalendarSegment() {
        let event = makeCalendarEvent(title: "Meeting", startHour: 10, endHour: 11)

        let segments = DayView.buildEveningSegments(events: [event], completed: [], unfinished: [])

        XCTAssertEqual(segments.count, 1, "Ein Event muss genau ein Segment erzeugen")
        XCTAssertEqual(segments.first?.kind, .calendar, "Event-Segment muss .calendar sein")
        XCTAssertEqual(segments.first?.startMinute, 600, "10:00 = 600 Minuten ab Mitternacht")
        XCTAssertEqual(segments.first?.endMinute, 660, "11:00 = 660 Minuten ab Mitternacht")
    }

    // MARK: - buildEveningSegments: Completed task → green segment

    /// Verhalten: Ein erledigter Task erzeugt ein .completed Segment (gruen)
    /// Bricht wenn: buildEveningSegments() completed Tasks nicht in .completed Segmente mappt
    func test_buildSegments_completedTask_producesCompletedSegment() {
        let cal = Calendar.current
        let completedAt = cal.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let task = makePlanItem(
            title: "Erledigt",
            completedAt: completedAt,
            isCompleted: true,
            estimatedDuration: 30
        )

        let segments = DayView.buildEveningSegments(events: [], completed: [task], unfinished: [])

        XCTAssertEqual(segments.count, 1, "Ein completed Task muss genau ein Segment erzeugen")
        XCTAssertEqual(segments.first?.kind, .completed, "Completed-Task-Segment muss .completed sein")
        XCTAssertEqual(segments.first?.startMinute, 840, "14:00 = 840 Minuten ab Mitternacht")
        XCTAssertEqual(segments.first?.endMinute, 870, "14:00 + 30min = 870 Minuten")
    }

    // MARK: - buildEveningSegments: Unfinished scheduled task → orange segment

    /// Verhalten: Ein unerledigter geplanter Task erzeugt ein .missed Segment (orange)
    /// Bricht wenn: buildEveningSegments() unfinished Tasks nicht in .missed Segmente mappt
    func test_buildSegments_unfinishedTask_producesMissedSegment() {
        let cal = Calendar.current
        let scheduledAt = cal.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!
        let task = makePlanItem(
            title: "Nicht geschafft",
            scheduledDate: scheduledAt,
            scheduledDuration: 45
        )

        let segments = DayView.buildEveningSegments(events: [], completed: [], unfinished: [task])

        XCTAssertEqual(segments.count, 1, "Ein unfinished Task muss genau ein Segment erzeugen")
        XCTAssertEqual(segments.first?.kind, .missed, "Unfinished-Task-Segment muss .missed sein")
        XCTAssertEqual(segments.first?.startMinute, 960, "16:00 = 960 Minuten ab Mitternacht")
        XCTAssertEqual(segments.first?.endMinute, 1005, "16:00 + 45min = 1005 Minuten")
    }

    // MARK: - buildEveningSegments: Sortierung

    /// Verhalten: Segmente werden nach startMinute sortiert, unabhaengig vom Typ
    /// Bricht wenn: buildEveningSegments() die .sorted { $0.startMinute < $1.startMinute } Zeile entfernt
    func test_buildSegments_segmentsAreSortedByStartMinute() {
        let cal = Calendar.current
        let today = Date()

        // Unfinished um 16:00 (spaeter eingefuegt, soll aber nach Event sortiert werden)
        let scheduledAt = cal.date(bySettingHour: 16, minute: 0, second: 0, of: today)!
        let unfinished = makePlanItem(title: "Spaet", scheduledDate: scheduledAt, scheduledDuration: 30)

        // Event um 09:00 (frueher im Tag)
        let event = makeCalendarEvent(title: "Frueh", startHour: 9, endHour: 10)

        // Completed um 12:00 (Mitte)
        let completedAt = cal.date(bySettingHour: 12, minute: 0, second: 0, of: today)!
        let completed = makePlanItem(title: "Mitte", completedAt: completedAt, isCompleted: true, estimatedDuration: 20)

        let segments = DayView.buildEveningSegments(events: [event], completed: [completed], unfinished: [unfinished])

        XCTAssertEqual(segments.count, 3, "Drei Segmente erwartet")
        XCTAssertEqual(segments[0].startMinute, 540, "Erstes Segment bei 09:00 (540)")
        XCTAssertEqual(segments[1].startMinute, 720, "Zweites Segment bei 12:00 (720)")
        XCTAssertEqual(segments[2].startMinute, 960, "Drittes Segment bei 16:00 (960)")
    }

    // MARK: - buildEveningSegments: Leerer Input

    /// Verhalten: Ohne Input werden keine Segmente erzeugt
    /// Bricht wenn: buildEveningSegments() bei leerem Input Dummy-Segmente erzeugt
    func test_buildSegments_emptyInputs_returnsEmpty() {
        let segments = DayView.buildEveningSegments(events: [], completed: [], unfinished: [])
        XCTAssertTrue(segments.isEmpty, "Leerer Input muss leeres Array liefern")
    }

    // MARK: - buildEveningSegments: Duration Fallback

    /// Verhalten: Completed Task ohne completedAt wird uebersprungen (kein Segment)
    /// Bricht wenn: buildEveningSegments() guard let completedAt entfernt wird
    func test_buildSegments_completedWithoutDate_isSkipped() {
        let task = makePlanItem(title: "Ohne Datum", isCompleted: true, estimatedDuration: 30)

        let segments = DayView.buildEveningSegments(events: [], completed: [task], unfinished: [])

        XCTAssertTrue(segments.isEmpty, "Task ohne completedAt darf kein Segment erzeugen")
    }

    /// Verhalten: Unfinished Task ohne scheduledDate wird uebersprungen (kein Segment)
    /// Bricht wenn: buildEveningSegments() guard let scheduledDate entfernt wird
    func test_buildSegments_unfinishedWithoutScheduledDate_isSkipped() {
        let task = makePlanItem(title: "Nur NextUp", isNextUp: true)

        let segments = DayView.buildEveningSegments(events: [], completed: [], unfinished: [task])

        XCTAssertTrue(segments.isEmpty, "Task ohne scheduledDate darf kein Segment in der Timeline erzeugen")
    }
}
