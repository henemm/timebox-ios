import AppIntents
import Foundation

// MARK: - CC Quick Add Intents (Bug 36 Diagnostic)
// Diese Datei muss in BEIDE Targets: FocusBlox + FocusBloxWidgetsExtension

// MARK: - Test A: Pure openAppWhenRun (star.fill)

struct TestA_PureOpenIntent: AppIntent {
    static let title: LocalizedStringResource = "Test A: Pure Open"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Test B: App Group Flag + openAppWhenRun (flame.fill)

struct TestB_FlagIntent: AppIntent {
    static let title: LocalizedStringResource = "Test B: Flag"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        defaults?.set(true, forKey: "quickCaptureFromCC")
        return .result()
    }
}

// MARK: - Test C: OpenURLIntent + openAppWhenRun (link)

struct TestC_URLIntent: AppIntent {
    static let title: LocalizedStringResource = "Test C: URL"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenURLIntent(URL(string: "focusblox://create-task")!))
    }
}

// MARK: - Test D: App Group Flag OHNE openAppWhenRun (bolt.fill)

struct TestD_FlagOnlyIntent: AppIntent {
    static let title: LocalizedStringResource = "Test D: Flag Only"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        defaults?.set(true, forKey: "quickCaptureFromCC")
        return .result()
    }
}
