import SwiftUI
import SwiftData

@main
struct FocusBloxApp: App {
    @State private var showQuickCapture = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalTask.self,
            TaskMetadata.self
        ])

        // Disable CloudKit everywhere until entitlements are properly configured
        // CloudKit requires com.apple.developer.icloud-services entitlement
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")
        let shouldDisableCloudKit = true

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting,
            cloudKitDatabase: shouldDisableCloudKit ? .none : .private("iCloud.com.henning.timebox")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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

            mock.mockFocusBlocks = [focusBlock1, focusBlock2]

            // Add mock Calendar Events for timeline testing
            let meeting1Start = calendar.date(byAdding: .hour, value: 8, to: startOfDay)!
            let meeting1End = calendar.date(byAdding: .minute, value: 30, to: meeting1Start)!
            let meeting1 = CalendarEvent(
                id: "mock-event-1",
                title: "Team Standup",
                startDate: meeting1Start,
                endDate: meeting1End,
                isAllDay: false,
                calendarColor: nil,
                notes: nil
            )

            let meeting2Start = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
            let meeting2End = calendar.date(byAdding: .hour, value: 13, to: startOfDay)!
            let meeting2 = CalendarEvent(
                id: "mock-event-2",
                title: "Lunch Meeting",
                startDate: meeting2Start,
                endDate: meeting2End,
                isAllDay: false,
                calendarColor: nil,
                notes: nil
            )

            let meeting3Start = calendar.date(byAdding: .hour, value: 16, to: startOfDay)!
            let meeting3End = calendar.date(byAdding: .hour, value: 17, to: startOfDay)!
            let meeting3 = CalendarEvent(
                id: "mock-event-3",
                title: "1:1 with Manager",
                startDate: meeting3Start,
                endDate: meeting3End,
                isAllDay: false,
                calendarColor: nil,
                notes: nil
            )

            mock.mockEvents = [meeting1, meeting2, meeting3]

            return mock
        } else {
            return EventKitRepository()
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.eventKitRepository, eventKitRepository)
                .onAppear {
                    seedUITestDataIfNeeded()
                    // Auto-open Quick Capture for UI testing
                    if ProcessInfo.processInfo.arguments.contains("-QuickCaptureTest") {
                        showQuickCapture = true
                    }
                }
                .onOpenURL { url in
                    if url.host == "create-task" {
                        showQuickCapture = true
                    }
                }
                .fullScreenCover(isPresented: $showQuickCapture) {
                    QuickCaptureView()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Seed mock data for UI testing
    private func seedUITestDataIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-UITesting") else { return }

        let context = sharedModelContainer.mainContext

        // Check if already seeded (avoid duplicates on re-render)
        let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.title == "Mock Task 1 #30min" })
        let existingTasks = (try? context.fetch(descriptor)) ?? []
        guard existingTasks.isEmpty else { return }

        // Create mock tasks with isNextUp = true
        let task1 = LocalTask(title: "Mock Task 1 #30min", priority: 3, manualDuration: 30)
        task1.isNextUp = true

        let task2 = LocalTask(title: "Mock Task 2 #15min", priority: 2, manualDuration: 15)
        task2.isNextUp = true

        let task3 = LocalTask(title: "Mock Task 3 #45min", priority: 1, manualDuration: 45)
        task3.isNextUp = true

        // Create a mock task that's already assigned to a Focus Block
        let assignedTask = LocalTask(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                                     title: "Assigned Task #20min",
                                     priority: 2,
                                     manualDuration: 20)
        assignedTask.isNextUp = false  // Not in Next Up because it's assigned

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        context.insert(assignedTask)

        try? context.save()
    }
}
