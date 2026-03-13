import AppIntents
import SwiftData

/// Siri intent: "Wie war mein Tag?" — reads the evening reflection summary.
struct GetEveningSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Tagesrueckblick"
    static let description = IntentDescription("Liest die Abend-Auswertung deiner Intention vor.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let intention = DailyIntention.load()
        guard intention.isSet else {
            return .result(dialog: "Du hast heute keine Intention gesetzt.")
        }

        // Tasks via SharedModelContainer (App Group SwiftData)
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let tasks = try context.fetch(FetchDescriptor<LocalTask>())

        // FocusBlocks via EventKit (fallback: empty array)
        let blocks: [FocusBlock]
        do {
            blocks = try EventKitRepository().fetchFocusBlocks(for: Date())
        } catch {
            blocks = []
        }

        // Evaluate each selected intention
        var summaryParts: [String] = []
        for option in intention.selections {
            let level = IntentionEvaluationService.evaluateFulfillment(
                intention: option, tasks: tasks, focusBlocks: blocks
            )
            let text = IntentionEvaluationService.fallbackTemplate(
                intention: option, level: level
            )
            if !text.isEmpty {
                summaryParts.append(text)
            }
        }

        let summary = summaryParts.joined(separator: " ")
        return .result(dialog: "\(summary)")
    }
}
