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

        @Guide(description: "Estimated duration in minutes: 5, 15, 30, or 60")
        let suggestedDurationMinutes: Int
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

    /// Re-analyze all incomplete tasks: title cleanup, date extraction, and AI enrichment.
    /// Applies the full rule set (TaskTitleEngine + SmartTaskEnrichmentService) to every task.
    /// Deterministic steps (title cleanup, date extraction) always run.
    /// AI steps only run when Apple Intelligence is available.
    /// Returns the number of tasks updated.
    func reanalyzeAllTasks() async -> Int {
        let predicate = #Predicate<LocalTask> { !$0.isCompleted }
        let descriptor = FetchDescriptor<LocalTask>(predicate: predicate)

        do {
            let allTasks = try modelContext.fetch(descriptor)
            let tasks = allTasks.filter { task in
                task.lifecycleStatus != TaskLifecycleStatus.raw.rawValue
            }
            var updatedCount = 0

            for task in tasks {
                let changed = await reanalyzeTask(task)
                if changed {
                    updatedCount += 1
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            try? modelContext.save()
            return updatedCount
        } catch {
            print("[SmartEnrichment] Full reanalysis failed: \(error)")
            return 0
        }
    }

    /// Re-analyze a single task. Returns true if any field was changed.
    /// Steps 1-5 are deterministic (always run), Steps 6-7 need AI.
    func reanalyzeTask(_ task: LocalTask) async -> Bool {
        var changed = false

        // Capture original title BEFORE cleanup for keyword extraction
        let originalTitle = task.taskDescription ?? task.title

        // --- Deterministic steps (always run, no AI needed) ---

        // Step 1: Title cleanup (all keywords, email prefixes, intro phrases)
        let cleanedTitle = TaskTitleEngine.cleanTitle(task.title)
        if cleanedTitle != task.title {
            task.title = cleanedTitle
            changed = true
        }

        // Step 2: Date extraction from original title (pre-cleanup)
        if task.dueDate == nil,
           TaskTitleEngine.titleContainsDateKeyword(originalTitle),
           let date = TaskTitleEngine.extractDeterministicDueDate(from: originalTitle) {
            task.dueDate = date
            changed = true
        }

        // Step 3: Urgency extraction — explicit keyword OVERRIDES any AI value
        if let urgency = TaskTitleEngine.extractDeterministicUrgency(from: originalTitle) {
            if task.urgency != urgency {
                task.urgency = urgency
                changed = true
            }
        }

        // Step 4: Importance extraction — explicit keyword OVERRIDES any AI value
        if let importance = TaskTitleEngine.extractDeterministicImportance(from: originalTitle) {
            if task.importance != importance {
                task.importance = importance
                changed = true
            }
        }

        // Step 5: Duration extraction (only if not already set by user)
        if task.estimatedDuration == nil,
           let duration = TaskTitleEngine.extractDeterministicDuration(from: originalTitle) {
            task.estimatedDuration = duration
            changed = true
        }

        // --- AI steps (only when available) ---

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), Self.isAvailable {
            // Step 6: AI enrichment for missing attributes
            let needsEnrichment = task.importance == nil || task.urgency == nil ||
                task.taskType.isEmpty || task.aiEnergyLevel == nil
            if needsEnrichment {
                await performEnrichment(task)
                changed = true
            }

            // Step 7: AI category + duration estimation
            let needsCategoryOrDuration = task.taskType.isEmpty || task.estimatedDuration == nil
            if needsCategoryOrDuration {
                await enrichCategoryAndDuration(task)
                changed = true
            }
        }
        #endif

        return changed
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func performBatchEnrichment() async -> Int {
        let predicate = #Predicate<LocalTask> { !$0.isCompleted }
        let descriptor = FetchDescriptor<LocalTask>(predicate: predicate)

        do {
            let allTasks = try modelContext.fetch(descriptor)
            let tasks = allTasks.filter { task in
                task.importance == nil || task.urgency == nil || task.taskType.isEmpty || task.aiEnergyLevel == nil
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

    @available(iOS 26.0, macOS 26.0, *)
    private func enrichCategoryAndDuration(_ task: LocalTask) async {
        do {
            let session = LanguageModelSession {
                "Du kategorisierst Aufgaben und schätzt die Dauer."
                ""
                "Kategorien:"
                "- income: Arbeit, Geld verdienen, Karriere, Freelance, Rechnungen, Kunden, Berichte, Präsentationen, Code, Meetings"
                "- maintenance: Haushalt, Besorgungen, Reparaturen, Putzen, Einkaufen, Gesundheitstermine, Behörden, Steuern, Versicherungen"
                "- recharge: Sport, Erholung, Hobbys, Meditation, Wellness, Freizeit, Konzerte, Filme, Serien, Musik"
                "- learning: Lernen, Lesen, Kurse, Weiterbildung, Konferenzen (WWDC etc.), Vokabeln, Podcasts"
                "- giving_back: Familie, Freunde, Ehrenamt, Geschenke, soziale Events, Helfen"
                ""
                "Dauer in Minuten: 5 (kurzer Anruf/Nachricht), 15 (kurze Aufgabe), 30 (mittlere Aufgabe), 60 (lange/tiefe Arbeit)"
                ""
                "Beispiele:"
                "  Quartalsbericht fertigstellen → income"
                "  Bewerbung schreiben → income"
                "  Pull Request reviewen → income"
                "  Steuererklärung abgeben → maintenance"
                "  WWDC-Session anschauen → learning"
                "  Gitarre üben → recharge"
                "  Kruder & Dorfmeister Tickets kaufen → recharge"
            }

            let prompt = "Task: \(task.title)"
            let response = try await session.respond(to: prompt, generating: TaskTitleEngine.TaskSuggestion.self)
            let result = response.content

            let validCategories = ["income", "maintenance", "recharge", "learning", "giving_back"]
            if task.taskType.isEmpty, validCategories.contains(result.category) {
                task.taskType = result.category
            }

            if task.estimatedDuration == nil, let minutes = Int(result.estimatedMinutes),
               [5, 15, 30, 60].contains(minutes) {
                task.estimatedDuration = minutes
            }
        } catch {
            print("[SmartEnrichment] Category/duration enrichment failed for '\(task.title)': \(error)")
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
                "Wichtigkeit (1-3):"
                "  1 = nice to have (Freizeit, Hobby, optional)"
                "  2 = should do (Routine, Haushalt, Einkaufen)"
                "  3 = must do (Pflichten, Deadlines, Finanzen, Bewerbungen, Gesundheit)"
                ""
                "Dringlichkeit: true wenn zeitkritisch (Termin, Frist, morgen, heute, bis [Datum])"
                ""
                "Kategorie: income (Geld verdienen), maintenance (Pflege/Haushalt), recharge (Erholung), learning (Lernen), giving_back (Helfen)"
                ""
                "Energie:"
                "  high = kognitive Tiefenarbeit (Steuererklärung, Bewerbung schreiben, Programmieren, Analyse, Berichte)"
                "  low = Routine ohne tiefes Nachdenken (Einkaufen, Putzen, Müll rausbringen, Gitarre üben)"
                ""
                "Beispiele:"
                "  Steuererklärung abgeben → importance: 3, urgent: false, category: maintenance, energy: high"
                "  Bewerbung schreiben → importance: 3, urgent: false, category: income, energy: high"
                "  Einkaufen gehen → importance: 2, urgent: false, category: maintenance, energy: low"
                "  Gitarre üben → importance: 1, urgent: false, category: recharge, energy: low"
                "  Server ist down → importance: 3, urgent: true, category: income, energy: high"
                "  Netflix schauen → importance: 1, urgent: false, category: recharge, energy: low"
                ""
                "Orientiere dich an den Attributen ähnlicher bestehender Tasks wenn vorhanden."
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
            // Duration estimation (was missing — only reanalyzeTask had it)
            if task.suggestedDuration == nil {
                let minutes = result.suggestedDurationMinutes
                if [5, 15, 30, 60].contains(minutes) {
                    task.suggestedDuration = minutes
                }
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
            parts.append("Bestehende Tasks des Nutzers (orientiere dich an deren Attributen für ähnliche Tasks):")
            parts.append(context)
        }

        return parts.joined(separator: "\n")
    }
}
