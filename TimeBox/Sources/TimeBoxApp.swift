import SwiftUI
import SwiftData

@main
struct TimeBoxApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalTask.self,
            TaskMetadata.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.henning.timebox")
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
            print("🟠 TimeBoxApp: -UITesting flag detected, using MockEventKitRepository")
            let mock = MockEventKitRepository()
            mock.mockCalendarAuthStatus = .fullAccess
            mock.mockReminderAuthStatus = .fullAccess
            print("🟠 TimeBoxApp: Mock configured with .fullAccess permissions")
            return mock
        } else {
            print("🟠 TimeBoxApp: Production mode, using EventKitRepository")
            return EventKitRepository()
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.eventKitRepository, eventKitRepository)
        }
        .modelContainer(sharedModelContainer)
    }
}
