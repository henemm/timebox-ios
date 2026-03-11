import Foundation
import Testing
import SwiftData
@testable import FocusBloxWatch_Watch_App

/// Unit Tests for WatchNotificationDelegate — handles interactive notification actions on Watch.
/// TDD RED: These tests MUST FAIL because WatchNotificationDelegate doesn't exist yet.
///
/// Root Cause: Watch app had no notification action handler. When user tapped "NextUp"
/// in a Watch notification, watchOS found no delegate and silently ignored the action.
@MainActor
struct WatchNotificationDelegateTests {

    // MARK: - NextUp Action

    /// Verhalten: "NextUp" Action setzt task.isNextUp = true
    /// Bricht wenn: WatchNotificationDelegate.handleAction fehlt oder setzt isNextUp nicht
    @Test func nextUpAction_setsIsNextUpTrue() throws {
        let (container, context) = try makeInMemoryContainer()
        let task = LocalTask(title: "Steuererklaerung")
        context.insert(task)
        try context.save()

        let delegate = WatchNotificationDelegate(container: container)
        delegate.handleActionForTesting("ACTION_NEXT_UP", taskID: task.id)

        let fetched = try context.fetch(FetchDescriptor<LocalTask>()).first
        #expect(fetched?.isNextUp == true, "NextUp action must set isNextUp to true")
    }

    /// Verhalten: "NextUp" Action setzt nextUpSortOrder auf maxOrder + 1
    /// Bricht wenn: Sort-Order-Berechnung fehlt
    @Test func nextUpAction_calculatesNextUpSortOrder() throws {
        let (container, context) = try makeInMemoryContainer()

        // Existing NextUp task with sortOrder 5
        let existing = LocalTask(title: "Existing NextUp")
        existing.isNextUp = true
        existing.nextUpSortOrder = 5
        context.insert(existing)

        let newTask = LocalTask(title: "New NextUp Task")
        context.insert(newTask)
        try context.save()

        let delegate = WatchNotificationDelegate(container: container)
        delegate.handleActionForTesting("ACTION_NEXT_UP", taskID: newTask.id)

        let fetched = try context.fetch(
            FetchDescriptor<LocalTask>(predicate: #Predicate { $0.title == "New NextUp Task" })
        ).first
        #expect(fetched?.nextUpSortOrder == 6, "NextUp sort order must be maxOrder + 1")
    }

    /// Verhalten: "NextUp" Action setzt modifiedAt fuer CloudKit-Sync
    /// Bricht wenn: modifiedAt nicht gesetzt wird (CloudKit propagiert Aenderung nicht)
    @Test func nextUpAction_setsModifiedAt() throws {
        let (container, context) = try makeInMemoryContainer()
        let task = LocalTask(title: "Test Task")
        context.insert(task)
        try context.save()

        let before = Date()
        let delegate = WatchNotificationDelegate(container: container)
        delegate.handleActionForTesting("ACTION_NEXT_UP", taskID: task.id)

        let fetched = try context.fetch(FetchDescriptor<LocalTask>()).first
        #expect(fetched?.modifiedAt != nil, "modifiedAt must be set for CloudKit sync")
        #expect(fetched!.modifiedAt! >= before, "modifiedAt must be current timestamp")
    }

    // MARK: - Postpone Action

    /// Verhalten: "Postpone" Action verschiebt dueDate um 1 Tag
    /// Bricht wenn: WatchNotificationDelegate.handleAction fehlt Postpone-Logik
    @Test func postponeAction_advancesDueDateByOneDay() throws {
        let (container, context) = try makeInMemoryContainer()
        // Task due today at 10:00 — postpone should move to tomorrow at 10:00
        let cal = Calendar.current
        let todayAt10 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let task = LocalTask(title: "Faellige Aufgabe", dueDate: todayAt10)
        context.insert(task)
        try context.save()

        let delegate = WatchNotificationDelegate(container: container)
        delegate.handleActionForTesting("ACTION_POSTPONE_TOMORROW", taskID: task.id)

        let fetched = try context.fetch(FetchDescriptor<LocalTask>()).first
        #expect(fetched?.dueDate != nil, "Postpone must set a new dueDate")
        #expect(fetched!.dueDate! > todayAt10, "Postponed dueDate must be after original")
    }

    /// Verhalten: "Postpone" ohne dueDate aendert nichts
    /// Bricht wenn: Nil-Guard fehlt
    @Test func postponeAction_withoutDueDate_doesNothing() throws {
        let (container, context) = try makeInMemoryContainer()
        let task = LocalTask(title: "Ohne Frist")
        context.insert(task)
        try context.save()

        let delegate = WatchNotificationDelegate(container: container)
        delegate.handleActionForTesting("ACTION_POSTPONE_TOMORROW", taskID: task.id)

        let fetched = try context.fetch(FetchDescriptor<LocalTask>()).first
        #expect(fetched?.dueDate == nil, "Postpone without dueDate must not crash or set arbitrary date")
    }

    // MARK: - Complete Action

    /// Verhalten: "Complete" Action setzt isCompleted = true und completedAt
    /// Bricht wenn: Complete-Logik fehlt
    @Test func completeAction_marksTaskCompleted() throws {
        let (container, context) = try makeInMemoryContainer()
        let task = LocalTask(title: "Zu erledigen")
        task.isNextUp = true
        context.insert(task)
        try context.save()

        let delegate = WatchNotificationDelegate(container: container)
        delegate.handleActionForTesting("ACTION_COMPLETE", taskID: task.id)

        let fetched = try context.fetch(FetchDescriptor<LocalTask>()).first
        #expect(fetched?.isCompleted == true, "Complete action must set isCompleted to true")
        #expect(fetched?.completedAt != nil, "Complete action must set completedAt timestamp")
        #expect(fetched?.isNextUp == false, "Complete action must clear isNextUp")
    }

    // MARK: - Edge Cases

    /// Verhalten: Unbekannter ActionID aendert nichts am Task
    /// Bricht wenn: Default-Case fehlt oder wirft Fehler
    @Test func unknownAction_doesNotModifyTask() throws {
        let (container, context) = try makeInMemoryContainer()
        let task = LocalTask(title: "Unveraendert")
        context.insert(task)
        try context.save()

        let delegate = WatchNotificationDelegate(container: container)
        delegate.handleActionForTesting("UNKNOWN_ACTION", taskID: task.id)

        let fetched = try context.fetch(FetchDescriptor<LocalTask>()).first
        #expect(fetched?.isNextUp == false, "Unknown action must not change isNextUp")
        #expect(fetched?.isCompleted == false, "Unknown action must not change isCompleted")
    }

    /// Verhalten: Nicht-existierende taskID crasht nicht
    /// Bricht wenn: Guard-Clause fehlt
    @Test func missingTask_doesNotCrash() throws {
        let (container, _) = try makeInMemoryContainer()
        let delegate = WatchNotificationDelegate(container: container)
        // Should not crash
        delegate.handleActionForTesting("ACTION_NEXT_UP", taskID: "non-existent-id")
    }

    // MARK: - Helper

    private func makeInMemoryContainer() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LocalTask.self, TaskMetadata.self,
            configurations: config
        )
        let context = ModelContext(container)
        return (container, context)
    }
}
