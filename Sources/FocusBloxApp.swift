import SwiftUI
import SwiftData
import FocusBloxCore

// MARK: - Notification Name for Control Center Widget
extension Notification.Name {
    static let quickCaptureRequested = Notification.Name("QuickCaptureRequested")
}

@main
struct FocusBloxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showQuickCapture = false
    @State private var permissionRequested = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalTask.self,
            TaskMetadata.self
        ])

        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

        do {
            let container: ModelContainer

            if isUITesting {
                // UI tests use in-memory storage for isolation
                let inMemoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                container = try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } else {
                // Production: Migrate from default to App Group, then use App Group
                try AppGroupMigration.migrateIfNeeded()
                container = try SharedModelContainer.create()

                // Fix: Deduplicate tasks that may have been duplicated during migration
                FocusBloxApp.deduplicateTasksIfNeeded(in: container.mainContext)
            }

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

                // Hidden indicator for UI testing that permission was requested
                if permissionRequested {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier("PermissionRequestedOnLaunch")
                }
            }
            .onAppear {
                resetUserDefaultsIfNeeded()
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
                    checkCCQuickCaptureTrigger()
                }
            }
            .onOpenURL { url in
                if url.host == "create-task" {
                    showQuickCapture = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickCaptureRequested)) { _ in
                showQuickCapture = true
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView()
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

    /// Check if Control Center triggered Quick Capture (via App Group flag)
    private func checkCCQuickCaptureTrigger() {
        guard let defaults = UserDefaults(suiteName: "group.com.henning.focusblox") else { return }
        guard defaults.bool(forKey: "quickCaptureFromCC") else { return }
        // Clear flag and show QuickCapture
        defaults.removeObject(forKey: "quickCaptureFromCC")
        showQuickCapture = true
    }

    /// Reset UserDefaults for UI test isolation
    private func resetUserDefaultsIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-ResetUserDefaults") else { return }
        UserDefaults.standard.set(false, forKey: "remindersSyncEnabled")
        UserDefaults.standard.removeObject(forKey: "visibleReminderListIDs")
        UserDefaults.standard.synchronize()
    }

    /// Deduplicate tasks that may have been duplicated during migration
    /// This fixes the "ForEach: the ID occurs multiple times" issue
    /// Only runs once per device (uses UserDefaults flag)
    private static func deduplicateTasksIfNeeded(in context: ModelContext) {
        let deduplicationKey = "tasksDeduplicatedV1"

        // Only run once
        guard !UserDefaults.standard.bool(forKey: deduplicationKey) else { return }

        do {
            // Fetch all tasks
            let descriptor = FetchDescriptor<LocalTask>()
            let allTasks = try context.fetch(descriptor)

            // Group by UUID
            var tasksByUUID: [UUID: [LocalTask]] = [:]
            for task in allTasks {
                tasksByUUID[task.uuid, default: []].append(task)
            }

            // Find duplicates and delete older ones
            var deletedCount = 0
            for (_, tasks) in tasksByUUID where tasks.count > 1 {
                // Sort by createdAt descending (newest first)
                let sorted = tasks.sorted { $0.createdAt > $1.createdAt }

                // Keep the newest, delete the rest
                for task in sorted.dropFirst() {
                    context.delete(task)
                    deletedCount += 1
                }
            }

            if deletedCount > 0 {
                try context.save()
                print("FocusBloxApp: Deduplicated \(deletedCount) duplicate tasks")
            }

            // Mark as done
            UserDefaults.standard.set(true, forKey: deduplicationKey)
        } catch {
            print("FocusBloxApp: Deduplication failed: \(error)")
        }
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

        try? context.save()
    }
}
