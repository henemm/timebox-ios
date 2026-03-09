import SwiftUI
import SwiftData
import UserNotifications

@main
struct FocusBloxWatch_Watch_AppApp: App {
    private static let appGroupID = "group.com.henning.focusblox"
    @State private var notificationDelegate: WatchNotificationDelegate?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalTask.self,
            TaskMetadata.self
        ])

        // Try with App Group + CloudKit first, fallback to local-only
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            print("[CloudKit] Watch: App Group verfuegbar (\(containerURL.path))")
            let cloudConfig = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .private("iCloud.com.henning.focusblox")
            )
            do {
                let container = try ModelContainer(for: schema, configurations: [cloudConfig])
                print("[CloudKit] Watch: ModelContainer mit CloudKit ERFOLGREICH erstellt")
                return container
            } catch {
                print("[CloudKit] Watch: ModelContainer mit CloudKit FEHLGESCHLAGEN: \(error)")
            }
        } else {
            print("[CloudKit] Watch: App Group NICHT verfuegbar — kein CloudKit moeglich")
        }

        // Fallback: local-only (NO CloudKit sync!)
        print("[CloudKit] Watch: FALLBACK auf lokalen Speicher OHNE CloudKit-Sync!")
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
                .onAppear {
                    WatchNotificationDelegate.registerActions()
                    let delegate = WatchNotificationDelegate(container: sharedModelContainer)
                    UNUserNotificationCenter.current().delegate = delegate
                    notificationDelegate = delegate
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
