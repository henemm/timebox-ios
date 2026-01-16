import SwiftUI
import SwiftData

@main
struct TimeBoxApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalTask.self,
            TaskMetadata.self
        ])

        // Disable CloudKit for UI testing to avoid simulator crashes
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting,
            cloudKitDatabase: isUITesting ? .none : .private("iCloud.com.henning.timebox")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if isUITesting {
                print("🟠 TimeBoxApp: ModelContainer configured for UI testing (in-memory, no CloudKit)")
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// Repository based on launch mode (test vs production)
    private let eventKitRepository: any EventKitRepositoryProtocol = {
        let logMessage: String
        let repo: any EventKitRepositoryProtocol

        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            logMessage = "🟠 TimeBoxApp: -UITesting flag detected, using MockEventKitRepository\n🟠 TimeBoxApp: Mock configured with .fullAccess permissions"
            let mock = MockEventKitRepository()
            mock.mockCalendarAuthStatus = .fullAccess
            mock.mockReminderAuthStatus = .fullAccess
            repo = mock
        } else {
            logMessage = "🟠 TimeBoxApp: Production mode, using EventKitRepository"
            repo = EventKitRepository()
        }

        print(logMessage)
        DebugLogger.log(logMessage)
        return repo
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.eventKitRepository, eventKitRepository)
        }
        .modelContainer(sharedModelContainer)
    }
}
