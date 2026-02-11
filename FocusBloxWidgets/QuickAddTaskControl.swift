import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Test A: Pure openAppWhenRun (star.fill)
// Testet: Öffnet die App überhaupt vom CC aus?

struct TestA_PureOpenIntent: AppIntent {
    static var title: LocalizedStringResource = "Test A: Pure Open"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

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

// MARK: - Test B: App Group Flag + openAppWhenRun (flame.fill)
// Testet: Flag-basierter Trigger mit App-Öffnung

struct TestB_FlagIntent: AppIntent {
    static var title: LocalizedStringResource = "Test B: Flag"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        defaults?.set(true, forKey: "quickCaptureFromCC")
        return .result()
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

// MARK: - Test C: OpenURLIntent + openAppWhenRun (link)
// Testet: Aktueller Ansatz mit URL-Scheme

struct TestC_URLIntent: AppIntent {
    static var title: LocalizedStringResource = "Test C: URL"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenURLIntent(URL(string: "focusblox://create-task")!))
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

// MARK: - Test D: App Group Flag OHNE openAppWhenRun (bolt.fill)
// Testet: Läuft der Intent überhaupt? (App öffnet sich NICHT)
// Nach Tap: App manuell öffnen - wenn QuickCapture erscheint, lief der Intent.

struct TestD_FlagOnlyIntent: AppIntent {
    static var title: LocalizedStringResource = "Test D: Flag Only"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        defaults?.set(true, forKey: "quickCaptureFromCC")
        return .result()
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
