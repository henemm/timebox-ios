import XCTest
@testable import FocusBlox

final class NextUpSuggestionServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Create a date on a future day at the given hour (avoids "today" edge cases)
    private func futureDate(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        var comps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    private var tomorrowDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    }

    private func makeSlot(startHour: Int, endHour: Int) -> TimeSlot {
        TimeSlot(startDate: futureDate(hour: startHour), endDate: futureDate(hour: endHour))
    }

    private func makePlanItem(
        title: String = "Test Task",
        importance: Int? = 2,
        urgency: String? = "not_urgent",
        estimatedDuration: Int? = 30,
        taskType: String = "income",
        rescheduleCount: Int = 0,
        isNextUp: Bool = false,
        isCompleted: Bool = false,
        blockerTaskID: String? = nil,
        dueDate: Date? = nil
    ) -> PlanItem {
        let task = LocalTask(
            title: title,
            importance: importance,
            estimatedDuration: estimatedDuration,
            urgency: urgency,
            taskType: taskType
        )
        task.rescheduleCount = rescheduleCount
        task.isNextUp = isNextUp
        task.isCompleted = isCompleted
        task.blockerTaskID = blockerTaskID
        task.dueDate = dueDate
        return PlanItem(localTask: task)
    }

    private func makeEvent(
        startHour: Int, endHour: Int,
        isAllDay: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString,
            title: "Meeting",
            startDate: futureDate(hour: startHour),
            endDate: futureDate(hour: endHour),
            isAllDay: isAllDay,
            calendarColor: nil,
            notes: nil
        )
    }

    private func makeProfile(
        affinity: [TaskCategory: [DayPeriod: Double]]? = nil,
        capacity: [MeetingLoad: Double]? = nil
    ) -> BehavioralProfile {
        BehavioralProfile(
            computedAt: Date(),
            categoryTimeAffinity: affinity,
            avgTasksPerDay: 5.0,
            avgMinutesPerDay: 120.0,
            estimationFactor: 1.0,
            capacityByMeetingLoad: capacity,
            procrastinationPatterns: nil
        )
    }

    // MARK: - Tests

    /// Verhalten: Bei 3 Slots und 6 Tasks wird pro Slot der beste Task vorgeschlagen.
    /// Bricht wenn: NextUpSuggestionService.compute() nicht den hoechst-gescorten Task pro Slot waehlt.
    func test_suggestions_returnsTopScoredTaskPerSlot() {
        let slots = [
            makeSlot(startHour: 9, endHour: 10),
            makeSlot(startHour: 11, endHour: 12),
            makeSlot(startHour: 14, endHour: 15),
        ]

        // 6 Tasks mit unterschiedlicher Importance → unterschiedliche priorityScores
        let tasks = [
            makePlanItem(title: "High Prio 1", importance: 3, urgency: "urgent"),
            makePlanItem(title: "High Prio 2", importance: 3, urgency: "not_urgent"),
            makePlanItem(title: "Medium 1", importance: 2, urgency: "urgent"),
            makePlanItem(title: "Medium 2", importance: 2, urgency: "not_urgent"),
            makePlanItem(title: "Low 1", importance: 1, urgency: "not_urgent"),
            makePlanItem(title: "Low 2", importance: 1, urgency: "not_urgent"),
        ]

        let profile = makeProfile()
        let result = NextUpSuggestionService.compute(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate
        )

        XCTAssertEqual(result.count, 3, "Soll genau einen Vorschlag pro Slot liefern")
        // Erster Slot bekommt hoechsten Score
        XCTAssertEqual(result[0].planItem.title, "High Prio 1",
                       "Hoechster Score soll im ersten Slot landen")
        // Jeder Task nur einmal (Dedup)
        let titles = Set(result.map(\.planItem.title))
        XCTAssertEqual(titles.count, 3, "Kein Task darf doppelt vorgeschlagen werden")
    }

    /// Verhalten: Tasks mit blockerTaskID werden nie vorgeschlagen.
    /// Bricht wenn: compute() die isBlocked/isActionable-Pruefung ueberspringt.
    func test_suggestions_excludesBlockedTasks() {
        let slots = [makeSlot(startHour: 9, endHour: 10)]
        let tasks = [
            makePlanItem(title: "Blocked", importance: 3, urgency: "urgent",
                         blockerTaskID: "some-blocker"),
            makePlanItem(title: "Free", importance: 1, urgency: "not_urgent"),
        ]
        let profile = makeProfile()

        let result = NextUpSuggestionService.compute(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].planItem.title, "Free",
                       "Nur unblockierte Tasks duerfen vorgeschlagen werden")
    }

    /// Verhalten: Tasks die nicht in den Slot passen werden ausgeschlossen.
    /// Bricht wenn: compute() den Duration-Check (estimatedDuration <= slot.durationMinutes) ueberspringt.
    func test_suggestions_excludesTasksThatDontFitSlot() {
        let slots = [makeSlot(startHour: 9, endHour: 10)] // 60 Min
        let tasks = [
            makePlanItem(title: "Too Long", estimatedDuration: 90),
            makePlanItem(title: "Fits", estimatedDuration: 45),
        ]
        let profile = makeProfile()

        let result = NextUpSuggestionService.compute(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].planItem.title, "Fits",
                       "Task mit 90 Min darf nicht in 60-Min-Slot")
    }

    /// Verhalten: Tasks die bereits isNextUp sind werden ausgeschlossen.
    /// Bricht wenn: compute() die isNextUp-Pruefung weglässt.
    func test_suggestions_excludesAlreadyNextUpTasks() {
        let slots = [makeSlot(startHour: 9, endHour: 10)]
        let tasks = [
            makePlanItem(title: "Already Staged", importance: 3, urgency: "urgent", isNextUp: true),
            makePlanItem(title: "Not Staged", importance: 1, urgency: "not_urgent"),
        ]
        let profile = makeProfile()

        let result = NextUpSuggestionService.compute(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].planItem.title, "Not Staged",
                       "Bereits in Next Up befindliche Tasks sollen nicht vorgeschlagen werden")
    }

    /// Verhalten: Ein oft verschobener Task (rescheduleCount=5) bekommt 1.5x Bonus
    /// und kann einen hoeher priorisierten Task mit count=0 ueberholen.
    /// Bricht wenn: score() den rescheduleBonus nicht anwendet.
    func test_suggestions_rescheduleBoostApplied() {
        let slots = [makeSlot(startHour: 9, endHour: 10)]
        // Niedrige Prio + hoher Reschedule vs. hohe Prio + kein Reschedule
        let neglected = makePlanItem(title: "Neglected", importance: 2, urgency: "not_urgent",
                                     rescheduleCount: 5) // Score ~20 * 1.0 * 1.5 = 30
        let fresh = makePlanItem(title: "Fresh", importance: 2, urgency: "not_urgent",
                                 rescheduleCount: 0) // Score ~20 * 1.0 * 1.0 = 20
        let profile = makeProfile()

        let neglectedScore = NextUpSuggestionService.score(
            item: neglected, slot: slots[0], profile: profile, now: tomorrowDate
        )
        let freshScore = NextUpSuggestionService.score(
            item: fresh, slot: slots[0], profile: profile, now: tomorrowDate
        )

        XCTAssertGreaterThan(neglectedScore, freshScore,
                             "Task mit rescheduleCount=5 soll hoeher scoren (1.5x Bonus)")
    }

    /// Verhalten: Task in bevorzugter Tageszeit (Affinitaet 0.9) schlaegt Task
    /// in nicht-bevorzugter Zeit (Affinitaet 0.2) bei gleicher Basis-Prioritaet.
    /// Bricht wenn: score() den timeAffinityBonus nicht aus dem Profil liest.
    func test_suggestions_timeAffinityBoostApplied() {
        // Morning Slot (9-10 Uhr)
        let slots = [makeSlot(startHour: 9, endHour: 10)]

        let preferred = makePlanItem(title: "Morning Task", importance: 2, urgency: "not_urgent",
                                     taskType: "income")
        let nonPreferred = makePlanItem(title: "Evening Task", importance: 2, urgency: "not_urgent",
                                        taskType: "maintenance")

        // income hat hohe Morning-Affinitaet, maintenance niedrige
        let profile = makeProfile(affinity: [
            .income: [.morning: 0.9, .afternoon: 0.5, .evening: 0.2],
            .essentials: [.morning: 0.2, .afternoon: 0.5, .evening: 0.8],
        ])

        let preferredScore = NextUpSuggestionService.score(
            item: preferred, slot: slots[0], profile: profile, now: tomorrowDate
        )
        let nonPreferredScore = NextUpSuggestionService.score(
            item: nonPreferred, slot: slots[0], profile: profile, now: tomorrowDate
        )

        XCTAssertGreaterThan(preferredScore, nonPreferredScore,
                             "Task mit hoher Morning-Affinitaet (0.9) soll hoeher scoren als niedrige (0.2)")
    }

    /// Verhalten: Bei hoher Meeting-Last (6 Meetings) werden max 3 Suggestions zurueckgegeben.
    /// Bricht wenn: maxSuggestionsForLoad(.high) nicht 3 zurueckgibt oder compute() das Cap ignoriert.
    func test_suggestions_capRespected_highMeetingLoad() {
        let slots = (9..<15).map { makeSlot(startHour: $0, endHour: $0 + 1) } // 6 Slots
        let tasks = (0..<6).map { i in
            makePlanItem(title: "Task \(i)", importance: 2, urgency: "not_urgent")
        }
        // 6 non-allDay Meetings = high load
        let events = (9..<15).map { h in
            makeEvent(startHour: h, endHour: h + 1)
        }
        let profile = makeProfile()

        let result = NextUpSuggestionService.compute(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: events, now: tomorrowDate
        )

        XCTAssertLessThanOrEqual(result.count, 3,
                                 "Bei 6 Meetings (high load) sollen max 3 Suggestions kommen")
    }

    /// Verhalten: Cache liefert bei zweitem Aufruf am selben Tag identische Ergebnisse.
    /// Bricht wenn: suggestions() den Cache nicht nutzt.
    func test_suggestions_cacheReturnedOnSameDay() {
        let slots = [makeSlot(startHour: 9, endHour: 10)]
        let tasks = [makePlanItem(title: "Cacheable")]
        let profile = makeProfile()

        NextUpSuggestionService.invalidateCache()

        let first = NextUpSuggestionService.suggestions(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate
        )
        let second = NextUpSuggestionService.suggestions(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate
        )

        XCTAssertEqual(first.count, second.count, "Cache soll identische Ergebnisse liefern")
        XCTAssertEqual(first.map(\.id), second.map(\.id),
                       "Gleiche IDs bei gecachtem Ergebnis")
    }

    /// Verhalten: Nach invalidateCache() wird neu berechnet.
    /// Bricht wenn: invalidateCache() den Cache nicht leert.
    func test_invalidateCache_clearsCache() {
        let slots = [makeSlot(startHour: 9, endHour: 10)]
        let tasks1 = [makePlanItem(title: "Original")]
        let tasks2 = [makePlanItem(title: "Updated")]
        let profile = makeProfile()

        NextUpSuggestionService.invalidateCache()

        let first = NextUpSuggestionService.suggestions(
            items: tasks1, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate
        )

        NextUpSuggestionService.invalidateCache()

        let second = NextUpSuggestionService.suggestions(
            items: tasks2, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate
        )

        XCTAssertNotEqual(first.map(\.planItem.title), second.map(\.planItem.title),
                          "Nach invalidateCache soll neu berechnet werden")
    }

    // MARK: - candidatesPerSlot Tests (Feature #206)

    /// Verhalten: candidatesPerSlot liefert bis zu 3 Tasks pro Slot, sortiert nach Score.
    /// Bricht wenn: Methode nicht existiert oder weniger/mehr als maxPerSlot Kandidaten liefert.
    func test_candidatesPerSlot_returnsUpToThreePerSlot() {
        let slots = [makeSlot(startHour: 9, endHour: 10)]
        let tasks = [
            makePlanItem(title: "High", importance: 3, urgency: "urgent"),
            makePlanItem(title: "Medium", importance: 2, urgency: "not_urgent"),
            makePlanItem(title: "Low", importance: 1, urgency: "not_urgent"),
            makePlanItem(title: "Lowest", importance: 1, urgency: "not_urgent"),
        ]
        let profile = makeProfile()

        let result = NextUpSuggestionService.candidatesPerSlot(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate, maxPerSlot: 3
        )

        XCTAssertEqual(result.count, 1, "Ein Slot → ein Eintrag im Dictionary")
        let candidates = result[slots[0].id] ?? []
        XCTAssertEqual(candidates.count, 3, "Max 3 Kandidaten pro Slot")
        XCTAssertEqual(candidates[0].planItem.title, "High",
                       "Hoechster Score soll zuerst kommen")
    }

    /// Verhalten: candidatesPerSlot schliesst Tasks aus die nicht in den Slot passen (Dauer).
    /// Bricht wenn: Duration-Filter nicht greift.
    func test_candidatesPerSlot_respectsDurationFilter() {
        let slots = [makeSlot(startHour: 9, endHour: 10)] // 60 Min
        let tasks = [
            makePlanItem(title: "Fits 30", estimatedDuration: 30),
            makePlanItem(title: "Fits 60", estimatedDuration: 60),
            makePlanItem(title: "Too Long 90", estimatedDuration: 90),
        ]
        let profile = makeProfile()

        let result = NextUpSuggestionService.candidatesPerSlot(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate, maxPerSlot: 3
        )

        let candidates = result[slots[0].id] ?? []
        XCTAssertEqual(candidates.count, 2, "Nur Tasks die in den Slot passen")
        let titles = candidates.map(\.planItem.title)
        XCTAssertFalse(titles.contains("Too Long 90"), "90-Min-Task darf nicht in 60-Min-Slot")
    }

    /// Verhalten: candidatesPerSlot liefert fuer mehrere Slots unabhaengige Kandidaten.
    /// Ein Task kann in mehreren Slots vorgeschlagen werden (anders als compute()).
    /// Bricht wenn: Dedup ueber Slots hinweg faelschlicherweise greift.
    func test_candidatesPerSlot_allowsSameTaskInMultipleSlots() {
        let slots = [
            makeSlot(startHour: 9, endHour: 10),
            makeSlot(startHour: 14, endHour: 15),
        ]
        let tasks = [
            makePlanItem(title: "Versatile", importance: 3, estimatedDuration: 30),
        ]
        let profile = makeProfile()

        let result = NextUpSuggestionService.candidatesPerSlot(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate, maxPerSlot: 3
        )

        let slot1Count = result[slots[0].id]?.count ?? 0
        let slot2Count = result[slots[1].id]?.count ?? 0
        XCTAssertEqual(slot1Count, 1, "Task soll im ersten Slot vorgeschlagen werden")
        XCTAssertEqual(slot2Count, 1, "Gleicher Task soll auch im zweiten Slot vorgeschlagen werden")
    }

    // MARK: - Original Tests

    /// Verhalten: Leere Ergebnisse wenn alle Tasks blockiert, erledigt oder zu lang sind.
    /// Bricht wenn: compute() trotzdem Ergebnisse zurueckgibt ohne eligible Tasks.
    func test_suggestions_emptyWhenNoEligibleTasks() {
        let slots = [makeSlot(startHour: 9, endHour: 10)]
        let tasks = [
            makePlanItem(title: "Blocked", blockerTaskID: "x"),
            makePlanItem(title: "Done", isCompleted: true),
            makePlanItem(title: "Too Long", estimatedDuration: 120),
        ]
        let profile = makeProfile()

        let result = NextUpSuggestionService.compute(
            items: tasks, slots: slots, profile: profile,
            calendarEvents: [], now: tomorrowDate
        )

        XCTAssertTrue(result.isEmpty, "Keine eligible Tasks → leeres Ergebnis")
    }
}
