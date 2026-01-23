import WidgetKit
import SwiftUI
import AppIntents

/// Intent that opens the app with Quick Capture view via deep link
struct QuickAddLaunchIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Task"

    func perform() async throws -> some IntentResult & OpensIntent {
        // Open app via deep link - TimeBoxApp.onOpenURL handles this
        guard let url = URL(string: "timebox://create-task") else {
            return .result()
        }
        return .result(opensIntent: OpenURLIntent(url))
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
