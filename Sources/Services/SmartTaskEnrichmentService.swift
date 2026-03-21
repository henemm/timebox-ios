import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Service for AI-powered task enrichment using Apple Intelligence (Foundation Models).
/// Fills missing task attributes (importance, urgency, taskType, energyLevel) from the title.
/// User-set values are NEVER overwritten.
@MainActor
final class SmartTaskEnrichmentService {

    // MARK: - Availability

    /// Whether Apple Intelligence enrichment is available on this device.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - Structured Output

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct TaskEnrichment {
        @Guide(description: "Importance 1-3: 1=nice to have, 2=should do, 3=must do")
        let suggestedImportance: Int

        @Guide(description: "Is this time-critical? true=urgent, false=not urgent")
        let suggestedUrgent: Bool

        @Guide(description: "Category: income, maintenance, recharge, learning, giving_back")
        let suggestedTaskType: String

        @Guide(description: "Cognitive energy: high for deep focus, low for routine")
        let suggestedEnergyLevel: String
    }
    #endif

    // MARK: - Properties

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Enrichment

    /// Enrich a task with AI-suggested attributes.
    /// Only fills nil/empty fields — user-set values are preserved.
    func enrichTask(_ task: LocalTask) async {
        guard Self.isAvailable else { return }
        guard AppSettings.shared.aiScoringEnabled else { return }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            await performEnrichment(task)
        }
        #endif
    }

    // MARK: - Batch Enrichment

    /// Enrich all incomplete tasks that have missing attributes.
    /// Returns the number of tasks enriched.
    func enrichAllTbdTasks() async -> Int {
        guard Self.isAvailable else { return 0 }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await performBatchEnrichment()
        }
        #endif
        return 0
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func performBatchEnrichment() async -> Int {
        let predicate = #Predicate<LocalTask> { !$0.isCompleted }
        let descriptor = FetchDescriptor<LocalTask>(predicate: predicate)

        do {
            let allTasks = try modelContext.fetch(descriptor)
            let tasks = allTasks.filter { task in
                task.lifecycleStatus != TaskLifecycleStatus.raw.rawValue &&
                (task.importance == nil || task.urgency == nil || task.taskType.isEmpty || task.aiEnergyLevel == nil)
            }
            var enrichedCount = 0

            for task in tasks {
                await performEnrichment(task)
                enrichedCount += 1
                try? await Task.sleep(for: .milliseconds(500))
            }

            return enrichedCount
        } catch {
            print("[SmartEnrichment] Batch fetch failed: \(error)")
            return 0
        }
    }
    #endif

    // MARK: - Private

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func performEnrichment(_ task: LocalTask) async {
        let prompt = buildPrompt(for: task)

        do {
            let session = LanguageModelSession {
                "Du analysierst Task-Titel und leitest fehlende Attribute ab."
                ""
                "Wichtigkeit (1-3): 1=nice to have, 2=should do, 3=must do"
                "Dringlichkeit: Zeitkritische Begriffe (Termin, Frist, morgen, heute) = true"
                "Kategorie: income (Geld verdienen), maintenance (Pflege/Haushalt), recharge (Erholung), learning (Lernen), giving_back (Helfen)"
                "Energie: high = tiefe Fokus-Arbeit (Programmieren, Schreiben, Analyse), low = Routine (Einkaufen, Putzen)"
                ""
                "Orientiere dich an den Attributen aehnlicher bestehender Tasks wenn vorhanden."
                "Beispiel: Wenn mehrere Tasks zum Thema Steuern importance=3 und category=income haben, uebernimm das fuer neue Steuer-Tasks."
            }

            let response = try await session.respond(to: prompt, generating: TaskEnrichment.self)
            let result = response.content

            // Only fill nil/empty fields — user values take precedence
            if task.importance == nil {
                task.importance = max(1, min(3, result.suggestedImportance))
            }
            if task.urgency == nil {
                task.urgency = result.suggestedUrgent ? "urgent" : "not_urgent"
            }
            if task.taskType.isEmpty {
                let validTypes = ["income", "maintenance", "recharge", "learning", "giving_back"]
                if validTypes.contains(result.suggestedTaskType) {
                    task.taskType = result.suggestedTaskType
                }
            }
            // Energy level stored in aiEnergyLevel (reuse existing field)
            if task.aiEnergyLevel == nil {
                let validEnergy = result.suggestedEnergyLevel.lowercased()
                task.aiEnergyLevel = (validEnergy == "high" || validEnergy == "low") ? validEnergy : "low"
            }

            try modelContext.save()
        } catch {
            print("[SmartEnrichment] Failed to enrich task '\(task.title)': \(error)")
        }
    }
    #endif

    // MARK: - Similar-Task Context

    /// Fetches recent tasks with at least one set attribute to provide context for enrichment.
    /// Returns a compact multi-line string or empty string if no attributed tasks found.
    func fetchRecentTaskContext() -> String {
        var descriptor = FetchDescriptor<LocalTask>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        guard let allTasks = try? modelContext.fetch(descriptor) else { return "" }

        // Filter to tasks with at least one meaningful attribute set
        let attributed = allTasks.filter { task in
            task.importance != nil || task.urgency != nil || !task.taskType.isEmpty
        }.prefix(30)

        if attributed.isEmpty { return "" }

        return attributed.map { task in
            var parts = ["- \(task.title)"]
            if !task.taskType.isEmpty { parts.append("Kat: \(task.taskType)") }
            if let imp = task.importance { parts.append("Imp: \(imp)") }
            if let urg = task.urgency { parts.append("Urg: \(urg)") }
            return parts.joined(separator: " | ")
        }.joined(separator: "\n")
    }

    func buildPrompt(for task: LocalTask) -> String {
        var parts: [String] = []
        parts.append("Task: \(task.title)")

        if !(task.tags ?? []).isEmpty {
            parts.append("Tags: \((task.tags ?? []).joined(separator: ", "))")
        }
        if let dueDate = task.dueDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: dueDate, relativeTo: Date())
            parts.append("Frist: \(relative)")
        }
        if let description = task.taskDescription, !description.isEmpty {
            parts.append("Beschreibung: \(description)")
        }

        let context = fetchRecentTaskContext()
        if !context.isEmpty {
            parts.append("")
            parts.append("Bestehende Tasks des Nutzers (orientiere dich an deren Attributen fuer aehnliche Tasks):")
            parts.append(context)
        }

        return parts.joined(separator: "\n")
    }
}
