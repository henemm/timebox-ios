import Foundation
import SwiftData
import UserNotifications

// MARK: - Watch Notification Action Handler

/// Handles interactive notification actions (NextUp, Postpone, Complete) on Apple Watch.
/// Mirrors NotificationActionDelegate from Sources/Services/ but is self-contained
/// for the Watch target (which doesn't compile Sources/).
@MainActor
final class WatchNotificationDelegate: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    let container: ModelContainer

    // Action identifiers must match iOS NotificationService constants
    static let actionNextUp = "ACTION_NEXT_UP"
    static let actionPostpone = "ACTION_POSTPONE_TOMORROW"
    static let actionPostponeTomorrow = "ACTION_POSTPONE_TOMORROW"
    static let actionPostponeNextWeek = "ACTION_POSTPONE_NEXT_WEEK"
    static let actionComplete = "ACTION_COMPLETE"
    static let dueDateCategory = "DUE_DATE_INTERACTIVE"

    init(container: ModelContainer) {
        self.container = container
    }

    /// Register notification categories so watchOS can display interactive actions.
    static func registerActions() {
        let nextUp = UNNotificationAction(identifier: actionNextUp, title: "Next Up", options: [])
        let postponeTomorrow = UNNotificationAction(identifier: actionPostponeTomorrow, title: "Morgen", options: [])
        let postponeNextWeek = UNNotificationAction(identifier: actionPostponeNextWeek, title: "Nächste Woche", options: [])
        let complete = UNNotificationAction(identifier: actionComplete, title: "Erledigt", options: [.destructive])

        let category = UNNotificationCategory(
            identifier: dueDateCategory,
            actions: [nextUp, postponeTomorrow, postponeNextWeek, complete],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let taskID = userInfo["taskID"] as? String else {
            completionHandler()
            return
        }
        let actionID = response.actionIdentifier

        Task { @MainActor in
            self.handleAction(actionID, taskID: taskID)
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Action Handling

    private func handleAction(_ actionID: String, taskID: String) {
        let context = container.mainContext
        guard let taskUUID = UUID(uuidString: taskID) else {
            print("[Watch Notification] ERROR: Invalid taskID format: \(taskID)")
            return
        }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.uuid == taskUUID }
        )
        guard let task = try? context.fetch(descriptor).first else {
            print("[Watch Notification] ERROR: Task \(taskID) not found in Watch store (CloudKit sync pending?)")
            return
        }

        switch actionID {
        case Self.actionNextUp:
            task.isNextUp = true
            let maxOrder = (try? context.fetch(
                FetchDescriptor<LocalTask>(
                    predicate: #Predicate { $0.isNextUp && !$0.isCompleted },
                    sortBy: [SortDescriptor(\LocalTask.nextUpSortOrder, order: .reverse)]
                )
            ).first?.nextUpSortOrder) ?? 0
            task.nextUpSortOrder = maxOrder + 1

        case Self.actionPostponeTomorrow:
            if let currentDue = task.dueDate {
                let today = Calendar.current.startOfDay(for: Date())
                let targetDay = Calendar.current.date(byAdding: .day, value: 1, to: today)!
                let time = Calendar.current.dateComponents([.hour, .minute, .second], from: currentDue)
                task.dueDate = Calendar.current.date(bySettingHour: time.hour ?? 0,
                                                     minute: time.minute ?? 0,
                                                     second: time.second ?? 0,
                                                     of: targetDay)
            }

        case Self.actionPostponeNextWeek:
            if let currentDue = task.dueDate {
                let today = Calendar.current.startOfDay(for: Date())
                let targetDay = Calendar.current.date(byAdding: .day, value: 7, to: today)!
                let time = Calendar.current.dateComponents([.hour, .minute, .second], from: currentDue)
                task.dueDate = Calendar.current.date(bySettingHour: time.hour ?? 0,
                                                     minute: time.minute ?? 0,
                                                     second: time.second ?? 0,
                                                     of: targetDay)
            }

        case Self.actionComplete:
            // DEP-4b: Blocked tasks cannot be completed
            guard task.blockerTaskID == nil else { break }
            task.isCompleted = true
            task.completedAt = Date()
            task.assignedFocusBlockID = nil
            task.isNextUp = false
            // DEP-4b: Free dependents when completing a blocker
            let depDescriptor = FetchDescriptor<LocalTask>(
                predicate: #Predicate { $0.blockerTaskID == taskID }
            )
            if let deps = try? context.fetch(depDescriptor) {
                for dep in deps { dep.blockerTaskID = nil }
            }

        default:
            break
        }

        task.modifiedAt = Date()
        do {
            try context.save()
            print("[Watch Notification] Action \(actionID) saved for task \(taskID)")
        } catch {
            print("[Watch Notification] ERROR: save failed for action \(actionID) on task \(taskID): \(error)")
        }
    }

    // MARK: - Testing Support

    /// Exposes handleAction for unit tests.
    func handleActionForTesting(_ actionID: String, taskID: String) {
        handleAction(actionID, taskID: taskID)
    }
}
