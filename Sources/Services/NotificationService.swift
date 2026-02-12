import UserNotifications

/// Service for scheduling local push notifications
@MainActor
enum NotificationService {
    private static let taskOverdueCategory = "TASK_OVERDUE"
    private static let taskNotificationPrefix = "task-timer-"
    private static let focusBlockNotificationPrefix = "focus-block-start-"
    private static let focusBlockEndPrefix = "focus-block-end-"

    // MARK: - Permission

    /// Request notification permission
    static func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("⚠️ Notification permission error: \(error)")
            return false
        }
    }

    // MARK: - Task Timer Notifications

    /// Schedule a notification for when a task's time runs out
    /// - Parameters:
    ///   - taskID: Unique task identifier
    ///   - taskTitle: Title to show in notification
    ///   - durationMinutes: Task duration in minutes
    static func scheduleTaskOverdueNotification(
        taskID: String,
        taskTitle: String,
        durationMinutes: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = "⏰ Zeit abgelaufen"
        content.body = "Zeit für \"\(taskTitle)\" ist abgelaufen"
        content.sound = .default
        content.categoryIdentifier = taskOverdueCategory

        // Trigger after task duration
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(durationMinutes * 60),
            repeats: false
        )

        let identifier = "\(taskNotificationPrefix)\(taskID)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule notification: \(error)")
            } else {
                print("📬 Scheduled notification for task: \(taskTitle) in \(durationMinutes) min")
            }
        }
    }

    /// Cancel a scheduled task notification
    /// - Parameter taskID: The task ID to cancel notification for
    static func cancelTaskNotification(taskID: String) {
        let identifier = "\(taskNotificationPrefix)\(taskID)"
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled notification for task: \(taskID)")
    }

    // MARK: - Focus Block Start Notifications

    /// Schedule a notification before a focus block starts
    /// - Parameters:
    ///   - blockID: Calendar event ID of the focus block
    ///   - blockTitle: Title to show in notification
    ///   - startDate: When the focus block starts
    ///   - minutesBefore: How many minutes before start to notify (default: 5)
    static func scheduleFocusBlockStartNotification(
        blockID: String,
        blockTitle: String,
        startDate: Date,
        minutesBefore: Int = 5
    ) {
        guard let request = buildFocusBlockNotificationRequest(
            blockID: blockID,
            blockTitle: blockTitle,
            startDate: startDate,
            minutesBefore: minutesBefore
        ) else { return }

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule focus block notification: \(error)")
            }
        }
    }

    /// Build a notification request for a focus block start (testable)
    /// Returns nil if the block is in the past
    static func buildFocusBlockNotificationRequest(
        blockID: String,
        blockTitle: String,
        startDate: Date,
        minutesBefore: Int = 5,
        now: Date = Date()
    ) -> UNNotificationRequest? {
        let notifyDate = startDate.addingTimeInterval(-Double(minutesBefore * 60))

        // If notifyDate is in the past, notify at start instead
        let triggerDate = notifyDate > now ? notifyDate : startDate

        // If even startDate is in the past, skip
        guard triggerDate > now else { return nil }

        let timeInterval = triggerDate.timeIntervalSince(now)

        let content = UNMutableNotificationContent()
        if notifyDate <= now {
            content.title = "FocusBlox startet jetzt"
            content.body = "\(blockTitle) beginnt jetzt"
        } else {
            content.title = "FocusBlox startet gleich"
            content.body = "\(blockTitle) beginnt in \(minutesBefore) Minuten"
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )

        let identifier = "\(focusBlockNotificationPrefix)\(blockID)"
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }

    /// Cancel a scheduled focus block start notification
    /// - Parameter blockID: The block ID to cancel notification for
    static func cancelFocusBlockNotification(blockID: String) {
        let identifier = "\(focusBlockNotificationPrefix)\(blockID)"
        let endIdentifier = "\(focusBlockEndPrefix)\(blockID)"
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier, endIdentifier])
    }

    // MARK: - Focus Block End Notifications

    /// Schedule a notification when a focus block ends
    static func scheduleFocusBlockEndNotification(
        blockID: String,
        blockTitle: String,
        endDate: Date,
        completedCount: Int,
        totalCount: Int
    ) {
        guard let request = buildFocusBlockEndNotificationRequest(
            blockID: blockID,
            blockTitle: blockTitle,
            endDate: endDate,
            completedCount: completedCount,
            totalCount: totalCount
        ) else { return }

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule block end notification: \(error)")
            }
        }
    }

    /// Build a notification request for a focus block end (testable)
    static func buildFocusBlockEndNotificationRequest(
        blockID: String,
        blockTitle: String,
        endDate: Date,
        completedCount: Int,
        totalCount: Int,
        now: Date = Date()
    ) -> UNNotificationRequest? {
        let timeInterval = endDate.timeIntervalSince(now)
        guard timeInterval > 0 else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "FocusBlox beendet"
        content.body = "\(blockTitle) - \(completedCount)/\(totalCount) Tasks erledigt. Zeit fuer dein Sprint Review!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )

        let identifier = "\(focusBlockEndPrefix)\(blockID)"
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }

    // MARK: - Cancel All

    /// Cancel all task notifications
    static func cancelAllTaskNotifications() {
        let prefix = taskNotificationPrefix
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let taskNotifications = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map { $0.identifier }

            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: taskNotifications)
            print("🗑️ Cancelled \(taskNotifications.count) task notifications")
        }
    }
}
