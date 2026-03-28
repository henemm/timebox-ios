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

    /// Removes known urgency/deadline keywords from task titles.
    /// Runs synchronously — no AI needed. Handles parenthesized and prefix formats.
    static func stripKeywords(_ title: String) -> String {
        var cleaned = title

        // Parenthesized keywords: "(dringend)", "(urgent)", "(ASAP)", "(sofort)"
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*\(\s*(?:dringend|urgent|asap|sofort|eilig)\s*\)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Prefix keywords: "dringend:", "urgent:", "ASAP:"
        cleaned = cleaned.replacingOccurrences(
            of: #"^(?:dringend|urgent|asap|sofort|eilig)\s*:\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
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
    /// RW_1.4: Title is cleaned deterministically, AI only suggests category + duration.
    func improveTitleIfNeeded(_ task: LocalTask) async {
        guard AppSettings.shared.aiScoringEnabled else { return }
        guard task.needsTitleImprovement else { return }

        // Preserve original title in description (if description is empty)
        if task.taskDescription == nil || task.taskDescription?.isEmpty == true {
            task.taskDescription = task.title
        }

        // Step 1: Deterministic title cleanup (always runs, no AI needed)
        task.title = Self.cleanTitle(task.title)

        // Step 2: Deterministic urgency extraction
        let originalTitle = task.taskDescription ?? task.title
        if task.urgency == nil {
            let lower = originalTitle.lowercased()
            let urgencyKeywords = ["dringend", "urgent", "asap", "sofort", "eilig"]
            if urgencyKeywords.contains(where: { lower.contains($0) }) {
                task.urgency = "urgent"
            }
        }

        // Step 3: Deterministic date extraction
        if task.dueDate == nil,
           Self.titleContainsDateKeyword(originalTitle),
           let date = Self.extractDeterministicDueDate(from: originalTitle) {
            task.dueDate = date
        }

        // Step 3: AI suggestions for category + duration (if available)
        if Self.isAvailable {
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
    /// Returns the number of tasks processed.
    func improveAllPendingTitles() async -> Int {
        guard Self.isAvailable else { return 0 }
        guard AppSettings.shared.aiScoringEnabled else { return 0 }

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
                "Categorize tasks and estimate duration."
                "Categories: income (work/career/money), maintenance (household/errands/health), recharge (exercise/hobbies/rest), learning (study/reading/courses), giving_back (family/friends/social)"
                "Duration: 5 (quick call/message), 15 (short errand), 30 (medium task), 60 (long/deep work)"
            }

            let prompt = "Task: \(task.title)"
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
