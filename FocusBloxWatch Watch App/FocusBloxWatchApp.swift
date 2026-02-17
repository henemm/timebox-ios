import SwiftUI
import SwiftData

@main
struct FocusBloxWatch_Watch_AppApp: App {
    private static let appGroupID = "group.com.henning.focusblox"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalTask.self,
            TaskMetadata.self
        ])

        // Try with App Group + CloudKit first, fallback to local-only
        if let _ = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .private("iCloud.com.henning.focusblox")
            )
            if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
                return container
            }
        }

        // Fallback: CloudKit without App Group
        let fallbackConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [fallbackConfig])
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
