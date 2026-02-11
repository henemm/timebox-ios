import WidgetKit
import SwiftUI
import AppIntents

/// Intent that opens the app and triggers Quick Capture
/// Sets App Group flag, then openAppWhenRun brings app to foreground.
/// App checks flag on activation via checkCCQuickCaptureTrigger().
struct QuickAddLaunchIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Task"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        defaults?.set(true, forKey: "quickCaptureFromCC")
        return .result()
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
