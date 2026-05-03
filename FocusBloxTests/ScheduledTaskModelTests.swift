import XCTest
@testable import FocusBlox

final class ScheduledTaskModelTests: XCTestCase {

    // MARK: - LocalTask: isScheduled computed property

    /// Verhalten: Task mit gesetztem scheduledDate meldet isScheduled == true
    /// Bricht wenn: LocalTask.isScheduled computed property entfernt oder Logik falsch
    func test_localTask_isScheduled_trueWhenDateSet() {
        let task = LocalTask(title: "Steuererklärung machen")
        task.scheduledDate = Date()
        task.scheduledDuration = 60

        XCTAssertTrue(task.isScheduled, "Task mit scheduledDate sollte isScheduled == true melden")
    }

    /// Verhalten: Task ohne scheduledDate meldet isScheduled == false
    /// Bricht wenn: isScheduled nicht auf scheduledDate != nil prueft
    func test_localTask_isScheduled_falseWhenNoDate() {
        let task = LocalTask(title: "Einkaufen gehen")
        // scheduledDate bleibt nil (Default)

        XCTAssertFalse(task.isScheduled, "Task ohne scheduledDate sollte isScheduled == false melden")
    }

    /// Verhalten: scheduledDate auf nil setzen macht Task wieder unscheduled
    /// Bricht wenn: isScheduled gecached wird statt computed
    func test_localTask_unschedule_clearsScheduledState() {
        let task = LocalTask(title: "Meeting vorbereiten")
        task.scheduledDate = Date()
        task.scheduledDuration = 30

        // Unschedule
        task.scheduledDate = nil
        task.scheduledDuration = nil

        XCTAssertFalse(task.isScheduled, "Nach Entfernen von scheduledDate sollte isScheduled == false sein")
        XCTAssertNil(task.scheduledDate)
        XCTAssertNil(task.scheduledDuration)
    }

    // MARK: - PlanItem: Mirror von scheduledDate/scheduledDuration

