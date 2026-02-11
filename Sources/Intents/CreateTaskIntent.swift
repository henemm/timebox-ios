import AppIntents
import SwiftData

/// Creates a new task in FocusBlox via Siri/Spotlight.
/// iOS 26: Shows an Interactive Snippet with metadata buttons after title input.
struct CreateTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Task erstellen"
    static let description = IntentDescription("Erstellt einen neuen Task in FocusBlox.")

    static let openAppWhenRun: Bool = false

    @Parameter(title: "Titel")
    var taskTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        return .result(
            dialog: "Task konfigurieren:",
            snippetIntent: CreateTaskSnippetIntent(taskTitle: taskTitle)
        )
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
