import AppIntents
import SwiftData

/// Returns the count of open (not completed) tasks in FocusBlox.
/// Works WITHOUT opening the app thanks to App Group shared container.
struct CountOpenTasksIntent: AppIntent {
    static let title: LocalizedStringResource = "Offene Tasks zaehlen"
    static let description = IntentDescription("Gibt die Anzahl offener Tasks zurueck.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let count = try context.fetchCount(descriptor)

        if count == 0 {
            return .result(value: count, dialog: "Keine offenen Tasks.")
        }
        return .result(value: count, dialog: "Du hast \(count) offene Tasks.")
    }
}
