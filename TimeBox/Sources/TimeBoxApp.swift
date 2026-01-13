import SwiftUI
import SwiftData

@main
struct TimeBoxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: TaskMetadata.self)
    }
}
