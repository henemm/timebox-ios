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
            let mock = MockEventKitRepository()
            mock.mockCalendarAuthStatus = .fullAccess
            mock.mockReminderAuthStatus = .fullAccess
            return mock
        } else {
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
