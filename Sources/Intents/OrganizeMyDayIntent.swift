import AppIntents
import SwiftData

/// Suggests which tasks to work on today by finding calendar gaps and ranking backlog tasks.
/// Read-only — no data is modified.
struct OrganizeMyDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Tag organisieren"
    static let description = IntentDescription(
        "Findet freie Zeitfenster und schlägt passende Tasks für heute vor."
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<[TaskEntity]> & ProvidesDialog {
        let today = Date()

        // 1. Fetch tasks from App Group SwiftData container
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let tasks = try context.fetch(descriptor)
        let planItems = tasks.map { PlanItem(localTask: $0) }

        // 2. Fetch calendar data (graceful degradation if EventKit not authorized)
        let repo = EventKitRepository()
        let calendarEvents = (try? repo.fetchCalendarEvents(for: today)) ?? []
        let focusBlocks = (try? repo.fetchFocusBlocks(for: today)) ?? []

        // 3. Find free slots in today's calendar
        let gapFinder = GapFinder(
            events: calendarEvents,
            focusBlocks: focusBlocks,
            scheduledTasks: [],
            date: today
        )
        let slots = gapFinder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // 4. Build behavioral profile
        let allTasksDescriptor = FetchDescriptor<LocalTask>()
        let allTasks = (try? context.fetch(allTasksDescriptor)) ?? tasks
        let profile = BehavioralProfileService.profile(
            tasks: allTasks,
            focusBlocks: focusBlocks,
            calendarEvents: calendarEvents,
            now: today
        )

        // 5. Rank tasks against slots
        let suggestions = NextUpSuggestionService.suggestions(
            items: planItems,
            slots: slots,
            profile: profile,
            calendarEvents: calendarEvents,
            now: today
        )

        // 6. Build output
        let entities = suggestions.compactMap { suggestion -> TaskEntity? in
            guard let task = tasks.first(where: { $0.uuid.uuidString == suggestion.planItem.id }) else {
                return nil
            }
            return TaskEntity(from: task)
        }

        let dialog = Self.buildDialog(slotCount: slots.count, suggestions: suggestions)
        return .result(value: entities, dialog: "\(dialog)")
    }

    // MARK: - Dialog Builder

    static func buildDialog(
        slotCount: Int,
        suggestions: [NextUpSuggestion]
    ) -> String {
        guard slotCount > 0 else {
            return "Heute sind keine freien Zeitfenster verfügbar."
        }
        guard !suggestions.isEmpty else {
            return "Du hast \(slotCount) freie Zeitfenster, aber keine passenden Tasks im Backlog."
        }

        let titles = suggestions.prefix(3).map(\.planItem.title)
        let spoken: String
        if suggestions.count > 3 {
            let extra = suggestions.count - 3
            spoken = titles.joined(separator: ", ") + " und \(extra) weitere"
        } else {
            spoken = titles.joined(separator: ", ")
        }

        let slotWord = slotCount == 1 ? "freien Slot" : "freie Slots"
        return "Du hast \(slotCount) \(slotWord) heute. Ich schlage vor: \(spoken)."
    }
}
