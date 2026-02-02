import WidgetKit
import SwiftUI
import AppIntents

/// Intent that opens the app and triggers Quick Capture
/// Uses openAppWhenRun with URL intent for reliable widget→app communication
struct QuickAddLaunchIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Task"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        // Return intent that opens the URL scheme
        // This triggers the app's onOpenURL handler
        return .result(opensIntent: OpenURLIntent(URL(string: "focusblox://create-task")!))
    }
}

/// Control Center widget for quick task capture
struct QuickAddTaskControl: ControlWidget {
    static let kind: String = "com.timebox.quickadd"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickAddLaunchIntent()) {
                Label("Quick Task", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Quick Task")
        .description("Schnell einen neuen Task erfassen")
    }
}
