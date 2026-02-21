import SwiftUI
import SwiftData
import AppIntents
import FocusBloxCore

// MARK: - Notification Name for Control Center Widget
extension Notification.Name {
    static let quickCaptureRequested = Notification.Name("QuickCaptureRequested")
}

@main
struct FocusBloxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showQuickCapture = false
    @State private var quickCaptureTitle = ""
    @State private var permissionRequested = false
    @State private var syncMonitor = CloudKitSyncMonitor()

    private static let appGroupID = "group.com.henning.focusblox"

    /// SyncedSettings fuer iCloud KV Store Sync zwischen Geraeten
    private let syncedSettings = SyncedSettings()

    init() {
        // Register shared state for Interactive Snippets (iOS 26)
        AppDependencyManager.shared.add(dependency: QuickCaptureState())
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalTask.self,
            TaskMetadata.self
        ])

        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

        let modelConfiguration: ModelConfiguration
        if isUITesting {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil {
            print("[CloudKit] iOS: App Group verfuegbar, CloudKit .private(iCloud.com.henning.focusblox)")
            modelConfiguration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .private("iCloud.com.henning.focusblox")
            )
        } else {
            print("[CloudKit] iOS: App Group NICHT verfuegbar, CloudKit .private(iCloud.com.henning.focusblox) ohne Group Container")
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.henning.focusblox")
            )
        }

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Seed mock data BEFORE any view loads
            // Fixes race condition: child .task fires before parent .onAppear,
            // so FocusLiveView.loadData() would find empty store if seeded in .onAppear
            if isUITesting {
                FocusBloxApp.seedUITestData(into: container.mainContext)
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// Repository based on launch mode (test vs production)
    private let eventKitRepository: any EventKitRepositoryProtocol = {
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            let mock = MockEventKitRepository()
            mock.mockCalendarAuthStatus = .fullAccess
            mock.mockReminderAuthStatus = .fullAccess

            // Add mock Focus Blocks for today
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)

            // Focus Block 1: 09:00 - 11:00 (with one assigned task)
            let block1Start = calendar.date(byAdding: .hour, value: 9, to: startOfDay)!
            let block1End = calendar.date(byAdding: .hour, value: 11, to: startOfDay)!
            let focusBlock1 = FocusBlock(
                id: "mock-block-1",
                title: "Focus Block 09:00",
                startDate: block1Start,
                endDate: block1End,
                taskIDs: ["00000000-0000-0000-0000-000000000001"],  // Matches assignedTask.id
                completedTaskIDs: []
            )

            // Focus Block 2: 14:00 - 16:00
            let block2Start = calendar.date(byAdding: .hour, value: 14, to: startOfDay)!
            let block2End = calendar.date(byAdding: .hour, value: 16, to: startOfDay)!
            let focusBlock2 = FocusBlock(
                id: "mock-block-2",
                title: "Deep Work 14:00",
                startDate: block2Start,
                endDate: block2End,
                taskIDs: [],
                completedTaskIDs: []
            )

            // Focus Block 3: ALWAYS ACTIVE (for Live Activity testing)
            // Starts 30min ago, ends in 30min
            let activeBlockStart = calendar.date(byAdding: .minute, value: -30, to: now)!
            let activeBlockEnd = calendar.date(byAdding: .minute, value: 30, to: now)!
            let activeBlock = FocusBlock(
                id: "mock-block-active",
                title: "Active Test Block",
                startDate: activeBlockStart,
                endDate: activeBlockEnd,
                taskIDs: ["00000000-0000-0000-0000-000000000001"],
                completedTaskIDs: []
            )

            mock.mockFocusBlocks = [focusBlock1, focusBlock2, activeBlock]

            // Add mock Calendar Events for timeline testing
            let meeting1Start = calendar.date(byAdding: .hour, value: 8, to: startOfDay)!
            let meeting1End = calendar.date(byAdding: .minute, value: 30, to: meeting1Start)!
            let meeting1 = CalendarEvent(
                id: "mock-event-1",
                title: "Team Meeting",
                startDate: meeting1Start,
                endDate: meeting1End,
                isAllDay: false,
                calendarColor: nil,
                notes: nil
            )

            let meeting2Start = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
            let meeting2End = calendar.date(byAdding: .minute, value: 60, to: meeting2Start)!
            let meeting2 = CalendarEvent(
                id: "mock-event-2",
                title: "Lunch Meeting",
                startDate: meeting2Start,
                endDate: meeting2End,
                isAllDay: false,
                calendarColor: nil,
                notes: nil
            )

            // Pre-categorized event for UI testing
            let workshopStart = calendar.date(byAdding: .hour, value: 16, to: startOfDay)!
            let workshopEnd = calendar.date(byAdding: .hour, value: 17, to: startOfDay)!
            let workshop = CalendarEvent(
                id: "mock-event-3",
                title: "Workshop",
                startDate: workshopStart,
                endDate: workshopEnd,
                isAllDay: false,
                calendarColor: nil,
                notes: "category:learning"
            )

            mock.mockEvents = [meeting1, meeting2, workshop]

            // Add mock Reminders for testing Reminders Sync
            // List IDs for filtering
            let arbeitListID = "mock-list-arbeit"
            let privatListID = "mock-list-privat"

            let reminder1 = ReminderData(
                id: "mock-reminder-1",
                title: "Design Review #30min",
                isCompleted: false,
                priority: 1,
                dueDate: calendar.date(byAdding: .day, value: 1, to: now),
                notes: "Review UI mockups",
                calendarIdentifier: arbeitListID  // In "Arbeit" list
            )
            let reminder2 = ReminderData(
                id: "mock-reminder-2",
                title: "Team Retro #45min",
                isCompleted: false,
                priority: 0,
                dueDate: nil,
                notes: nil,
                calendarIdentifier: arbeitListID  // In "Arbeit" list
            )
            let reminder3 = ReminderData(
                id: "mock-reminder-3",
                title: "Einkaufen gehen",
                isCompleted: false,
                priority: 0,
                dueDate: nil,
                notes: nil,
                calendarIdentifier: privatListID  // In "Privat" list
            )
            mock.mockReminders = [reminder1, reminder2, reminder3]

            // Add mock Reminder Lists for Settings UI
            let arbeitList = ReminderListInfo(id: arbeitListID, title: "Arbeit", colorHex: "#FF0000")
            let privatList = ReminderListInfo(id: privatListID, title: "Privat", colorHex: "#00FF00")
            mock.mockReminderLists = [arbeitList, privatList]

            return mock
        } else {
            return EventKitRepository()
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.eventKitRepository, eventKitRepository)
                    .environment(syncMonitor)

                // Hidden indicator for UI testing that permission was requested
                if permissionRequested {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier("PermissionRequestedOnLaunch")
                }
            }
            .onAppear {
                syncMonitor.startRemoteChangeMonitoring(container: sharedModelContainer)
                resetUserDefaultsIfNeeded()
                // Migrate reminders-sourced tasks to local (one-time, idempotent)
                // Then run existing dedup cleanup
                if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
                    RemindersImportService.migrateRemindersToLocal(in: sharedModelContainer.mainContext)
                    Self.cleanupRemindersDuplicates(in: sharedModelContainer.mainContext)
                    Self.cleanupOrphanedBlockAssignments(in: sharedModelContainer.mainContext)
                    Self.forceCloudKitFieldSync(in: sharedModelContainer.mainContext)
                    RecurrenceService.repairOrphanedRecurringSeries(in: sharedModelContainer.mainContext)
                    RecurrenceService.migrateToTemplateModel(in: sharedModelContainer.mainContext)
                }
                // Request calendar/reminders permission on app launch (Bug 8 fix)
                requestPermissionsOnLaunch()
                // Check for CC trigger (App Group flag)
                checkCCQuickCaptureTrigger()
                // Auto-open Quick Capture for UI testing
                if ProcessInfo.processInfo.arguments.contains("-QuickCaptureTest")
                    || ProcessInfo.processInfo.arguments.contains("-SimulateCCTrigger") {
                    showQuickCapture = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    syncMonitor.triggerSync()
                    checkCCQuickCaptureTrigger()
                    syncedSettings.pushToCloud()
                    rescheduleDueDateNotifications()
                }
            }
            .onOpenURL { url in
                if url.host == "create-task" {
                    quickCaptureTitle = ""
                    showQuickCapture = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickCaptureRequested)) { _ in
                showQuickCapture = true
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView(initialTitle: quickCaptureTitle)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Request calendar, reminders, and notification permissions on app launch
    /// This ensures the app appears in iOS Settings and prompts for access
    /// Skips during UI testing to avoid blocking dialogs
    private func requestPermissionsOnLaunch() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")
        Task {
            _ = try? await eventKitRepository.requestAccess()
            // Skip notification permission during UI testing to avoid blocking dialogs
            if !isUITesting {
                _ = await NotificationService.requestPermission()
            }
            await MainActor.run {
                permissionRequested = true
            }
        }
    }

    /// Batch reschedule due date notifications for all tasks with due dates.
    private func rescheduleDueDateNotifications() {
        let context = sharedModelContainer.mainContext
        do {
            let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
            let tasksWithDueDate = allTasks
                .filter { $0.dueDate != nil && !$0.isCompleted }
                .map { (id: $0.id, title: $0.title, dueDate: $0.dueDate!) }
            NotificationService.rescheduleAllDueDateNotifications(tasks: tasksWithDueDate)
        } catch {
            print("Failed to fetch tasks for due date notifications: \(error)")
        }
    }

    /// Check if Control Center triggered Quick Capture (via App Group flag)
    private func checkCCQuickCaptureTrigger() {
        guard let defaults = UserDefaults(suiteName: "group.com.henning.focusblox") else { return }
        guard defaults.bool(forKey: "quickCaptureFromCC") else { return }
        // Clear flags and show QuickCapture
        defaults.removeObject(forKey: "quickCaptureFromCC")
        quickCaptureTitle = defaults.string(forKey: "quickCaptureTitle") ?? ""
        defaults.removeObject(forKey: "quickCaptureTitle")
        showQuickCapture = true
    }

    /// Remove duplicate tasks sharing the same externalID (Bug 34 v2).
    /// Groups by externalID, keeps the most enriched task per group.
    /// Returns number of deleted tasks, or -1 on error.
    @discardableResult
    static func cleanupRemindersDuplicates(in context: ModelContext) -> Int {
        do {
            let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
            let tasksWithExternalID = allTasks.filter { $0.externalID != nil }
            guard !tasksWithExternalID.isEmpty else { return 0 }

            // Group by externalID
            var groups: [String: [LocalTask]] = [:]
            for task in tasksWithExternalID {
                let key = task.externalID!
                groups[key, default: []].append(task)
            }

            var deletedCount = 0
            for (_, tasks) in groups where tasks.count > 1 {
                // Sort by attribute score descending, then by createdAt ascending (older first)
                let sorted = tasks.sorted { a, b in
                    let scoreA = Self.attributeScore(a)
                    let scoreB = Self.attributeScore(b)
                    if scoreA != scoreB { return scoreA > scoreB }
                    return a.createdAt < b.createdAt
                }
                // Keep first (highest score / oldest), delete rest
                for task in sorted.dropFirst() {
                    context.delete(task)
                    deletedCount += 1
                }
            }

            if deletedCount > 0 {
                try context.save()
            }
            return deletedCount
        } catch {
            return -1
        }
    }

    /// Score how many enrichment attributes a task has filled.
    private static func attributeScore(_ task: LocalTask) -> Int {
        var score = 0
        if task.importance != nil { score += 1 }
        if task.urgency != nil { score += 1 }
        if task.estimatedDuration != nil { score += 1 }
        if !task.taskType.isEmpty { score += 1 }
        if !task.tags.isEmpty { score += 1 }
        return score
    }

    /// Bug 52: Clear orphaned assignedFocusBlockID on tasks that are not in Next Up and not completed.
    /// These tasks are invisible in the iOS backlog because the filter checks assignedFocusBlockID == nil.
    @discardableResult
    static func cleanupOrphanedBlockAssignments(in context: ModelContext) -> Int {
        do {
            let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
            let orphaned = allTasks.filter {
                $0.assignedFocusBlockID != nil && !$0.isNextUp && !$0.isCompleted
            }
            guard !orphaned.isEmpty else { return 0 }
            for task in orphaned {
                task.assignedFocusBlockID = nil
            }
            try context.save()
            return orphaned.count
        } catch {
            return -1
        }
    }

    /// Bug 38 V2: Force CloudKit to sync fields by touching only NON-NIL attributes.
    /// V1 touched ALL fields (including nil), which gave nil values fresh timestamps.
    /// CloudKit's last-writer-wins then preferred nil over real values from other platforms.
    /// V2 only touches fields with actual values, so real data always wins over nil.
    @discardableResult
    static func forceCloudKitFieldSync(in context: ModelContext) -> Int {
        let key = "cloudKitFieldSyncV2"
        guard !UserDefaults.standard.bool(forKey: key) else { return 0 }

        do {
            let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
            guard !allTasks.isEmpty else {
                UserDefaults.standard.set(true, forKey: key)
                return 0
            }

            var touchedFields = 0
            for task in allTasks {
                // Only touch fields with actual values - nil fields keep old timestamps
                // so real values from other platforms win CloudKit conflict resolution
                if task.importance != nil { task.importance = task.importance; touchedFields += 1 }
                if task.urgency != nil { task.urgency = task.urgency; touchedFields += 1 }
                if task.estimatedDuration != nil { task.estimatedDuration = task.estimatedDuration; touchedFields += 1 }
                if task.dueDate != nil { task.dueDate = task.dueDate; touchedFields += 1 }
                if task.taskDescription != nil { task.taskDescription = task.taskDescription; touchedFields += 1 }
                if task.recurrencePattern != nil { task.recurrencePattern = task.recurrencePattern; touchedFields += 1 }
                if task.recurrenceWeekdays != nil { task.recurrenceWeekdays = task.recurrenceWeekdays; touchedFields += 1 }
                if task.recurrenceMonthDay != nil { task.recurrenceMonthDay = task.recurrenceMonthDay; touchedFields += 1 }
                if !task.tags.isEmpty { task.tags = task.tags; touchedFields += 1 }
                if !task.taskType.isEmpty { task.taskType = task.taskType; touchedFields += 1 }
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            print("[CloudKit] V2 field sync: \(allTasks.count) tasks, \(touchedFields) non-nil fields touched")
            return allTasks.count
        } catch {
            print("[CloudKit] V2 field sync failed: \(error)")
            return -1
        }
    }

    /// Reset UserDefaults for UI test isolation
    private func resetUserDefaultsIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-ResetUserDefaults") else { return }
        UserDefaults.standard.set(false, forKey: "remindersSyncEnabled")
        UserDefaults.standard.removeObject(forKey: "visibleReminderListIDs")
        UserDefaults.standard.synchronize()
    }

    /// Seed mock data for UI testing
    /// Static so it can be called from the model container initializer (before views load)
    private static func seedUITestData(into context: ModelContext) {
        // Check if already seeded (avoid duplicates on re-render)
        let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.title == "Mock Task 1 #30min" })
        let existingTasks = (try? context.fetch(descriptor)) ?? []
        guard existingTasks.isEmpty else { return }

        // Create mock tasks with isNextUp = true (vollständig - nicht TBD)
        let task1 = LocalTask(title: "Mock Task 1 #30min", importance: 3, estimatedDuration: 30, urgency: "urgent")
        task1.isNextUp = true

        let task2 = LocalTask(title: "Mock Task 2 #15min", importance: 2, estimatedDuration: 15, urgency: "not_urgent")
        task2.isNextUp = true

        let task3 = LocalTask(title: "Mock Task 3 #45min", importance: 1, estimatedDuration: 45, urgency: "not_urgent")
        task3.isNextUp = true

        // Create a mock task that's already assigned to a Focus Block
        let assignedTask = LocalTask(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                                     title: "Assigned Task #20min",
                                     importance: 2,
                                     estimatedDuration: 20,
                                     urgency: "not_urgent")
        assignedTask.isNextUp = false  // Not in Next Up because it's assigned

        // Create backlog tasks (isNextUp = false) for testing EditTaskSheet
        let backlogTask1 = LocalTask(title: "Backlog Task 1", importance: 2, estimatedDuration: 25, urgency: "urgent")
        backlogTask1.isNextUp = false
        backlogTask1.tags = ["work", "urgent"]
        backlogTask1.taskType = "deep_work"
        backlogTask1.dueDate = Date()
        backlogTask1.taskDescription = "This is a test description"

        let backlogTask2 = LocalTask(title: "Backlog Task 2", importance: 1, estimatedDuration: 15, urgency: "not_urgent")
        backlogTask2.isNextUp = false
        backlogTask2.tags = []
        backlogTask2.taskType = "shallow_work"

        // TBD Task (missing importance, urgency, duration) - should show italic title
        // sortOrder = -1 to appear at top of backlog list
        let tbdTask = LocalTask(title: "TBD Task - Unvollständig", importance: nil, estimatedDuration: nil, urgency: nil)
        tbdTask.isNextUp = false
        tbdTask.taskType = "maintenance"
        tbdTask.sortOrder = -1  // Appear first in backlog

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        context.insert(assignedTask)
        context.insert(backlogTask1)
        context.insert(backlogTask2)
        context.insert(tbdTask)

        // Create Focus Block mock tasks with known UUIDs
        // These match the taskIDs in FocusLiveView.createMockRepository()
        let fbTask1 = LocalTask(
            uuid: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
            title: "Focus Task 1",
            importance: 3,
            estimatedDuration: 10,
            urgency: "urgent"
        )
        fbTask1.isNextUp = false

        let fbTask2 = LocalTask(
            uuid: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!,
            title: "Focus Task 2",
            importance: 2,
            estimatedDuration: 10,
            urgency: "not_urgent"
        )
        fbTask2.isNextUp = false

        let fbTask3 = LocalTask(
            uuid: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000003")!,
            title: "Focus Task 3",
            importance: 1,
            estimatedDuration: 10,
            urgency: "not_urgent"
        )
        fbTask3.isNextUp = false

        context.insert(fbTask1)
        context.insert(fbTask2)
        context.insert(fbTask3)

        // Badge-overflow task: ALL badges set to demonstrate FlowLayout wrapping
        let badgeOverflowTask = LocalTask(title: "Badge Overflow Demo", importance: 3, estimatedDuration: 120, urgency: "urgent")
        badgeOverflowTask.isNextUp = false
        badgeOverflowTask.taskType = "learning"
        badgeOverflowTask.tags = ["design", "research", "project"]
        badgeOverflowTask.dueDate = Date()
        badgeOverflowTask.recurrencePattern = "weekly"
        context.insert(badgeOverflowTask)

        // Completed task outside any FocusBlock (for Review tab testing)
        let completedOutsideBlock = LocalTask(title: "Erledigte Backlog-Aufgabe", importance: 2, estimatedDuration: 20, urgency: "not_urgent")
        completedOutsideBlock.isNextUp = false
        completedOutsideBlock.isCompleted = true
        completedOutsideBlock.completedAt = Date()
        completedOutsideBlock.taskType = "shallow_work"
        context.insert(completedOutsideBlock)

        try? context.save()
    }
}
