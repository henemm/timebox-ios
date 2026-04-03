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
    static let budgetReview: Int = 14
    static var budgetNudges: Int { AppSettings.shared.nudgeDailyBudget * 7 }

    // MARK: - Cached AI Content (set during reconcile, used by buildReviewRequests)

    static var cachedMorningContent: NotificationContentService.Content?
    static var cachedEveningContent: NotificationContentService.Content?

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
            await precomputeNotificationContent(container: container)
            requests += buildReviewRequests(now: Date())
        }

        if profile == .active {
            let intentionText = fetchTodayIntention(container: container)
            requests += buildNudgeRequests(now: Date(), intentionText: intentionText)
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

    // MARK: - Reconcile (ModelContext Overload — für Views ohne ModelContainer-Zugriff)

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
            await precomputeNotificationContent(context: context)
            requests += buildReviewRequests(now: Date())
        }

        if profile == .active {
            let intentionText = fetchTodayIntention(context: context)
            requests += buildNudgeRequests(now: Date(), intentionText: intentionText)
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
        let settings = AppSettings.shared
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        for dayOffset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let dateStr = dateString(from: day)

            if let eveningDate = cal.date(bySettingHour: settings.eveningReflectionHour, minute: settings.eveningReflectionMinute, second: 0, of: day),
               eveningDate > now {
                let ec = cachedEveningContent
                let content = UNMutableNotificationContent()
                content.title = ec?.title ?? "Tagesrückblick"
                content.body = ec?.body ?? "Zeit für deinen Tagesrückblick."
                content.sound = .default
                content.userInfo = ["target": "day", "phase": "evening"]
                content.categoryIdentifier = NotificationContentService.dailyCompanionCategoryID + "_EVENING"

                let interval = eveningDate.timeIntervalSince(now)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                requests.append(UNNotificationRequest(
                    identifier: "focusblox.review.\(dateStr)",
                    content: content,
                    trigger: trigger
                ))
            }

            if let morningDate = cal.date(bySettingHour: settings.morningReminderHour, minute: settings.morningReminderMinute, second: 0, of: day),
               morningDate > now {
                let mc = cachedMorningContent
                let content = UNMutableNotificationContent()
                content.title = mc?.title ?? "Dein Tag"
                content.body = mc?.body ?? "Was packst du heute an?"
                content.sound = .default
                var info: [String: Any] = ["target": "day", "phase": "morning"]
                if let taskID = mc?.suggestedTaskID { info["suggestedTaskID"] = taskID }
                content.userInfo = info
                content.categoryIdentifier = NotificationContentService.dailyCompanionCategoryID + "_MORNING"

                let interval = morningDate.timeIntervalSince(now)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                requests.append(UNNotificationRequest(
                    identifier: "focusblox.morning.\(dateStr)",
                    content: content,
                    trigger: trigger
                ))
            }
        }

        return Array(requests.prefix(budgetReview))
    }

    // MARK: - Prio 4: Nudge Requests

    static func buildNudgeRequests(now: Date = Date(), completedTodayCount: Int = 0, intentionText: String? = nil) -> [UNNotificationRequest] {
        let settings = AppSettings.shared
        let budget = max(1, min(3, settings.nudgeDailyBudget))
        let windowStart = settings.morningReminderHour + 1  // Nudges starten 1h nach Morgengruß
        let windowEnd = settings.eveningReflectionHour      // Nudges enden bei Abend-Reflexion

        // Ohne Intention: keine Nudges (User-Advocate: lieber Stille als generisch)
        guard let intention = intentionText, !intention.isEmpty else { return [] }

        if settings.nudgeSilenceOnSuccess && completedTodayCount >= budget {
            return []
        }
        guard windowStart < windowEnd else { return [] }

        let slotHours = distributeSlots(count: budget, startHour: windowStart, endHour: windowEnd)

        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        for (index, hour) in slotHours.enumerated() {
            guard let fireDate = cal.date(bySettingHour: hour, minute: 0, second: 0, of: today),
                  fireDate > now else { continue }

            let nudgeContent = NotificationContentService.generateNudgeContent(
                intentionText: intention,
                slotIndex: index
            )
            let content = UNMutableNotificationContent()
            content.title = nudgeContent.title
            content.body = nudgeContent.body
            content.sound = .default
            content.userInfo = ["target": "day", "phase": "daytime"]
            content.categoryIdentifier = NotificationContentService.dailyCompanionCategoryID + "_NUDGE"

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

    private static func distributeSlots(count: Int, startHour: Int, endHour: Int) -> [Int] {
        guard count > 0, startHour < endHour else { return [] }
        let span = endHour - startHour
        if count == 1 { return [startHour + span / 2] }
        let step = Double(span) / Double(count)
        return (0..<count).map { i in startHour + Int(Double(i) * step + step / 2) }
    }

    // MARK: - Fetch Today's Intention

    private static func fetchTodayIntention(container: ModelContainer) -> String? {
        let context = ModelContext(container)
        return fetchTodayIntention(context: context)
    }

    private static func fetchTodayIntention(context: ModelContext) -> String? {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DayIntention>(
            predicate: #Predicate { $0.date == today }
        )
        guard let intention = try? context.fetch(descriptor).first,
              !intention.text.isEmpty else { return nil }
        return intention.text
    }

    // MARK: - Precompute AI Content

    private static func precomputeNotificationContent(container: ModelContainer) async {
        let context = ModelContext(container)
        await precomputeNotificationContent(context: context)
    }

    private static func precomputeNotificationContent(context: ModelContext) async {
        // Morning: Find the most overdue task + free time estimate
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted && !$0.isTemplate },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let tasks = (try? context.fetch(descriptor)) ?? []

        if let oldestTask = tasks.first {
            let daysSince = Calendar.current.dateComponents([.day], from: oldestTask.createdAt, to: Date()).day ?? 0
            cachedMorningContent = await NotificationContentService.generateMorningContent(
                topTaskTitle: oldestTask.title,
                daysSinceCreated: daysSince,
                freeMinutes: 120,
                meetingCount: 0,
                suggestedTaskID: oldestTask.id
            )
        }

        // Evening: Find completed tasks today
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let completedDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.isCompleted && $0.completedAt != nil }
        )
        let allCompleted = (try? context.fetch(completedDescriptor)) ?? []
        let todayCompleted = allCompleted.filter { ($0.completedAt ?? .distantPast) >= startOfToday }

        if !todayCompleted.isEmpty {
            let titles = todayCompleted.map(\.title)
            let hardest = todayCompleted.max(by: { $0.rescheduleCount < $1.rescheduleCount })
            let hardestDays = hardest.map { Calendar.current.dateComponents([.day], from: $0.createdAt, to: Date()).day ?? 0 } ?? 0

            cachedEveningContent = await NotificationContentService.generateEveningContent(
                completedTaskTitles: titles,
                focusMinutes: 0,
                hardestTaskTitle: hardest?.title,
                hardestTaskDaysOpen: hardestDays
            )
        }
    }

    // MARK: - Helpers

    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - BGAppRefreshTask Registration (iOS only)

    #if !os(macOS)
    private static var bgContainer: ModelContainer?
    private static var bgEventKitRepo: (any EventKitRepositoryProtocol)?

    static func registerBackgroundTask(
        container: ModelContainer,
        eventKitRepo: any EventKitRepositoryProtocol
    ) {
        bgContainer = container
        bgEventKitRepo = eventKitRepo

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: bgTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                if let c = bgContainer, let r = bgEventKitRepo {
                    await reconcile(reason: .appBackground, container: c, eventKitRepo: r)
                }
                scheduleBackgroundRefresh()
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
