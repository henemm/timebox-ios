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
            requests += buildReviewRequests()
        }

        if profile == .active {
            requests += buildNudgeRequests()
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

    // MARK: - Prio 3: Review / Morning Requests (Phase C)

    private static func buildReviewRequests() -> [UNNotificationRequest] {
        return []
    }

    // MARK: - Prio 4: Nudge Requests (Phase C)

    private static func buildNudgeRequests() -> [UNNotificationRequest] {
        return []
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
