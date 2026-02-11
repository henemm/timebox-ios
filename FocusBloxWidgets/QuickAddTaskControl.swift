import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Bug 36 Diagnostic: 4 CC-Buttons
// Intent-Definitionen sind in Sources/Intents/CCQuickAddIntents.swift
// (kompiliert in BEIDE Targets: FocusBlox + FocusBloxWidgetsExtension)

struct TestAControl: ControlWidget {
    static let kind = "com.focusblox.cc.testA"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: TestA_PureOpenIntent()) {
                Label("Test A", systemImage: "star.fill")
            }
        }
        .displayName("A: Pure Open")
        .description("Nur openAppWhenRun")
    }
}

struct TestBControl: ControlWidget {
    static let kind = "com.focusblox.cc.testB"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: TestB_FlagIntent()) {
                Label("Test B", systemImage: "flame.fill")
            }
        }
        .displayName("B: Flag")
        .description("App Group Flag + openAppWhenRun")
    }
}

struct TestCControl: ControlWidget {
    static let kind = "com.focusblox.cc.testC"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: TestC_URLIntent()) {
                Label("Test C", systemImage: "link")
            }
        }
        .displayName("C: URL")
        .description("OpenURLIntent + openAppWhenRun")
    }
}

struct TestDControl: ControlWidget {
    static let kind = "com.focusblox.cc.testD"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: TestD_FlagOnlyIntent()) {
                Label("Test D", systemImage: "bolt.fill")
            }
        }
        .displayName("D: Flag Only")
        .description("Flag ohne openAppWhenRun")
    }
}
