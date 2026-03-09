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
    static let actionPostpone = "ACTION_POSTPONE"
    static let actionComplete = "ACTION_COMPLETE"
    static let dueDateCategory = "DUE_DATE_INTERACTIVE"

    init(container: ModelContainer) {
        self.container = container
    }

    /// Register notification categories so watchOS can display interactive actions.
    static func registerActions() {
        let nextUp = UNNotificationAction(identifier: actionNextUp, title: "Next Up", options: [])
        let postpone = UNNotificationAction(identifier: actionPostpone, title: "Morgen", options: [])
        let complete = UNNotificationAction(identifier: actionComplete, title: "Erledigt", options: [.destructive])

        let category = UNNotificationCategory(
            identifier: dueDateCategory,
            actions: [nextUp, postpone, complete],
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
        guard let taskUUID = UUID(uuidString: taskID) else { return }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.uuid == taskUUID }
        )
        guard let task = try? context.fetch(descriptor).first else { return }

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

        case Self.actionPostpone:
            if let currentDue = task.dueDate {
                task.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDue)
            }

        case Self.actionComplete:
            task.isCompleted = true
            task.completedAt = Date()
            task.assignedFocusBlockID = nil
            task.isNextUp = false

        default:
            break
        }

        task.modifiedAt = Date()
        try? context.save()
    }

    // MARK: - Testing Support

    /// Exposes handleAction for unit tests.
    func handleActionForTesting(_ actionID: String, taskID: String) {
        handleAction(actionID, taskID: taskID)
    }
}
