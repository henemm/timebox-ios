import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Control Center: Quick Task Button
// Intent-Definition in Sources/Intents/CCQuickAddIntents.swift
// (kompiliert in BEIDE Targets: FocusBlox + FocusBloxWidgetsExtension)

struct QuickAddTaskControl: ControlWidget {
    static let kind = "com.focusblox.quickAddTask"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickAddLaunchIntent()) {
                Label("Quick Task", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Quick Task")
        .description("Schnell eine neue Aufgabe erstellen")
    }
}
