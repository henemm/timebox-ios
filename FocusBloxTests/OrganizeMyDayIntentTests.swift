import XCTest
@testable import FocusBlox

final class OrganizeMyDayIntentTests: XCTestCase {

    // MARK: - Helpers

    private func futureDate(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        var comps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    private func makeSlot(startHour: Int, endHour: Int) -> TimeSlot {
        TimeSlot(startDate: futureDate(hour: startHour), endDate: futureDate(hour: endHour))
    }

    private func makeSuggestion(title: String, score: Double, startHour: Int = 9, endHour: Int = 10) -> NextUpSuggestion {
        let task = LocalTask(
            title: title,
            importance: 2,
            estimatedDuration: 30,
            urgency: "not_urgent",
            taskType: "income"
        )
        let planItem = PlanItem(localTask: task)
        let slot = makeSlot(startHour: startHour, endHour: endHour)
        return NextUpSuggestion(id: planItem.id, planItem: planItem, slot: slot, score: score)
    }

    // MARK: - Dialog Tests

    /// Verhalten: Bei 0 freien Slots → "keine freien Zeitfenster"
    /// Bricht wenn: OrganizeMyDayIntent.buildDialog() den guard fuer slotCount==0 nicht hat
    func test_buildDialog_noSlots_returnsNoSlotsMessage() {
        let dialog = OrganizeMyDayIntent.buildDialog(slotCount: 0, suggestions: [])
        XCTAssertEqual(dialog, "Heute sind keine freien Zeitfenster verfügbar.")
    }

    /// Verhalten: Slots vorhanden aber keine passenden Tasks → "keine passenden Tasks"
    /// Bricht wenn: OrganizeMyDayIntent.buildDialog() den guard fuer suggestions.isEmpty nicht hat
    func test_buildDialog_slotsButNoSuggestions_returnsNoTasksMessage() {
        let dialog = OrganizeMyDayIntent.buildDialog(slotCount: 3, suggestions: [])
        XCTAssertEqual(dialog, "Du hast 3 freie Zeitfenster, aber keine passenden Tasks im Backlog.")
    }

    /// Verhalten: 1 Suggestion → Titel wird genannt, kein "weitere"
    /// Bricht wenn: OrganizeMyDayIntent.buildDialog() die Titel-Zusammenstellung fehlt
    func test_buildDialog_oneSuggestion_returnsSingleTitle() {
        let s1 = makeSuggestion(title: "Steuern machen", score: 80)
        let dialog = OrganizeMyDayIntent.buildDialog(slotCount: 2, suggestions: [s1])

        XCTAssertTrue(dialog.contains("Steuern machen"), "Dialog sollte den Tasknamen enthalten")
        XCTAssertTrue(dialog.contains("Ich schlage vor:"), "Dialog sollte Vorschlags-Prefix haben")
        XCTAssertFalse(dialog.contains("weitere"), "Kein 'weitere' bei nur 1 Suggestion")
    }

    /// Verhalten: 3 Suggestions → alle 3 Titel, kein "weitere"
    /// Bricht wenn: OrganizeMyDayIntent.buildDialog() prefix(3) Logik falsch
    func test_buildDialog_threeSuggestions_listsAllThree() {
        let s1 = makeSuggestion(title: "Task A", score: 90)
        let s2 = makeSuggestion(title: "Task B", score: 80)
        let s3 = makeSuggestion(title: "Task C", score: 70)
        let dialog = OrganizeMyDayIntent.buildDialog(slotCount: 4, suggestions: [s1, s2, s3])

        XCTAssertTrue(dialog.contains("Task A"))
        XCTAssertTrue(dialog.contains("Task B"))
        XCTAssertTrue(dialog.contains("Task C"))
        XCTAssertFalse(dialog.contains("weitere"))
    }

    /// Verhalten: 5 Suggestions → erste 3 Titel + "und 2 weitere"
    /// Bricht wenn: OrganizeMyDayIntent.buildDialog() die >3 Logik fehlt
    func test_buildDialog_moreThanThree_showsOverflowCount() {
        let suggestions = (1...5).map { makeSuggestion(title: "Task \($0)", score: Double(100 - $0 * 10)) }
        let dialog = OrganizeMyDayIntent.buildDialog(slotCount: 5, suggestions: suggestions)

        XCTAssertTrue(dialog.contains("Task 1"))
        XCTAssertTrue(dialog.contains("Task 2"))
        XCTAssertTrue(dialog.contains("Task 3"))
        XCTAssertFalse(dialog.contains("Task 4"), "Task 4 sollte nicht im gesprochenen Text sein")
        XCTAssertTrue(dialog.contains("und 2 weitere"))
    }

    /// Verhalten: 1 Slot → korrekte Singular-Form
    /// Bricht wenn: OrganizeMyDayIntent.buildDialog() die Slot/Slots Pluralisierung fehlt
    func test_buildDialog_singleSlot_usesSingularForm() {
        let s1 = makeSuggestion(title: "Einkaufen", score: 50)
        let dialog = OrganizeMyDayIntent.buildDialog(slotCount: 1, suggestions: [s1])

        XCTAssertTrue(dialog.contains("1 freie"), "Sollte Singular-Form verwenden")
    }

    // MARK: - Scoring Order Test

    /// Verhalten: NextUpSuggestionService liefert nach Score sortierte Ergebnisse
    /// Bricht wenn: NextUpSuggestionService.compute() die Sortierung aendert
    func test_suggestionOrder_highestScoreFirst() {
        let highPrio = LocalTask(title: "Wichtig", importance: 3, estimatedDuration: 30, urgency: "urgent", taskType: "income")
        let lowPrio = LocalTask(title: "Unwichtig", importance: 1, estimatedDuration: 30, urgency: "not_urgent", taskType: "maintenance")

        let items = [PlanItem(localTask: lowPrio), PlanItem(localTask: highPrio)]
        let slots = [makeSlot(startHour: 9, endHour: 10), makeSlot(startHour: 14, endHour: 15)]
        let profile = BehavioralProfile(
            computedAt: futureDate(hour: 0),
            categoryTimeAffinity: nil,
            avgTasksPerDay: 5.0,
            avgMinutesPerDay: 120.0,
            estimationFactor: 1.0,
            capacityByMeetingLoad: nil,
            procrastinationPatterns: nil
        )

        NextUpSuggestionService.invalidateCache()
        let suggestions = NextUpSuggestionService.compute(
            items: items,
            slots: slots,
            profile: profile,
            calendarEvents: [],
            now: futureDate(hour: 8)
        )

        XCTAssertFalse(suggestions.isEmpty, "Sollte mindestens 1 Suggestion liefern")
        if let first = suggestions.first {
            XCTAssertEqual(first.planItem.title, "Wichtig", "Hoechster Score sollte zuerst kommen")
        }
    }
}
