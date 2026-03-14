import AppIntents
import SwiftData

/// Siri intent: "Wie war mein Tag?" — reads the evening reflection summary.
struct GetEveningSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Tagesrueckblick"
    static let description = IntentDescription("Liest die Abend-Auswertung deines Coaches vor.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selection = DailyCoachSelection.load()
        guard let coach = selection.coach else {
            return .result(dialog: "Du hast heute keinen Coach gewaehlt.")
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

        let level = IntentionEvaluationService.evaluateFulfillment(
            coach: coach, tasks: tasks, focusBlocks: blocks
        )
        let text = IntentionEvaluationService.fallbackTemplate(
            coach: coach, level: level
        )

        return .result(dialog: "\(text)")
    }
}
