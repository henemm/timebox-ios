import AppIntents
import SwiftData

/// Returns all tasks marked as "Next Up" in FocusBlox.
/// Works WITHOUT opening the app thanks to App Group shared container.
struct GetNextUpIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Up anzeigen"
    static let description = IntentDescription("Gibt die aktuelle Next-Up-Liste zurueck.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<[TaskEntity]> & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isNextUp && !$0.isCompleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let tasks = try context.fetch(descriptor)
        let entities = tasks.map { TaskEntity(from: $0) }

        if entities.isEmpty {
            return .result(value: entities, dialog: "Keine Tasks in Next Up.")
        }

        let titles = entities.map(\.title).joined(separator: ", ")
        return .result(
            value: entities,
            dialog: "\(entities.count) Tasks in Next Up: \(titles)"
        )
    }
}
