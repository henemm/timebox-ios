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

    // MARK: - Token Budget (AI_004)

    /// Calculates what percentage of the context window a prompt uses.
    /// Returns 0 if contextSize is 0 (division-by-zero guard).
    static func tokenBudgetPercentage(tokens: Int, contextSize: Int) -> Int {
        guard contextSize > 0 else { return 0 }
        return Int(Double(tokens) / Double(contextSize) * 100)
    }

    #if canImport(FoundationModels)
    /// Logs token usage for a prompt in Debug builds.
    @available(iOS 26.4, macOS 26.4, *)
    static func logTokenUsage(prompt: String, service: String) async {
        #if DEBUG
        let model = SystemLanguageModel.default
        let contextSize = model.contextSize
        guard let tokens = try? await model.tokenCount(for: prompt) else { return }
        let pct = tokenBudgetPercentage(tokens: tokens, contextSize: contextSize)
        print("[\(service)] Prompt: \(tokens) tokens (\(pct)% of \(contextSize) context)")
        if pct > 50 {
            print("[\(service)] ⚠️ Prompt verbraucht \(pct)% des Context Windows!")
        }
        #endif
    }
    #endif

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
        @Guide(description: "Importance: 1=nice to have, 2=should do (DEFAULT for most tasks), 3=must do (only real obligations with consequences)")
        let suggestedImportance: Int

        @Guide(description: "Is this time-critical? true ONLY if concrete deadline/date exists, false otherwise")
        let suggestedUrgent: Bool

        @Guide(description: "Task category", .anyOf(["income", "maintenance", "recharge", "learning", "giving_back"]))
        let suggestedTaskType: String

        @Guide(description: "Cognitive energy required", .anyOf(["high", "low"]))
        let suggestedEnergyLevel: String

        @Guide(description: "Estimated duration in minutes: 5, 15, 30, or 60")
        let suggestedDurationMinutes: Int

        @Guide(description: "Up to 3 suggested tags for this task. Prefer tags the user already uses. At most 1 completely new tag. Empty array if no good match.")
        let suggestedTags: [String]
    }

    #endif

    // MARK: - Seed Tags

    /// Base tags suggested for new users who haven't created any tags yet.
    static let seedTags = ["computer", "telefon", "unterwegs", "zuhause", "einkauf"]

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

    // MARK: - Live Enrichment

    /// Result of a combined live enrichment call (tags + duration + importance).
    struct LiveEnrichmentResult {
        let tags: [String]
        let durationMinutes: Int?
        let importance: Int?

        static let empty = LiveEnrichmentResult(tags: [], durationMinutes: nil, importance: nil)
    }

    /// Combined live enrichment for the task creation form.
    /// Returns tags, suggested duration, and suggested importance in one AI call.
    func suggestLiveEnrichment(title: String, existingTags: [String]) async -> LiveEnrichmentResult {
        guard Self.isAvailable else { return .empty }
        guard AppSettings.shared.aiScoringEnabled else { return .empty }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await performLiveEnrichment(title: title, existingTags: existingTags)
        }
        #endif
        return .empty
    }

    // MARK: - Live Tag Suggestions

    /// Tag-only convenience wrapper around suggestLiveEnrichment.
    func suggestTagsForTitle(_ title: String, existingTags: [String]) async -> [String] {
        await suggestLiveEnrichment(title: title, existingTags: existingTags).tags
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

            // Cache context ONCE before batch — prevents snowball effect where
            // early (possibly wrong) enrichments poison later tasks' prompts
            let cachedContext = fetchRecentTaskContext()

            for task in tasks {
                let changed = await reanalyzeTask(task, cachedContext: cachedContext)
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
    func reanalyzeTask(_ task: LocalTask, cachedContext: String? = nil) async -> Bool {
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
                await performEnrichment(task, cachedContext: cachedContext)
                changed = true
            }

            // Step 6b: Promote suggestedDuration → estimatedDuration (confirmSuggestions() is not called in reanalyze)
            if task.estimatedDuration == nil, let dur = task.suggestedDuration {
                task.estimatedDuration = dur
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
            if #available(iOS 26.4, macOS 26.4, *) {
                await Self.logTokenUsage(prompt: prompt, service: "SmartEnrichment/Category")
            }
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
    private func performEnrichment(_ task: LocalTask, cachedContext: String? = nil) async {
        let prompt = buildPrompt(for: task, cachedContext: cachedContext)
        if #available(iOS 26.4, macOS 26.4, *) {
            await Self.logTokenUsage(prompt: prompt, service: "SmartEnrichment")
        }

        do {
            let session = LanguageModelSession {
                "Du analysierst Task-Titel und leitest fehlende Attribute ab."
                ""
                "Wichtigkeit (1-3):"
                "  1 = nice to have (Freizeit, Hobby, optional, kein Zeitdruck)"
                "  2 = should do (die MEISTEN Alltagstasks: Haushalt, Einkaufen, Termine, Besorgungen, Routine, Updates)"
                "  3 = must do (NUR echte Pflichten mit spürbaren Konsequenzen: Steuererklärung, Arzttermin, Deadlines, Finanzen)"
                ""
                "WICHTIG: Im Zweifel importance=2. Nur bei echten Pflichten mit Konsequenzen importance=3."
                "Dringlichkeit: true NUR wenn ein konkretes Datum oder eine Frist existiert. Ohne Datum/Frist → false."
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
                "Tag-Vorschläge (suggestedTags):"
                "  Bevorzuge Tags die der Nutzer bereits verwendet."
                "  Maximal 1 komplett neuer Tag erlaubt."
                "  Falls keine Tags passen: leeres Array []."
                "  Nutzer-Tags: \(fetchUserTags().joined(separator: ", "))"
                ""
                "Orientiere dich an den Attributen ähnlicher bestehender Tasks wenn vorhanden."
            }

            let response = try await session.respond(to: prompt, generating: TaskEnrichment.self)
            let result = response.content

            // Importance/Urgency: AI darf diese NICHT setzen — nur Keywords dürfen hochsetzen.
            // Default: importance=1, urgency=not_urgent (harmlose Baseline)
            if task.importance == nil {
                task.importance = 1
            }
            if task.urgency == nil {
                task.urgency = "not_urgent"
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

            // Tag suggestions: only when user hasn't set manual tags
            if (task.tags ?? []).isEmpty, !result.suggestedTags.isEmpty {
                let userTags = fetchUserTags()
                let filtered = filterTagSuggestions(result.suggestedTags, existingTags: userTags)
                if !filtered.isEmpty {
                    task.suggestedTags = filtered
                }
            }

            try modelContext.save()
        } catch {
            print("[SmartEnrichment] Failed to enrich task '\(task.title)': \(error)")
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func performLiveEnrichment(title: String, existingTags: [String]) async -> LiveEnrichmentResult {
        let tagContext = existingTags.isEmpty ? Self.seedTags : existingTags
        let taskContext = fetchRecentTaskContext()

        do {
            let session = LanguageModelSession {
                "Du analysierst einen Task-Titel und schlägst Tags, Dauer und Wichtigkeit vor."
                ""
                "Wichtigkeit (1-3):"
                "  1 = nice to have (Freizeit, Hobby, optional)"
                "  2 = should do (MEISTE Alltagstasks: Haushalt, Einkaufen, Termine)"
                "  3 = must do (NUR echte Pflichten mit Konsequenzen)"
                "Im Zweifel importance=2."
                ""
                "Dauer in Minuten: 5, 15, 30, oder 60"
                ""
                "Tag-Regeln:"
                "  - Maximal 3 Tags vorschlagen"
                "  - Bevorzuge Tags aus der Liste des Nutzers"
                "  - Maximal 1 komplett neuer Tag erlaubt"
                "  - Falls nichts passt: leeres Array"
                ""
                "Verfügbare Tags des Nutzers: \(tagContext.joined(separator: ", "))"
                if !taskContext.isEmpty {
                    ""
                    "Bestehende Tasks des Nutzers (orientiere dich an deren Attributen):"
                    taskContext
                }
            }

            let response = try await session.respond(to: "Aufgabe: \(title)", generating: TaskEnrichment.self)
            let enrichment = response.content
            let filteredTags = filterTagSuggestions(enrichment.suggestedTags, existingTags: tagContext)
            let validDuration = [5, 15, 30, 60].contains(enrichment.suggestedDurationMinutes)
                ? enrichment.suggestedDurationMinutes : nil
            let validImportance = (1...3).contains(enrichment.suggestedImportance)
                ? enrichment.suggestedImportance : nil

            return LiveEnrichmentResult(
                tags: filteredTags,
                durationMinutes: validDuration,
                importance: validImportance
            )
        } catch {
            print("[SmartEnrichment] Live enrichment failed for '\(title)': \(error)")
            return .empty
        }
    }

    #endif

    // MARK: - Tag Helpers

    /// Fetches all user-used tags sorted by frequency, falls back to seed tags.
    private func fetchUserTags() -> [String] {
        let taskSource = LocalTaskSource(modelContext: modelContext)
        let tags = (try? taskSource.fetchAllUsedTags()) ?? []
        return tags.isEmpty ? Self.seedTags : tags
    }

    /// Filters AI tag suggestions: max 3 total, max 1 new tag.
    private func filterTagSuggestions(_ suggestions: [String], existingTags: [String]) -> [String] {
        let loweredExisting = Set(existingTags.map { $0.lowercased() })
        var result: [String] = []
        var newTagCount = 0

        for tag in suggestions.prefix(3) {
            let cleaned = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "#", with: "")
            guard !cleaned.isEmpty else { continue }

            if loweredExisting.contains(cleaned) {
                result.append(cleaned)
            } else if newTagCount < 1 {
                result.append(cleaned)
                newTagCount += 1
            }
        }

        return result
    }

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
            if let dur = task.estimatedDuration { parts.append("Dauer: \(dur)min") }
            if let tags = task.tags, !tags.isEmpty { parts.append("Tags: \(tags.joined(separator: ", "))") }
            return parts.joined(separator: " | ")
        }.joined(separator: "\n")
    }

    func buildPrompt(for task: LocalTask, cachedContext: String? = nil) -> String {
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

        let context = cachedContext ?? fetchRecentTaskContext()
        if !context.isEmpty {
            parts.append("")
            parts.append("Bestehende Tasks des Nutzers (orientiere dich an deren Attributen für ähnliche Tasks):")
            parts.append(context)
        }

        return parts.joined(separator: "\n")
    }
}
