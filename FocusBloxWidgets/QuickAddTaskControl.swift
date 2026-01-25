import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Notification Name Extension
extension Notification.Name {
    static let quickCaptureRequested = Notification.Name("QuickCaptureRequested")
}

/// Intent that opens the app and triggers Quick Capture
struct QuickAddLaunchIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Task"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // App is already open due to openAppWhenRun = true
        // Post notification to trigger QuickCaptureView
        NotificationCenter.default.post(name: .quickCaptureRequested, object: nil)
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
