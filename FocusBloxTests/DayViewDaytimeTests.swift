import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests fuer DayView.scheduledTimelineItems(from:for:)
/// Testet die Filter- und Mapping-Logik fuer Daytime-Timeline.
@MainActor
final class DayViewDaytimeTests: XCTestCase {

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
        scheduledDate: Date? = nil,
        scheduledDuration: Int? = nil,
        estimatedDuration: Int? = nil
    ) -> PlanItem {
        let task = LocalTask(title: title, importance: 2, estimatedDuration: estimatedDuration, urgency: "not_urgent")
        task.scheduledDate = scheduledDate
        task.scheduledDuration = scheduledDuration
        context.insert(task)
        return PlanItem(localTask: task)
    }

    // MARK: - Filter: nur scheduled + heute

    /// Verhalten: Tasks ohne scheduledDate werden herausgefiltert
    /// Bricht wenn: der Filter $0.isScheduled entfernt wird
    func test_unscheduledTasks_areExcluded() {
        let today = Date()
        let unscheduled = makePlanItem(title: "Nicht geplant")
        let scheduled = makePlanItem(title: "Geplant", scheduledDate: today)

        let result = DayView.scheduledTimelineItems(from: [unscheduled, scheduled], for: today)

        XCTAssertEqual(result.count, 1, "Nur scheduled Tasks duerfen erscheinen")
        XCTAssertEqual(result.first?.startDate, today)
    }

    /// Verhalten: Tasks die fuer einen anderen Tag scheduled sind werden herausgefiltert
    /// Bricht wenn: der isDate(_:inSameDayAs:) Check entfernt wird
    func test_scheduledForDifferentDay_areExcluded() {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let tomorrowTask = makePlanItem(title: "Morgen", scheduledDate: tomorrow)

        let result = DayView.scheduledTimelineItems(from: [tomorrowTask], for: today)

        XCTAssertTrue(result.isEmpty, "Tasks fuer morgen duerfen nicht in heutiger Timeline erscheinen")
    }

    /// Verhalten: Tasks die fuer heute scheduled sind werden inkludiert
    /// Bricht wenn: der Filter-Ausdruck falsch ist
    func test_scheduledForToday_areIncluded() {
        let today = Date()
        let cal = Calendar.current
        let todayAt10 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        let todayAt14 = cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)!

        let task1 = makePlanItem(title: "Task A", scheduledDate: todayAt10)
        let task2 = makePlanItem(title: "Task B", scheduledDate: todayAt14)

        let result = DayView.scheduledTimelineItems(from: [task1, task2], for: today)

        XCTAssertEqual(result.count, 2, "Beide fuer heute geplanten Tasks muessen erscheinen")
    }

    // MARK: - Mapping: Duration Fallback

    /// Verhalten: scheduledDuration hat Vorrang vor estimatedDuration
    /// Bricht wenn: die Reihenfolge scheduledDuration ?? estimatedDuration vertauscht wird
    func test_durationFallback_scheduledDurationFirst() {
        let today = Date()
        let cal = Calendar.current
        let start = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!

        let task = makePlanItem(
            title: "Mit Override",
            scheduledDate: start,
            scheduledDuration: 60,
            estimatedDuration: 30
        )

        let result = DayView.scheduledTimelineItems(from: [task], for: today)
        let item = result.first!

        let expectedEnd = cal.date(byAdding: .minute, value: 60, to: start)!
        XCTAssertEqual(
            item.endDate, expectedEnd,
            "scheduledDuration (60) muss Vorrang haben, nicht estimatedDuration (30)"
        )
    }

    /// Verhalten: Wenn scheduledDuration nil → estimatedDuration wird verwendet
    /// Bricht wenn: der Fallback-Chain ?? estimatedDuration entfernt wird
    func test_durationFallback_estimatedDurationSecond() {
        let today = Date()
        let cal = Calendar.current
        let start = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!

        let task = makePlanItem(
            title: "Ohne Override",
            scheduledDate: start,
            scheduledDuration: nil,
            estimatedDuration: 45
        )

        let result = DayView.scheduledTimelineItems(from: [task], for: today)
        let item = result.first!

        let expectedEnd = cal.date(byAdding: .minute, value: 45, to: start)!
        XCTAssertEqual(
            item.endDate, expectedEnd,
            "estimatedDuration (45) muss verwendet werden wenn scheduledDuration nil"
        )
    }

    /// Verhalten: Wenn beide Durations nil → Default 30 Minuten
    /// Bricht wenn: der Default-Wert ?? 30 entfernt oder geaendert wird
    func test_durationFallback_default30Minutes() {
        let today = Date()
        let cal = Calendar.current
        let start = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!

        let task = makePlanItem(
            title: "Keine Dauer",
            scheduledDate: start,
            scheduledDuration: nil,
            estimatedDuration: nil
        )

        let result = DayView.scheduledTimelineItems(from: [task], for: today)
        let item = result.first!

        let expectedEnd = cal.date(byAdding: .minute, value: 30, to: start)!
        XCTAssertEqual(
            item.endDate, expectedEnd,
            "Default-Dauer muss 30 Minuten sein wenn beide Duration-Felder nil"
        )
    }

    // MARK: - Mapping: Korrekte Felder

    /// Verhalten: TimelineItem hat den korrekten Titel und Typ
    /// Bricht wenn: task.title nicht korrekt an TimelineItem.scheduledTask uebergeben wird
    func test_mapping_preservesTitleAndType() {
        let today = Date()
        let start = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: today)!

        let task = makePlanItem(title: "Bericht schreiben", scheduledDate: start)

        let result = DayView.scheduledTimelineItems(from: [task], for: today)
        let item = result.first!

        if case .scheduledTask(_, let title) = item.type {
            XCTAssertEqual(title, "Bericht schreiben", "Titel muss korrekt gemappt werden")
        } else {
            XCTFail("TimelineItem muss vom Typ .scheduledTask sein")
        }
    }

    /// Verhalten: Leeres Array rein → leeres Array raus
    /// Bricht wenn: die Funktion bei leerem Input crasht
    func test_emptyInput_returnsEmpty() {
        let result = DayView.scheduledTimelineItems(from: [], for: Date())
        XCTAssertTrue(result.isEmpty, "Leerer Input muss leeres Ergebnis liefern")
    }
}
