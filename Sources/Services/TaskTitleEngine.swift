import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Central AI service for improving task titles from raw input.
/// Runs as a batch service at app start — tasks are created immediately with raw titles,
/// the engine improves them asynchronously in the background.
/// Original input is preserved in taskDescription.
@MainActor
final class TaskTitleEngine {

    // MARK: - Availability

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - Deterministic Keyword Stripping

    /// Removes known urgency, importance, duration, and date keywords from task titles.
    /// Runs synchronously — no AI needed. Handles parenthesized, prefix, and standalone formats.
    /// Word-boundary aware: "Morgengymnastik" is preserved, "Morgen" standalone is removed.
    nonisolated static func stripKeywords(_ title: String) -> String {
        var cleaned = title

        // Parenthesized keywords: "(dringend)", "(wichtig)", "(urgent)", "(important)", etc.
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*\(\s*(?:dringend|urgent|asap|sofort|eilig|wichtig|unwichtig|important)\s*\)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Parenthesized duration: "(30 min)", "(1h)", "(45 Minuten)"
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*\(\s*\d+\s*(?:min(?:uten|utes)?|h|hour(?:s)?|stunde(?:n)?)\s*\)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Prefix keywords: "dringend:", "wichtig:", "important:", "urgent:"
        cleaned = cleaned.replacingOccurrences(
            of: #"^(?:dringend|urgent|asap|sofort|eilig|wichtig|unwichtig|important)\s*:\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Duration keywords (word-boundary safe): "30min", "1h", "15 Minuten", "2 Stunden", "30 minutes", "1 hour"
        // Must come before standalone keyword stripping to avoid partial matches
        cleaned = cleaned.replacingOccurrences(
            of: #"\b\d+\s*(?:min(?:uten|utes)?|h|hour(?:s)?|stunde(?:n)?)\b"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Standalone urgency keywords (word-boundary safe): "dringend", "urgent", "asap", "sofort", "eilig"
        // Also handles trailing punctuation: "Dringend!" → removed
        cleaned = cleaned.replacingOccurrences(
            of: #"\b(?:dringend|urgent|asap|sofort|eilig)\b[!.]?"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Standalone importance keywords (word-boundary safe): "wichtig", "unwichtig", "important"
        cleaned = cleaned.replacingOccurrences(
            of: #"\b(?:wichtig|unwichtig|important)\b"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Date keywords (standalone, word-boundary safe): "heute", "morgen", weekdays, etc.
        // Uses \b word boundaries to avoid matching substrings like "Morgengymnastik"
        let dateKeywords = [
            "übermorgen",  // longer first to avoid partial match with "morgen"
            "nächste woche", "next week",
            "heute", "today", "morgen", "tomorrow",
            "montag", "monday", "dienstag", "tuesday",
            "mittwoch", "wednesday", "donnerstag", "thursday",
            "freitag", "friday", "samstag", "saturday",
            "sonntag", "sunday",
        ]
        let datePattern = dateKeywords.joined(separator: "|")
        cleaned = cleaned.replacingOccurrences(
            of: "\\b(?:\(datePattern))\\b",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove orphaned "und"/"and" connectors between removed keywords
        cleaned = cleaned.replacingOccurrences(
            of: #"(?:^|\s)und(?:\s|$)"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"(?:^|\s)and(?:\s|$)"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )

        // Collapse multiple spaces into one and trim
        cleaned = cleaned.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Deterministic Title Cleanup (RW_1.4)

    /// Cleans task titles deterministically using regex — no AI involved.
    /// Removes email prefixes, intro phrases, and urgency keywords.
    /// Umlauts and special characters are NEVER modified.
    static func cleanTitle(_ title: String) -> String {
        var cleaned = title

        // Email prefixes: Re:, Fwd:, AW:, WG:, FW: (case-insensitive, chained)
        cleaned = cleaned.replacingOccurrences(
            of: #"(?:(?:Re|Fwd|AW|WG|FW)\s*:\s*)+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Intro phrases (case-insensitive, at start of string)
        let introPhrases = [
            "erinnere mich daran",
            "ich muss noch",
            "vergiss nicht",
            "denk daran",
        ]
        for phrase in introPhrases {
            cleaned = cleaned.replacingOccurrences(
                of: "(?i)^\(NSRegularExpression.escapedPattern(for: phrase))\\s*",
                with: "",
                options: .regularExpression
            )
        }

        // Urgency keywords via existing stripKeywords()
        cleaned = stripKeywords(cleaned)

        // Normalize whitespace (multiple spaces → single, trim)
        cleaned = cleaned.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Deterministic Importance Extraction (BUG_148)

    /// Extracts importance level from known keywords in the title.
    /// "wichtig"/"important" → 3 (high), "unwichtig" → 1 (low), no keyword → nil.
    /// Word-boundary aware: "Wichtigtuerei" does NOT match.
    nonisolated static func extractDeterministicImportance(from title: String) -> Int? {
        let lower = title.lowercased()
        // Check "unwichtig" first (longer, avoids "wichtig" substring match)
        if lower.range(of: #"\bunwichtig\b"#, options: .regularExpression) != nil {
            return 1
        }
        if lower.range(of: #"\b(?:wichtig|important)\b"#, options: .regularExpression) != nil {
            return 3
        }
        return nil
    }

    // MARK: - Deterministic Urgency Extraction (BUG_148)

    /// Extracts urgency from known keywords in the title.
    /// "dringend"/"urgent"/"asap"/"sofort"/"eilig" → "urgent", no keyword → nil.
    /// Word-boundary aware: "Dringlichkeit" does NOT match.
    nonisolated static func extractDeterministicUrgency(from title: String) -> String? {
        let lower = title.lowercased()
        // Explicit urgency keywords
        if lower.range(of: #"\b(?:dringend|urgent|asap|sofort|eilig)\b"#, options: .regularExpression) != nil {
            return "urgent"
        }
        // Deadline pattern: "bis [Wochentag/heute/morgen]" → urgent
        if lower.range(of: #"\bbis\s+(?:morgen|heute|montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag|ende\s+der\s+woche)\b"#, options: .regularExpression) != nil {
            return "urgent"
        }
        return nil
    }

    // MARK: - Deterministic Duration Extraction (BUG_148)

    /// Extracts duration in minutes from known keywords in the title.
    /// "30min" → 30, "1h" → 60, "2 Stunden" → 120, "45 minutes" → 45.
    /// No keyword → nil.
    nonisolated static func extractDeterministicDuration(from title: String) -> Int? {
        let lower = title.lowercased()
        // Match patterns: "30min", "30 min", "30minuten", "30 minuten", "30minutes", "30 minutes"
        // "1h", "2h", "1 hour", "2 hours", "1 stunde", "2 stunden"
        let pattern = #"\b(\d+)\s*(?:min(?:uten|utes)?|h(?:our(?:s)?)?|stunde(?:n)?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let numberRange = Range(match.range(at: 1), in: lower) else {
            return nil
        }
        let numberStr = String(lower[numberRange])
        guard let number = Int(numberStr), number > 0 else { return nil }

        // Determine unit: hours (h/hour/stunde) vs minutes (min/minuten/minutes)
        let matchStr = String(lower[Range(match.range, in: lower)!]).lowercased()
        let isHours = matchStr.contains("h") && !matchStr.contains("min")
        return isHours ? number * 60 : number
    }

    // MARK: - Date Keyword Detection (Bug 95)

    /// Deterministic check: does the title contain a known date keyword?
    /// Used as guard before accepting AI-extracted dueDate to prevent hallucination.
    static func titleContainsDateKeyword(_ title: String) -> Bool {
        let lower = title.lowercased()
        let keywords = [
            "heute", "today", "morgen", "tomorrow", "übermorgen",
            "nächste woche", "next week",
            "montag", "monday", "dienstag", "tuesday", "mittwoch", "wednesday",
            "donnerstag", "thursday", "freitag", "friday", "samstag", "saturday",
            "sonntag", "sunday"
        ]
        return keywords.contains { lower.contains($0) }
    }

    // MARK: - Deterministic Date Extraction (Bug 97)

    /// Extracts a due date from a title using deterministic keyword matching.
    /// No AI needed — uses keyword→date mapping directly.
    /// Used by CreateTaskIntent for immediate date extraction without AI.
    nonisolated static func extractDeterministicDueDate(from title: String) -> Date? {
        let lower = title.lowercased()
        // Order: longer/more specific keywords first to avoid partial matches
        let mappings: [(keyword: String, relative: String)] = [
            ("übermorgen", "übermorgen"),
            ("nächste woche", "nächste woche"),
            ("next week", "next week"),
            ("heute", "heute"), ("today", "heute"),
            ("morgen", "morgen"), ("tomorrow", "morgen"),
            ("montag", "montag"), ("monday", "montag"),
            ("dienstag", "dienstag"), ("tuesday", "dienstag"),
            ("mittwoch", "mittwoch"), ("wednesday", "mittwoch"),
            ("donnerstag", "donnerstag"), ("thursday", "donnerstag"),
            ("freitag", "freitag"), ("friday", "freitag"),
            ("samstag", "samstag"), ("saturday", "samstag"),
            ("sonntag", "sonntag"), ("sunday", "sonntag"),
        ]
        for mapping in mappings {
            if lower.contains(mapping.keyword) {
                return relativeDateFrom(mapping.relative)
            }
        }
        return nil
    }

    // MARK: - Date Helper

    /// Maps relative date strings from AI output to actual dates.
    /// Accepts German and English variants, weekdays, and extended phrases.
    nonisolated static func relativeDateFrom(_ value: String?) -> Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        switch value?.lowercased() {
        case "today", "heute":
            return today
        case "tomorrow", "morgen":
            return cal.date(byAdding: .day, value: 1, to: today)
        case "übermorgen":
            return cal.date(byAdding: .day, value: 2, to: today)
        case "nächste woche", "next week":
            return nextWeekday(2, after: today) // Monday
        case "montag", "monday":
            return nextWeekday(2, after: today)
        case "dienstag", "tuesday":
            return nextWeekday(3, after: today)
        case "mittwoch", "wednesday":
            return nextWeekday(4, after: today)
        case "donnerstag", "thursday":
            return nextWeekday(5, after: today)
        case "freitag", "friday":
            return nextWeekday(6, after: today)
        case "samstag", "saturday":
            return nextWeekday(7, after: today)
        case "sonntag", "sunday":
            return nextWeekday(1, after: today)
        default:
            return nil
        }
    }

    /// Returns the next occurrence of the given weekday (1=Sun .. 7=Sat).
    /// Always returns a future date (never today).
    nonisolated private static func nextWeekday(_ weekday: Int, after date: Date) -> Date {
        let cal = Calendar.current
        let current = cal.component(.weekday, from: date)
        var daysAhead = weekday - current
        if daysAhead <= 0 { daysAhead += 7 }
        return cal.date(byAdding: .day, value: daysAhead, to: date)!
    }

    // MARK: - Structured Output (RW_1.4: Category + Duration only)

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct TaskSuggestion {
        @Guide(description: "Task category", .anyOf(["income", "maintenance", "recharge", "learning", "giving_back"]))
        let category: String

        @Guide(description: "Estimated duration in minutes", .anyOf(["5", "15", "30", "60"]))
        let estimatedMinutes: String
    }
    #endif

    // MARK: - Properties

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Improve the title of a single task if needed.
    /// Deterministic steps (title cleanup, keyword extraction) run ALWAYS.
    /// AI steps (category/duration suggestion) only run when AI is available and enabled.
    func improveTitleIfNeeded(_ task: LocalTask) async {
        guard task.needsTitleImprovement else { return }

        // Preserve original title in description (if description is empty)
        if task.taskDescription == nil || task.taskDescription?.isEmpty == true {
            task.taskDescription = task.title
        }

        let originalTitle = task.taskDescription ?? task.title

        // --- Deterministic steps (always run, no AI needed) ---

        // Step 1: Title cleanup (removes keywords, email prefixes, intro phrases)
        task.title = Self.cleanTitle(task.title)

        // Step 2: Urgency extraction (only if not already set)
        if task.urgency == nil,
           let urgency = Self.extractDeterministicUrgency(from: originalTitle) {
            task.urgency = urgency
        }

        // Step 3: Importance extraction (only if not already set)
        if task.importance == nil,
           let importance = Self.extractDeterministicImportance(from: originalTitle) {
            task.importance = importance
        }

        // Step 4: Duration extraction (only if not already set)
        if task.estimatedDuration == nil,
           let duration = Self.extractDeterministicDuration(from: originalTitle) {
            task.estimatedDuration = duration
        }

        // Step 5: Date extraction (only if not already set)
        if task.dueDate == nil,
           Self.titleContainsDateKeyword(originalTitle),
           let date = Self.extractDeterministicDueDate(from: originalTitle) {
            task.dueDate = date
        }

        // --- AI steps (only when available and enabled) ---

        if AppSettings.shared.aiScoringEnabled, Self.isAvailable {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, *) {
                await enrichWithSuggestions(task)
            }
            #endif
        }

        task.needsTitleImprovement = false
        try? modelContext.save()
    }

    /// Batch: Improve all tasks with needsTitleImprovement flag.
    /// Deterministic steps (title cleanup, keyword extraction) always run.
    /// AI steps only run when Apple Intelligence is available and enabled.
    /// Returns the number of tasks processed.
    func improveAllPendingTitles() async -> Int {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.needsTitleImprovement && !$0.isCompleted }
        )
        guard let tasks = try? modelContext.fetch(descriptor) else { return 0 }

        var improved = 0
        for task in tasks {
            await improveTitleIfNeeded(task)
            improved += 1
            try? await Task.sleep(for: .milliseconds(500))
        }
        return improved
    }

    // MARK: - Private: AI Enrichment (RW_1.4)

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func enrichWithSuggestions(_ task: LocalTask) async {
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
                await SmartTaskEnrichmentService.logTokenUsage(prompt: prompt, service: "TaskTitleEngine/Category")
            }
            let response = try await session.respond(to: prompt, generating: TaskSuggestion.self)
            let result = response.content

            let validCategories = ["income", "maintenance", "recharge", "learning", "giving_back"]
            if task.suggestedCategory == nil, validCategories.contains(result.category) {
                task.suggestedCategory = result.category
            }

            if task.suggestedDuration == nil, let minutes = Int(result.estimatedMinutes),
               [5, 15, 30, 60].contains(minutes) {
                task.suggestedDuration = minutes
            }
        } catch {
            print("[TaskTitleEngine] AI suggestion failed for '\(task.title)': \(error)")
        }
    }
    #endif
}
