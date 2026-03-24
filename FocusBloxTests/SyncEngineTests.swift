import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class SyncEngineTests: XCTestCase {

    var container: ModelContainer!
    var source: LocalTaskSource!
    var syncEngine: SyncEngine!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        source = LocalTaskSource(modelContext: container.mainContext)
        syncEngine = SyncEngine(taskSource: source, modelContext: container.mainContext)
    }

    override func tearDownWithError() throws {
        container = nil
        source = nil
        syncEngine = nil
    }

    // MARK: - Sync Tests

    func test_sync_returnsIncompleteTasks() async throws {
        let context = container.mainContext
        let task1 = LocalTask(title: "Task 1", importance: 0)
        let task2 = LocalTask(title: "Task 2", importance: 0)
        task2.isCompleted = true
        let task3 = LocalTask(title: "Task 3", importance: 0)

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let planItems = try await syncEngine.sync()

        XCTAssertEqual(planItems.count, 2)
        XCTAssertTrue(planItems.allSatisfy { !$0.isCompleted })
    }

    func test_sync_sortsByRank() async throws {
        let context = container.mainContext
        let task1 = LocalTask(title: "Third", importance: 0)
        task1.sortOrder = 2
        let task2 = LocalTask(title: "First", importance: 0)
        task2.sortOrder = 0
        let task3 = LocalTask(title: "Second", importance: 0)
        task3.sortOrder = 1

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let planItems = try await syncEngine.sync()

        XCTAssertEqual(planItems[0].title, "First")
        XCTAssertEqual(planItems[1].title, "Second")
        XCTAssertEqual(planItems[2].title, "Third")
    }

    // MARK: - updateDuration Tests

    func test_updateDuration_setsManualDuration() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", importance: 0)
        context.insert(task)
        try context.save()

        try await syncEngine.updateDuration(itemID: task.id, minutes: 30)

        XCTAssertEqual(task.estimatedDuration, 30)
    }

    func test_updateDuration_resetsToNil() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", importance: 0)
        task.estimatedDuration = 30
        context.insert(task)
        try context.save()

        try await syncEngine.updateDuration(itemID: task.id, minutes: nil)

        XCTAssertNil(task.estimatedDuration)
    }

    func test_updateDuration_withInvalidID_doesNotCrash() async throws {
        try await syncEngine.updateDuration(itemID: "invalid-id", minutes: 15)
        // No crash = success
    }

    // MARK: - updateSortOrder Tests

    // MARK: - deleteRecurringSeries Tests (Ticket 2)

    /// Deleting a single recurring instance keeps other series members
    func test_deleteSingleInstance_keepsOthers() throws {
        let context = container.mainContext
        let groupID = "series-abc"

        let task1 = LocalTask(title: "Instance 1", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let task2 = LocalTask(title: "Instance 2", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let task3 = LocalTask(title: "Instance 3", recurrencePattern: "daily", recurrenceGroupID: groupID)
        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        // Delete only task2 (single instance)
        try syncEngine.deleteTask(itemID: task2.id)

        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(remaining.count, 2, "Only one instance should be deleted")
        XCTAssertTrue(remaining.contains(where: { $0.title == "Instance 1" }))
        XCTAssertTrue(remaining.contains(where: { $0.title == "Instance 3" }))
    }

    /// Deleting entire series removes all open instances but keeps completed ones
    func test_deleteRecurringSeries_deletesAllOpen() throws {
        let context = container.mainContext
        let groupID = "series-xyz"

        let open1 = LocalTask(title: "Open 1", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let open2 = LocalTask(title: "Open 2", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let completed = LocalTask(title: "Completed", recurrencePattern: "daily", recurrenceGroupID: groupID)
        completed.isCompleted = true
        completed.completedAt = Date()

        let unrelated = LocalTask(title: "Unrelated", recurrencePattern: "daily", recurrenceGroupID: "other-group")

        context.insert(open1)
        context.insert(open2)
        context.insert(completed)
        context.insert(unrelated)
        try context.save()

        try syncEngine.deleteRecurringSeries(groupID: groupID)

        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(remaining.count, 2, "Only completed + unrelated should remain")
        XCTAssertTrue(remaining.contains(where: { $0.title == "Completed" }), "Completed instances stay")
        XCTAssertTrue(remaining.contains(where: { $0.title == "Unrelated" }), "Unrelated tasks stay")
    }

    // MARK: - updateRecurringSeries Tests (Ticket 3)

    /// Editing a single instance keeps other series members unchanged
    func test_editSingleInstance_keepsOthers() throws {
        let context = container.mainContext
        let groupID = "series-edit"

        let task1 = LocalTask(title: "Original 1", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let task2 = LocalTask(title: "Original 2", recurrencePattern: "daily", recurrenceGroupID: groupID)
        context.insert(task1)
        context.insert(task2)
        try context.save()

        // Edit only task1 (single instance)
        try syncEngine.updateTask(itemID: task1.id, title: "Edited 1", importance: nil, duration: nil, tags: [], urgency: nil, taskType: "", dueDate: nil, description: nil)

        let all = try context.fetch(FetchDescriptor<LocalTask>())
        let edited = all.first(where: { $0.title == "Edited 1" })
        let unchanged = all.first(where: { $0.title == "Original 2" })
        XCTAssertNotNil(edited, "Edited task should exist")
        XCTAssertNotNil(unchanged, "Other instance should be unchanged")
    }

    /// Editing entire series updates all open instances
    func test_editSeries_updatesAllOpen() throws {
        let context = container.mainContext
        let groupID = "series-edit-all"

        let open1 = LocalTask(title: "Old Title", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let open2 = LocalTask(title: "Old Title", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let completed = LocalTask(title: "Old Title", recurrencePattern: "daily", recurrenceGroupID: groupID)
        completed.isCompleted = true
        completed.completedAt = Date()

        context.insert(open1)
        context.insert(open2)
        context.insert(completed)
        try context.save()

        try syncEngine.updateRecurringSeries(groupID: groupID, title: "New Title", importance: 3, duration: 45, tags: ["updated"], urgency: "urgent", taskType: "deep_work", dueDate: nil, description: "Updated desc")

        let all = try context.fetch(FetchDescriptor<LocalTask>())
        let openTasks = all.filter { !$0.isCompleted }
        let completedTask = all.first(where: { $0.isCompleted })

        // All open tasks should be updated
        for task in openTasks {
            XCTAssertEqual(task.title, "New Title")
            XCTAssertEqual(task.importance, 3)
            XCTAssertEqual(task.estimatedDuration, 45)
            XCTAssertEqual(task.taskType, "deep_work")
        }

        // Completed task should be unchanged
        XCTAssertEqual(completedTask?.title, "Old Title", "Completed instance should stay unchanged")
    }

    // MARK: - updateRecurringSeries Recurrence Propagation (Feature: recurrence-editing)

    /// Series update should propagate recurrence pattern changes to all open tasks
    func test_editSeries_shouldPropagateRecurrencePattern() throws {
        let context = container.mainContext
        let groupID = "series-recurrence-propagation"

        let task1 = LocalTask(title: "Task", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let task2 = LocalTask(title: "Task", recurrencePattern: "daily", recurrenceGroupID: groupID)
        context.insert(task1)
        context.insert(task2)
        try context.save()

        // Update series recurrence to weekly with specific weekdays
        try syncEngine.updateRecurringSeries(
            groupID: groupID,
            title: nil, importance: nil, duration: nil, tags: nil,
            urgency: nil, taskType: nil, dueDate: nil, description: nil,
            recurrencePattern: "weekly", recurrenceWeekdays: [1, 3, 5]
        )

        XCTAssertEqual(task1.recurrencePattern, "weekly",
            "Series update should propagate recurrence pattern")
        XCTAssertEqual(task2.recurrencePattern, "weekly",
            "Series update should propagate recurrence pattern to all open tasks")
        XCTAssertEqual(task1.recurrenceWeekdays, [1, 3, 5],
            "Series update should propagate weekdays")
        XCTAssertEqual(task2.recurrenceWeekdays, [1, 3, 5],
            "Series update should propagate weekdays to all open tasks")
    }

    /// Series update should propagate recurrence month day to all open tasks
    func test_editSeries_shouldPropagateRecurrenceMonthDay() throws {
        let context = container.mainContext
        let groupID = "series-monthday-propagation"

        let task1 = LocalTask(title: "Monthly", recurrencePattern: "monthly", recurrenceGroupID: groupID)
        task1.recurrenceMonthDay = 15
        let task2 = LocalTask(title: "Monthly", recurrencePattern: "monthly", recurrenceGroupID: groupID)
        task2.recurrenceMonthDay = 15
        context.insert(task1)
        context.insert(task2)
        try context.save()

        // Update series to last day of month
        try syncEngine.updateRecurringSeries(
            groupID: groupID,
            title: nil, importance: nil, duration: nil, tags: nil,
            urgency: nil, taskType: nil, dueDate: nil, description: nil,
            recurrenceMonthDay: 32
        )

        XCTAssertEqual(task1.recurrenceMonthDay, 32,
            "Series update should propagate month day")
        XCTAssertEqual(task2.recurrenceMonthDay, 32,
            "Series update should propagate month day to all open tasks")
    }

    /// Recurrence changes via series update should NOT affect completed tasks
    func test_editSeries_recurrenceChange_shouldNotAffectCompleted() throws {
        let context = container.mainContext
        let groupID = "series-recurrence-completed"

        let open1 = LocalTask(title: "Task", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let completed = LocalTask(title: "Task", recurrencePattern: "daily", recurrenceGroupID: groupID)
        completed.isCompleted = true
        completed.completedAt = Date()
        context.insert(open1)
        context.insert(completed)
        try context.save()

        // Change series to weekly
        try syncEngine.updateRecurringSeries(
            groupID: groupID,
            title: nil, importance: nil, duration: nil, tags: nil,
            urgency: nil, taskType: nil, dueDate: nil, description: nil,
            recurrencePattern: "weekly", recurrenceWeekdays: [1, 5]
        )

        // Completed task should keep original recurrence
        XCTAssertEqual(completed.recurrencePattern, "daily",
            "Completed tasks should not be affected by series recurrence updates")
    }

    // MARK: - completeTask + Recurrence Tests

    /// Completing a recurring task via SyncEngine must create a new instance.
    /// Bricht wenn: SyncEngine.swift:153-154 — RecurrenceService-Aufruf entfernt/fehlt.
    func test_completeTask_recurring_createsNextInstance() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Recurring Daily", recurrencePattern: "daily")
        task.dueDate = Calendar.current.startOfDay(for: Date())
        context.insert(task)
        try context.save()

        try syncEngine.completeTask(itemID: task.id)

        let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
        let openTasks = allTasks.filter { !$0.isCompleted }

        XCTAssertTrue(task.isCompleted, "Original task should be completed")
        XCTAssertEqual(openTasks.count, 1, "A new open instance should exist after completing recurring task")
        XCTAssertEqual(openTasks.first?.recurrencePattern, "daily", "New instance should inherit recurrence pattern")
        XCTAssertEqual(openTasks.first?.title, "Recurring Daily", "New instance should inherit title")
    }

    /// Completing a NON-recurring task must NOT create a new instance.
    /// Bricht wenn: SyncEngine.swift:153 — Guard-Check entfernt.
    func test_completeTask_nonRecurring_doesNotCreateInstance() throws {
        let context = container.mainContext
        let task = LocalTask(title: "One-Off Task", recurrencePattern: "none")
        context.insert(task)
        try context.save()

        try syncEngine.completeTask(itemID: task.id)

        let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(allTasks.count, 1, "No new instance should be created for non-recurring task")
        XCTAssertTrue(allTasks.first!.isCompleted)
    }

    func test_completeTask_doesNotCrashAccessingTaskAfterSave() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Crash Test Task", recurrencePattern: "none")
        context.insert(task)
        try context.save()

        let taskID = task.id

        // completeTask must not crash when accessing task properties after save
        try syncEngine.completeTask(itemID: taskID)

        // If we get here without crash, the fix works
        let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
        let completed = allTasks.first { $0.id == taskID }
        XCTAssertNotNil(completed)
        XCTAssertTrue(completed!.isCompleted)
    }

    // MARK: - updateSortOrder Tests

    // MARK: - Schedule/Unschedule Tests (RW_3.1b)

    /// Verhalten: scheduleTask setzt scheduledDate + scheduledDuration auf dem Task
    /// Bricht wenn: SyncEngine.scheduleTask() fehlt oder task.scheduledDate = date entfernt
    func test_scheduleTask_setsDateAndDuration() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Steuererklaerung machen")
        context.insert(task)
        try context.save()

        let scheduleDate = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let beforeModified = task.modifiedAt

        try syncEngine.scheduleTask(itemID: task.id, date: scheduleDate, duration: 45)

        XCTAssertEqual(task.scheduledDate, scheduleDate, "scheduledDate muss auf die Drop-Zeit gesetzt werden")
        XCTAssertEqual(task.scheduledDuration, 45, "scheduledDuration muss auf die uebergebene Dauer gesetzt werden")
        XCTAssertTrue(task.isScheduled, "Task muss nach Scheduling isScheduled == true melden")
        XCTAssertGreaterThan(task.modifiedAt ?? .distantPast, beforeModified ?? .distantPast,
            "modifiedAt muss aktualisiert werden fuer CloudKit-Sync")
    }

    /// Verhalten: scheduleTask raeumt assignedFocusBlockID (Mutual Exclusion)
    /// Bricht wenn: task.assignedFocusBlockID = nil Zeile in scheduleTask() fehlt
    func test_scheduleTask_clearsAssignedFocusBlockID() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task mit FocusBlock")
        task.assignedFocusBlockID = "block-123"
        context.insert(task)
        try context.save()

        let scheduleDate = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        try syncEngine.scheduleTask(itemID: task.id, date: scheduleDate, duration: 30)

        XCTAssertNil(task.assignedFocusBlockID,
            "assignedFocusBlockID MUSS geraeumt werden — Mutual Exclusion: scheduled XOR focusBlock")
        XCTAssertEqual(task.scheduledDate, scheduleDate,
            "scheduledDate muss trotzdem gesetzt werden")
    }

    /// Verhalten: scheduleTask mit duration: nil laesst scheduledDuration auf nil
    /// Bricht wenn: scheduleTask() einen Default-Wert fuer nil-Duration einsetzt (z.B. 30)
    func test_scheduleTask_withNilDuration_keepsNil() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Kurze Aufgabe")
        task.estimatedDuration = 15
        context.insert(task)
        try context.save()

        let scheduleDate = Date()
        try syncEngine.scheduleTask(itemID: task.id, date: scheduleDate, duration: nil)

        XCTAssertNil(task.scheduledDuration,
            "scheduledDuration darf NICHT auf Default gesetzt werden — nil heisst: estimatedDuration verwenden")
        XCTAssertNotNil(task.scheduledDate, "scheduledDate muss trotzdem gesetzt sein")
    }

    // MARK: - unscheduleTask Tests

    /// Verhalten: unscheduleTask raeumt scheduledDate + scheduledDuration
    /// Bricht wenn: SyncEngine.unscheduleTask() fehlt oder task.scheduledDate = nil entfernt
    func test_unscheduleTask_clearsScheduleFields() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Geplanter Task")
        task.scheduledDate = Date()
        task.scheduledDuration = 60
        context.insert(task)
        try context.save()

        try syncEngine.unscheduleTask(itemID: task.id)

        XCTAssertNil(task.scheduledDate, "scheduledDate muss nach Unschedule nil sein")
        XCTAssertNil(task.scheduledDuration, "scheduledDuration muss nach Unschedule nil sein")
        XCTAssertFalse(task.isScheduled, "Task darf nach Unschedule nicht mehr als scheduled gelten")
    }

    // MARK: - Mutual Exclusion in bestehenden Methoden

    /// Verhalten: completeTask raeumt scheduledDate (zusaetzlich zu assignedFocusBlockID)
    /// Bricht wenn: task.scheduledDate = nil Zeile in completeTask() fehlt
    func test_completeTask_clearsScheduledDate() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Geplanter Task zum Abschliessen")
        task.scheduledDate = Date()
        task.scheduledDuration = 30
        context.insert(task)
        try context.save()

        try syncEngine.completeTask(itemID: task.id)

        XCTAssertTrue(task.isCompleted, "Task muss als completed markiert sein")
        XCTAssertNil(task.scheduledDate,
            "scheduledDate MUSS bei Completion geraeumt werden — sonst erscheint completed Task noch auf Timeline")
        XCTAssertNil(task.scheduledDuration,
            "scheduledDuration muss bei Completion geraeumt werden")
    }

    /// Verhalten: updateAssignedFocusBlock raeumt scheduledDate wenn focusBlockID gesetzt wird
    /// Bricht wenn: if focusBlockID != nil { task.scheduledDate = nil } in updateAssignedFocusBlock() fehlt
    func test_updateAssignedFocusBlock_clearsScheduledDate() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Scheduled Task bekommt FocusBlock")
        task.scheduledDate = Date()
        task.scheduledDuration = 45
        context.insert(task)
        try context.save()

        try syncEngine.updateAssignedFocusBlock(itemID: task.id, focusBlockID: "block-456")

        XCTAssertEqual(task.assignedFocusBlockID, "block-456",
            "FocusBlock-Zuweisung muss funktionieren")
        XCTAssertNil(task.scheduledDate,
            "scheduledDate MUSS geraeumt werden — Mutual Exclusion: scheduled XOR focusBlock")
        XCTAssertNil(task.scheduledDuration,
            "scheduledDuration muss bei FocusBlock-Zuweisung geraeumt werden")
    }

    // MARK: - updateSortOrder Tests

    func test_updateSortOrder_updatesTasksSortOrder() async throws {
        let context = container.mainContext
        let task1 = LocalTask(title: "Task 1", importance: 0)
        task1.sortOrder = 0
        let task2 = LocalTask(title: "Task 2", importance: 0)
        task2.sortOrder = 1

        context.insert(task1)
        context.insert(task2)
        try context.save()

        // Create PlanItems in reversed order
        let planItems = [
            PlanItem(localTask: task2),
            PlanItem(localTask: task1)
        ]

        try await syncEngine.updateSortOrder(for: planItems)

        XCTAssertEqual(task2.sortOrder, 0)
        XCTAssertEqual(task1.sortOrder, 1)
    }
}
