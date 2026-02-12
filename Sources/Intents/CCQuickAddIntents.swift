import AppIntents
import Foundation

// MARK: - CC Quick Add Intent
// Diese Datei muss in BEIDE Targets: FocusBlox + FocusBloxWidgetsExtension
// Mechanismus: OpenURLIntent + openAppWhenRun (getestet via Bug 36 Diagnostic)

struct QuickAddLaunchIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Task erstellen"
    static let description: IntentDescription = "Öffnet FocusBlox zum schnellen Erstellen einer Aufgabe"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenURLIntent(URL(string: "focusblox://create-task")!))
    }
}