    /// Verhalten: PlanItem uebernimmt scheduledDate + scheduledDuration aus LocalTask
    /// Bricht wenn: init(localTask:) die neuen Felder nicht kopiert
    func test_planItem_mirrorsScheduledFields_fromLocalTask() {
        let task = LocalTask(title: "Bericht schreiben")
        let scheduledTime = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        task.scheduledDate = scheduledTime
        task.scheduledDuration = 45

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.scheduledDate, scheduledTime, "PlanItem.scheduledDate muss LocalTask-Wert spiegeln")
        XCTAssertEqual(planItem.scheduledDuration, 45, "PlanItem.scheduledDuration muss LocalTask-Wert spiegeln")
        XCTAssertTrue(planItem.isScheduled, "PlanItem.isScheduled muss true sein wenn scheduledDate gesetzt")
    }

    /// Verhalten: PlanItem aus Reminder hat keine Scheduling-Felder
    /// Bricht wenn: init(reminder:) scheduledDate nicht auf nil setzt
    func test_planItem_reminder_hasNoScheduledFields() {
        let reminder = ReminderData(id: "rem-1", title: "Test Reminder", isCompleted: false, priority: 0)
        let metadata = TaskMetadata(reminderID: "rem-1", sortOrder: 0)
        let planItem = PlanItem(reminder: reminder, metadata: metadata)

        XCTAssertNil(planItem.scheduledDate, "PlanItem aus Reminder darf kein scheduledDate haben")
        XCTAssertNil(planItem.scheduledDuration, "PlanItem aus Reminder darf kein scheduledDuration haben")
        XCTAssertFalse(planItem.isScheduled, "PlanItem aus Reminder darf nicht scheduled sein")
    }

    /// Bug #306 AC-5: PlanItem aus recurring Reminder uebernimmt recurrencePattern
    /// Bricht wenn: init(reminder:) recurrencePattern hart auf nil setzt
    func test_planItem_reminder_recurringPattern_isPropagated() {
        let reminder = ReminderData(
            id: "rem-1",
            title: "Weekly task",
            recurrencePattern: "weekly"
        )
        let metadata = TaskMetadata(reminderID: "rem-1", sortOrder: 0)
        let planItem = PlanItem(reminder: reminder, metadata: metadata)

        XCTAssertEqual(
            planItem.recurrencePattern,
            "weekly",
            "PlanItem aus recurring Reminder muss recurrencePattern uebernehmen (nicht nil)"
        )
    }

    /// Bug #306 AC-6: PlanItem aus non-recurring Reminder hat recurrencePattern == nil
    /// Bricht wenn: init(reminder:) "none"-String durchreicht statt nil
    func test_planItem_reminder_nonRecurringPattern_isNil() {
        let reminder = ReminderData(id: "rem-1", title: "One-shot", recurrencePattern: "none")
        let metadata = TaskMetadata(reminderID: "rem-1", sortOrder: 0)
        let planItem = PlanItem(reminder: reminder, metadata: metadata)

        XCTAssertNil(
            planItem.recurrencePattern,
            "PlanItem aus 'none'-Reminder darf KEIN recurrencePattern haben (nil, nicht 'none')"
        )
    }

    // MARK: - TimelineItem: Scheduled Task Case

    /// Verhalten: TimelineItem aus scheduled Task berechnet Start/End korrekt
    /// Bricht wenn: init(scheduledTaskID:...) die Duration falsch addiert
    func test_timelineItem_scheduledTask_calculatesCorrectEndTime() {
        let startDate = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let item = TimelineItem(
            scheduledTaskID: "task-123",
            title: "Deep Work",
            scheduledDate: startDate,
            durationMinutes: 45
        )

        let expectedEnd = Calendar.current.date(byAdding: .minute, value: 45, to: startDate)!
        XCTAssertEqual(item.startDate, startDate, "Start muss scheduledDate sein")
        XCTAssertEqual(item.endDate, expectedEnd, "End muss scheduledDate + 45min sein")
    }

    /// Verhalten: TimelineItem ID hat "scheduled_" Prefix
    /// Bricht wenn: init(scheduledTaskID:...) den Prefix weglässt
    func test_timelineItem_scheduledTask_hasIDPrefix() {
        let item = TimelineItem(
            scheduledTaskID: "abc-def",
            title: "Test",
            scheduledDate: Date(),
            durationMinutes: 30
        )

        XCTAssertTrue(item.id.hasPrefix("scheduled_"), "ID muss mit 'scheduled_' beginnen um Kollisionen zu vermeiden")
        XCTAssertEqual(item.id, "scheduled_abc-def")
    }

    /// Verhalten: Scheduled Task wird in groupOverlapping mit Events zusammengefasst
    /// Bricht wenn: groupOverlapping den .scheduledTask case nicht verarbeitet
    func test_timelineItem_collision_groupsScheduledWithEvent() {
        let tenAM = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let tenThirty = Calendar.current.date(byAdding: .minute, value: 30, to: tenAM)!
        let eleven = Calendar.current.date(byAdding: .minute, value: 60, to: tenAM)!

        // Event von 10:00-11:00
        let event = TimelineItem(
            id: "event-1",
            startDate: tenAM,
            endDate: eleven
        )

        // Scheduled Task von 10:00-10:30 — ueberlappt mit Event
        let scheduledTask = TimelineItem(
            scheduledTaskID: "task-1",
            title: "Overlapping Task",
            scheduledDate: tenAM,
            durationMinutes: 30
        )

        let groups = TimelineItem.groupOverlapping([event, scheduledTask])

        XCTAssertEqual(groups.count, 1, "Ueberlappende Items muessen in einer Gruppe sein")
        XCTAssertEqual(groups.first?.count, 2, "Gruppe muss beide Items enthalten")
    }

    /// Verhalten: Nicht-ueberlappende Items bleiben in getrennten Gruppen
    /// Bricht wenn: groupOverlapping scheduled Tasks falsch sortiert
    func test_timelineItem_collision_separatesNonOverlapping() {
        let nineAM = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let tenAM = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!

        // Scheduled Task von 09:00-09:30
        let morning = TimelineItem(
            scheduledTaskID: "task-morning",
            title: "Morning Task",
            scheduledDate: nineAM,
            durationMinutes: 30
        )

        // Scheduled Task von 10:00-10:30 — NICHT ueberlappend
        let later = TimelineItem(
            scheduledTaskID: "task-later",
            title: "Later Task",
            scheduledDate: tenAM,
            durationMinutes: 30
        )

        let groups = TimelineItem.groupOverlapping([morning, later])

        XCTAssertEqual(groups.count, 2, "Nicht-ueberlappende Items muessen in getrennten Gruppen sein")
    }
}
