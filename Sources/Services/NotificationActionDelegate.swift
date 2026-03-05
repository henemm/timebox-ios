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
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.id == taskID }
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

        case NotificationService.actionPostpone:
            if let currentDue = task.dueDate {
                let newDue = Calendar.current.date(byAdding: .day, value: 1, to: currentDue)!
                task.dueDate = newDue
                NotificationService.cancelDueDateNotifications(taskID: taskID)
                NotificationService.scheduleDueDateNotifications(
                    taskID: taskID, title: task.title, dueDate: newDue
                )
            }

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
}
