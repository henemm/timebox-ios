import SwiftUI
import SwiftData
import UserNotifications

@main
struct FocusBloxWatch_Watch_AppApp: App {
    private static let appGroupID = "group.com.henning.focusblox"
    /// Strong reference keeps delegate alive (UNUserNotificationCenter.delegate is weak)
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

    // Register notification delegate in init() — BEFORE any notification action is dispatched.
    // Apple docs: "You must assign your delegate before your app finishes launching."
    // Using .onAppear is too late: when watchOS launches the app for a notification action,
    // didReceive is called before SwiftUI renders the view.
    init() {
        let container = sharedModelContainer
        WatchNotificationDelegate.registerActions()
        let delegate = WatchNotificationDelegate(container: container)
        UNUserNotificationCenter.current().delegate = delegate
        _notificationDelegate = State(initialValue: delegate)
        print("[Watch] Notification delegate registered in init()")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
