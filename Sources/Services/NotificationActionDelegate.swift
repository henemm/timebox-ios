import Foundation
import SwiftData
import UserNotifications

// MARK: - Notification Action Handler

/// Handles interactive notification actions (NextUp, Postpone, Complete) for due date notifications.
@MainActor
final class NotificationActionDelegate: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    let container: ModelContainer
    let eventKitRepository: any EventKitRepositoryProtocol

    init(container: ModelContainer, eventKitRepository: any EventKitRepositoryProtocol) {
        self.container = container
        self.eventKitRepository = eventKitRepository
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
            _ = LocalTask.postpone(task, byDays: 1, context: context)

        case NotificationService.actionPostponeNextWeek:
            _ = LocalTask.postpone(task, byDays: 7, context: context)

        case NotificationService.actionComplete:
            // DEP-4b: Blocked tasks cannot be completed
            guard task.blockerTaskID == nil else { break }
            let taskSource = LocalTaskSource(modelContext: context)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: context)
            try? syncEngine.completeTask(itemID: task.id)

        default:
            break
        }

        task.modifiedAt = Date()
        try? context.save()

        Task {
            await SmartNotificationEngine.reconcile(
                reason: .taskChanged,
                container: container,
                eventKitRepo: eventKitRepository
            )
        }

        #if !os(macOS)
        NotificationService.updateOverdueBadge(container: container)
        #endif
    }

    // MARK: - Testing Support

    /// Exposes handleAction for unit tests.
    func handleActionForTesting(_ actionID: String, taskID: String) {
        handleAction(actionID, taskID: taskID)
    }
}
