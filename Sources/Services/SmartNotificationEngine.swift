import UserNotifications
import SwiftData
#if canImport(BackgroundTasks) && !os(macOS)
import BackgroundTasks
#endif

/// Zentraler Notification-Orchestrator. Berechnet bei jedem Trigger
/// die gesamte Notification-Queue neu (Reconcile-on-Event-Strategie).
/// Nutzt intern NotificationService.build*Request-Methoden.
@MainActor
enum SmartNotificationEngine {

    // MARK: - Enums

    enum NotificationProfile: String, CaseIterable, Sendable {
        case quiet    = "quiet"
        case balanced = "balanced"
        case active   = "active"
    }

    enum ReconciliationReason: CustomStringConvertible, Sendable {
        case appForeground
        case appBackground
        case taskChanged
        case blockChanged
        case profileChanged

        var description: String {
            switch self {
            case .appForeground: return "appForeground"
            case .appBackground: return "appBackground"
            case .taskChanged: return "taskChanged"
            case .blockChanged: return "blockChanged"
            case .profileChanged: return "profileChanged"
            }
        }
    }

    // MARK: - Budget Constants (Prio 1-5, total = 64)

    static let budgetTimers: Int = 4
    static let budgetTasks: Int  = 20
    static let budgetReview: Int = 2
    static let budgetNudges: Int = 10

    // MARK: - BGAppRefreshTask

    static let bgTaskIdentifier = "com.henning.focusblox.notification-refresh"

    // MARK: - Reconcile Entry Point

    static func reconcile(
        reason: ReconciliationReason,
        container: ModelContainer,
        eventKitRepo: any EventKitRepositoryProtocol
    ) async {
        let start = Date()
        let center = UNUserNotificationCenter.current()

        center.removeAllPendingNotificationRequests()

        let requests = await buildAllRequests(
            profile: AppSettings.shared.notificationProfile,
            container: container,
            eventKitRepo: eventKitRepo
        )

        let capped = Array(requests.prefix(64))
        for request in capped {
            try? await center.add(request)
        }

        let elapsed = Date().timeIntervalSince(start) * 1000
        print("SmartNotificationEngine: reconcile(\(reason)) — \(capped.count) notifications, \(String(format: "%.1f", elapsed))ms")
    }

    // MARK: - Testable Request Builder

    static func buildAllRequests(
        profile: NotificationProfile,
        container: ModelContainer,
        eventKitRepo: any EventKitRepositoryProtocol
    ) async -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        requests += buildTimerRequests(eventKitRepo: eventKitRepo)

        if profile == .balanced || profile == .active {
            requests += buildTaskRequests(container: container)
        }

        if profile == .balanced || profile == .active {
            requests += buildReviewRequests(now: Date())
        }

        if profile == .active {
            requests += buildNudgeRequests(now: Date())
        }

