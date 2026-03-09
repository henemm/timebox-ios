import Foundation
import SwiftData
import UserNotifications

// MARK: - Notification Action Handler

/// Handles interactive notification actions (NextUp, Postpone, Complete) for due date notifications.
@MainActor
final class NotificationActionDelegate: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

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

    private func handleAction(_ actionID: String, taskID: String) {
        let context = container.mainContext
        guard let taskUUID = UUID(uuidString: taskID) else { return }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.uuid == taskUUID }
        )
        guard let task = try? context.fetch(descriptor).first else { return }

        switch actionID {
        case NotificationService.actionNextUp:
            task.isNextUp = true
            let maxOrder = (try? context.fetch(
                FetchDescriptor<LocalTask>(
                    predicate: #Predicate { $0.isNextUp && !$0.isCompleted },
                    sortBy: [SortDescriptor(\LocalTask.nextUpSortOrder, order: .reverse)]
                )
            ).first?.nextUpSortOrder) ?? 0
            task.nextUpSortOrder = maxOrder + 1

        case NotificationService.actionPostponeTomorrow:
            postponeTask(task, taskID: taskID, byDays: 1)

        case NotificationService.actionPostponeNextWeek:
            postponeTask(task, taskID: taskID, byDays: 7)

        case NotificationService.actionComplete:
            task.isCompleted = true
            task.completedAt = Date()
            task.assignedFocusBlockID = nil
            task.isNextUp = false
            NotificationService.cancelDueDateNotifications(taskID: taskID)

        default:
            break
        }

        task.modifiedAt = Date()
        try? context.save()

        #if !os(macOS)
        NotificationService.updateOverdueBadge(container: container)
        #endif
    }

    private func postponeTask(_ task: LocalTask, taskID: String, byDays days: Int) {
        if let currentDue = task.dueDate {
            let newDue = Calendar.current.date(byAdding: .day, value: days, to: currentDue)!
            task.dueDate = newDue
            NotificationService.cancelDueDateNotifications(taskID: taskID)
            NotificationService.scheduleDueDateNotifications(
                taskID: taskID, title: task.title, dueDate: newDue
            )
        }
    }

    // MARK: - Testing Support

    /// Exposes handleAction for unit tests.
    func handleActionForTesting(_ actionID: String, taskID: String) {
        handleAction(actionID, taskID: taskID)
    }
}
