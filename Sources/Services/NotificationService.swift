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

    // MARK: - Due Date Notifications

    private static let dueDateMorningPrefix = "due-date-morning-"
    private static let dueDateAdvancePrefix = "due-date-advance-"

    /// Build a morning reminder request for the due date day (testable).
    /// Returns nil if dueDate is past, morning time is after dueDate, or fire date is past.
    static func buildDueDateMorningRequest(
        taskID: String,
        title: String,
        dueDate: Date,
        morningHour: Int,
        morningMinute: Int,
        now: Date = Date()
    ) -> UNNotificationRequest? {
        guard dueDate > now else { return nil }

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: dueDate)
        comps.hour = morningHour
        comps.minute = morningMinute
        comps.second = 0
        guard let fireDate = cal.date(from: comps) else { return nil }

        // Morning time must be before dueDate and in the future
        guard fireDate < dueDate, fireDate > now else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Heute fällig"
        content.body = "\(title) — pack ihn in einen Sprint"
        content.sound = .default

        let triggerComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)

        return UNNotificationRequest(
            identifier: "\(dueDateMorningPrefix)\(taskID)",
            content: content,
            trigger: trigger
        )
    }

    /// Build an advance reminder request before the due date (testable).
    /// Returns nil if dueDate is past or fire date would be in the past.
    static func buildDueDateAdvanceRequest(
        taskID: String,
        title: String,
        dueDate: Date,
        advanceMinutes: Int,
        now: Date = Date()
    ) -> UNNotificationRequest? {
        guard dueDate > now else { return nil }

        let fireDate = dueDate.addingTimeInterval(-Double(advanceMinutes * 60))
        guard fireDate > now else { return nil }

        let timeInterval = fireDate.timeIntervalSince(now)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(title) ist in \(Self.formattedAdvanceDuration(advanceMinutes)) fällig"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)

        return UNNotificationRequest(
            identifier: "\(dueDateAdvancePrefix)\(taskID)",
            content: content,
            trigger: trigger
        )
    }

    /// Schedule both due date notifications for a task (reads settings).
    static func scheduleDueDateNotifications(taskID: String, title: String, dueDate: Date) {
        let settings = AppSettings.shared
        let center = UNUserNotificationCenter.current()

        if settings.dueDateMorningReminderEnabled {
            if let req = buildDueDateMorningRequest(
                taskID: taskID, title: title, dueDate: dueDate,
                morningHour: settings.dueDateMorningReminderHour,
                morningMinute: settings.dueDateMorningReminderMinute
            ) { center.add(req) }
        }

        if settings.dueDateAdvanceReminderEnabled {
            if let req = buildDueDateAdvanceRequest(
                taskID: taskID, title: title, dueDate: dueDate,
                advanceMinutes: settings.dueDateAdvanceReminderMinutes
            ) { center.add(req) }
        }
    }

    /// Cancel both pending due date notifications for a task.
    static func cancelDueDateNotifications(taskID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "\(dueDateMorningPrefix)\(taskID)",
            "\(dueDateAdvancePrefix)\(taskID)"
        ])
    }

    /// Batch: cancel all due date notifications and reschedule for up to 25 nearest tasks.
    static func rescheduleAllDueDateNotifications(
        tasks: [(id: String, title: String, dueDate: Date)]
    ) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier)
                .filter { $0.hasPrefix(dueDateMorningPrefix) || $0.hasPrefix(dueDateAdvancePrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)

            let now = Date()
            let sorted = tasks
                .filter { $0.dueDate > now }
                .sorted { $0.dueDate < $1.dueDate }
                .prefix(25)

            Task { @MainActor in
                for task in sorted {
                    scheduleDueDateNotifications(taskID: task.id, title: task.title, dueDate: task.dueDate)
                }
            }
        }
    }

    /// Format advance minutes as human-readable duration.
    private static func formattedAdvanceDuration(_ minutes: Int) -> String {
        switch minutes {
        case 1440: return "1 Tag"
        case 120: return "2 Stunden"
        case 60: return "1 Stunde"
        default: return "\(minutes) Min"
        }
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