        return Array(requests.prefix(64))
    }

    // MARK: - Prio 1: Timer Requests

    private static func buildTimerRequests(
        eventKitRepo: any EventKitRepositoryProtocol
    ) -> [UNNotificationRequest] {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        var blocks: [FocusBlock] = []
        blocks += (try? eventKitRepo.fetchFocusBlocks(for: today)) ?? []
        blocks += (try? eventKitRepo.fetchFocusBlocks(for: tomorrow)) ?? []

        let now = Date()
        var requests: [UNNotificationRequest] = []

        for block in blocks.prefix(2) {
            if let startReq = NotificationService.buildFocusBlockNotificationRequest(
                blockID: block.id,
                blockTitle: block.title,
                startDate: block.startDate,
                minutesBefore: 5,
                now: now
            ) {
                requests.append(startReq)
            }
            if let endReq = NotificationService.buildFocusBlockEndNotificationRequest(
                blockID: block.id,
                blockTitle: block.title,
                endDate: block.endDate,
                completedCount: block.completedTaskIDs.count,
                totalCount: block.taskIDs.count,
                now: now
            ) {
                requests.append(endReq)
            }
            if requests.count >= budgetTimers { break }
        }

        return Array(requests.prefix(budgetTimers))
    }

    // MARK: - Prio 2: Task Requests

    private static func buildTaskRequests(
        container: ModelContainer
    ) -> [UNNotificationRequest] {
        let context = ModelContext(container)
        let settings = AppSettings.shared
        guard settings.dueDateMorningReminderEnabled || settings.dueDateAdvanceReminderEnabled else {
            return []
        }

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted && !$0.isTemplate && $0.dueDate != nil },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        guard let tasks = try? context.fetch(descriptor) else { return [] }

        let now = Date()
        var requests: [UNNotificationRequest] = []

        for task in tasks {
            guard let dueDate = task.dueDate, dueDate > now else { continue }
            if settings.dueDateMorningReminderEnabled,
               let req = NotificationService.buildDueDateMorningRequest(
                   taskID: task.id,
                   title: task.title,
                   dueDate: dueDate,
                   morningHour: settings.dueDateMorningReminderHour,
                   morningMinute: settings.dueDateMorningReminderMinute,
                   now: now
               ) {
                requests.append(req)
            }
            if settings.dueDateAdvanceReminderEnabled,
               let req = NotificationService.buildDueDateAdvanceRequest(
                   taskID: task.id,
                   title: task.title,
                   dueDate: dueDate,
                   advanceMinutes: settings.dueDateAdvanceReminderMinutes,
                   now: now
               ) {
                requests.append(req)
            }
            if requests.count >= budgetTasks { break }
        }

        return Array(requests.prefix(budgetTasks))
    }

    // MARK: - Reconcile (ModelContext Overload — fuer Views ohne ModelContainer-Zugriff)

    static func reconcile(
        reason: ReconciliationReason,
        context: ModelContext,
        eventKitRepo: any EventKitRepositoryProtocol
    ) async {
        let start = Date()
        let center = UNUserNotificationCenter.current()

        center.removeAllPendingNotificationRequests()

        let requests = await buildAllRequests(
            profile: AppSettings.shared.notificationProfile,
            context: context,
            eventKitRepo: eventKitRepo
        )

        let capped = Array(requests.prefix(64))
        for request in capped {
            try? await center.add(request)
        }

        let elapsed = Date().timeIntervalSince(start) * 1000
        print("SmartNotificationEngine: reconcile(\(reason)) — \(capped.count) notifications, \(String(format: "%.1f", elapsed))ms")
    }

    static func buildAllRequests(
        profile: NotificationProfile,
        context: ModelContext,
        eventKitRepo: any EventKitRepositoryProtocol
    ) async -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        requests += buildTimerRequests(eventKitRepo: eventKitRepo)

        if profile == .balanced || profile == .active {
            requests += buildTaskRequests(context: context)
        }

        if profile == .balanced || profile == .active {
            requests += buildReviewRequests()
        }

        if profile == .active {
            requests += buildNudgeRequests()
        }

        return Array(requests.prefix(64))
    }

    // MARK: - Prio 2: Task Requests (ModelContext Overload)

    private static func buildTaskRequests(
        context: ModelContext
    ) -> [UNNotificationRequest] {
        let settings = AppSettings.shared
        guard settings.dueDateMorningReminderEnabled || settings.dueDateAdvanceReminderEnabled else {
            return []
        }

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted && !$0.isTemplate && $0.dueDate != nil },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        guard let tasks = try? context.fetch(descriptor) else { return [] }

        let now = Date()
        var requests: [UNNotificationRequest] = []

        for task in tasks {
            guard let dueDate = task.dueDate, dueDate > now else { continue }
            if settings.dueDateMorningReminderEnabled,
               let req = NotificationService.buildDueDateMorningRequest(
                   taskID: task.id,
                   title: task.title,
                   dueDate: dueDate,
                   morningHour: settings.dueDateMorningReminderHour,
                   morningMinute: settings.dueDateMorningReminderMinute,
                   now: now
               ) {
                requests.append(req)
            }
            if settings.dueDateAdvanceReminderEnabled,
               let req = NotificationService.buildDueDateAdvanceRequest(
                   taskID: task.id,
                   title: task.title,
                   dueDate: dueDate,
                   advanceMinutes: settings.dueDateAdvanceReminderMinutes,
                   now: now
               ) {
                requests.append(req)
            }
            if requests.count >= budgetTasks { break }
        }

        return Array(requests.prefix(budgetTasks))
    }

    // MARK: - Task Overdue (Laufzeit-State — nicht Teil von reconcile)

    static func scheduleTaskOverdue(
        taskID: String,
        taskTitle: String,
        durationMinutes: Int
    ) {
        NotificationService.scheduleTaskOverdueNotification(
            taskID: taskID,
            taskTitle: taskTitle,
            durationMinutes: durationMinutes
        )
    }

    static func cancelTaskOverdue(taskID: String) {
        NotificationService.cancelTaskNotification(taskID: taskID)
    }

    // MARK: - Prio 3: Review / Morning Requests

    static func buildReviewRequests(now: Date = Date()) -> [UNNotificationRequest] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        // 1. Evening Review — 20:00 heute
        if let eveningDate = cal.date(bySettingHour: 20, minute: 0, second: 0, of: today),
           eveningDate > now {
            let content = UNMutableNotificationContent()
            content.title = "Tagesreview"
            content.body = "Zeit fuer dein Tagesreview — was hast du heute geschafft?"
            content.sound = .default

            let interval = eveningDate.timeIntervalSince(now)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let dateStr = dateString(from: today)
            requests.append(UNNotificationRequest(
                identifier: "focusblox.review.\(dateStr)",
                content: content,
                trigger: trigger
            ))
        }

        // 2. Morning Nudge — 08:00 morgen
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: today),
           let morningDate = cal.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow),
           morningDate > now {
            let content = UNMutableNotificationContent()
            content.title = "Guten Morgen"
            content.body = "Dein Tag wartet — was packst du heute an?"
            content.sound = .default

            let interval = morningDate.timeIntervalSince(now)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let dateStr = dateString(from: tomorrow)
            requests.append(UNNotificationRequest(
                identifier: "focusblox.morning.\(dateStr)",
                content: content,
                trigger: trigger
            ))
        }

        return Array(requests.prefix(budgetReview))
    }

    // MARK: - Prio 4: Nudge Requests

    static func buildNudgeRequests(now: Date = Date()) -> [UNNotificationRequest] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        // Feste Arbeitszeit-Slots: 9, 11, 13, 15, 17, 19 Uhr
        let nudgeHours = [9, 11, 13, 15, 17, 19]

        let nudgeTexts: [(title: String, body: String)] = [
            ("Wie laeuft dein Tag?", "Schau mal in dein Backlog — vielleicht ist ein Quick Win dabei."),
            ("Zeit fuer den naechsten Sprint?", "Ein kurzer Focus Block kann viel bewegen."),
            ("Dein Backlog wartet", "Welchen Task koenntest du jetzt angehen?"),
            ("Kurze Pause vorbei?", "Der naechste kleine Schritt wartet auf dich."),
            ("Halbzeit!", "Guter Zeitpunkt fuer einen Focus Sprint."),
            ("Endspurt!", "Noch ein Task vor Feierabend?"),
        ]

        var requests: [UNNotificationRequest] = []

        for (index, hour) in nudgeHours.enumerated() {
            guard let fireDate = cal.date(bySettingHour: hour, minute: 0, second: 0, of: today),
                  fireDate > now else { continue }

            let text = nudgeTexts[index % nudgeTexts.count]
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = .default

            let interval = fireDate.timeIntervalSince(now)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            requests.append(UNNotificationRequest(
                identifier: "focusblox.nudge.work.\(hour)",
                content: content,
                trigger: trigger
            ))
        }

        return Array(requests.prefix(budgetNudges))
    }

    // MARK: - Helpers

    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - BGAppRefreshTask Registration (iOS only)

    #if !os(macOS)
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: bgTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                refreshTask.setTaskCompleted(success: true)
            }
        }
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        let nextHour = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        request.earliestBeginDate = nextHour
        try? BGTaskScheduler.shared.submit(request)
    }
    #endif
}
