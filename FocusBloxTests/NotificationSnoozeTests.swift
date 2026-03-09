import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import FocusBlox

/// Bug 85-B: Notification Snooze Options — Tests for new postpone actions.
/// Tests MUST FAIL before implementation (TDD RED).
@MainActor
struct NotificationSnoozeTests {

    // MARK: - New Action Constants Must Exist

    @Test func actionPostpone_renamedToTomorrow() {
        // The old ACTION_POSTPONE must be renamed to ACTION_POSTPONE_TOMORROW
        let currentValue = NotificationService.actionPostpone
        #expect(currentValue == "ACTION_POSTPONE_TOMORROW",
                "Bug 85-B: actionPostpone must be renamed to ACTION_POSTPONE_TOMORROW (currently: \(currentValue))")
    }

    @Test func actionPostponeNextWeek_constantValue() {
        // ACTION_POSTPONE_NEXT_WEEK must be the correct string value
        let value = NotificationService.actionPostponeNextWeek
        #expect(value == "ACTION_POSTPONE_NEXT_WEEK",
                "Bug 85-B: actionPostponeNextWeek must equal ACTION_POSTPONE_NEXT_WEEK")
    }

    // MARK: - Postpone +7 Days Handler

    @Test func postponeNextWeek_advancesDueDateBySevenDays() throws {
        let (container, context) = try makeInMemoryContainer()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = LocalTask(title: "Test Task", dueDate: tomorrow)
        context.insert(task)
        try context.save()

        // ACTION_POSTPONE_NEXT_WEEK hits default case currently → dueDate unchanged
        let delegate = NotificationActionDelegate(container: container)
        delegate.handleActionForTesting("ACTION_POSTPONE_NEXT_WEEK", taskID: task.id)

        let fetched = try context.fetch(FetchDescriptor<LocalTask>()).first
        let expected = Calendar.current.date(byAdding: .day, value: 7, to: tomorrow)!
        let diff = abs(fetched!.dueDate!.timeIntervalSince(expected))
        #expect(diff < 1.0, "Bug 85-B: ACTION_POSTPONE_NEXT_WEEK must advance dueDate by 7 days")
    }

    @Test func postponeNextWeek_withoutDueDate_doesNotCrash() throws {
        let (container, context) = try makeInMemoryContainer()
        let task = LocalTask(title: "No Due Date")
        context.insert(task)
        try context.save()

        let delegate = NotificationActionDelegate(container: container)
        delegate.handleActionForTesting("ACTION_POSTPONE_NEXT_WEEK", taskID: task.id)

        let fetched = try context.fetch(FetchDescriptor<LocalTask>()).first
        #expect(fetched?.dueDate == nil, "Postpone without dueDate must not set arbitrary date")
    }

    @Test func postponeTomorrow_newActionID_advancesByOneDay() throws {
        let (container, context) = try makeInMemoryContainer()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = LocalTask(title: "Test Task", dueDate: tomorrow)
        context.insert(task)
        try context.save()

        // ACTION_POSTPONE_TOMORROW currently hits default case → dueDate unchanged
        let delegate = NotificationActionDelegate(container: container)
        delegate.handleActionForTesting("ACTION_POSTPONE_TOMORROW", taskID: task.id)

        let fetched = try context.fetch(FetchDescriptor<LocalTask>()).first
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: tomorrow)!
        let diff = abs(fetched!.dueDate!.timeIntervalSince(expected))
        #expect(diff < 1.0, "Bug 85-B: ACTION_POSTPONE_TOMORROW must advance dueDate by 1 day")
    }

    // MARK: - Helper

    private func makeInMemoryContainer() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LocalTask.self, TaskMetadata.self,
            configurations: config
        )
        // Use mainContext so handler's container.mainContext sees the same data
        let context = container.mainContext
        return (container, context)
    }
}
