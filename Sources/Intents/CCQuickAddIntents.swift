import AppIntents
import Foundation

// MARK: - CC Quick Add Intent
// Diese Datei muss in BEIDE Targets: FocusBlox + FocusBloxWidgetsExtension
// Mechanismus: OpenURLIntent + openAppWhenRun (getestet via Bug 36 Diagnostic)

struct QuickAddLaunchIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Task erstellen"
    static let description: IntentDescription = "Öffnet FocusBlox zum schnellen Erstellen einer Aufgabe"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Flag in App Group UserDefaults setzen - App liest es beim Aktivieren
        if let defaults = UserDefaults(suiteName: "group.com.henning.focusblox") {
            defaults.set(true, forKey: "quickCaptureFromCC")
        }
        return .result()
    }
}
