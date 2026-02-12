import AppIntents
import SwiftData

/// Creates a new task in FocusBlox via Siri/Spotlight.
/// iOS 26: Shows an Interactive Snippet with metadata buttons after title input.
struct CreateTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Task erstellen"
    static let description = IntentDescription("Erstellt einen neuen Task in FocusBlox.")

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Titel")
    var taskTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Titel in App Group UserDefaults speichern - App liest und füllt vor
        if let defaults = UserDefaults(suiteName: "group.com.henning.focusblox") {
            defaults.set(true, forKey: "quickCaptureFromCC")
            defaults.set(taskTitle, forKey: "quickCaptureTitle")
        }
        return .result(dialog: "Öffne FocusBlox...")
    }
}

// MARK: - Intent Error

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case message(String)
    case taskNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let msg):
            return "\(msg)"
        case .taskNotFound:
            return "Task nicht gefunden."
        }
    }
}
