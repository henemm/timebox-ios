import Foundation
import SwiftData

/// Provides task title suggestions and duplicate detection for CreateTaskView.
/// Pure string matching — no AI dependency, <100ms response time.
@MainActor
final class TaskSuggestionService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Returns up to 5 matching task titles for the given input.
    /// Requires minimum 2 characters. Returns empty when feature is disabled.
    func suggestions(for input: String) async -> [TaskSuggestion] {
        guard AppSettings.shared.taskSuggestionsEnabled else { return [] }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let allTasks = fetchAllTasks()
        let query = trimmed.lowercased()

        // Score and sort: prefix matches first, then contains matches
        var scored: [(task: LocalTask, score: Int)] = []
        for task in allTasks {
            let titleLower = task.title.lowercased()
            if titleLower.hasPrefix(query) {
                scored.append((task, 2)) // prefix = higher priority
            } else if titleLower.contains(query) {
                scored.append((task, 1)) // contains = lower priority
            }
        }

        // Sort by score (desc), then by recency
        scored.sort { $0.score > $1.score }

        return Array(scored.prefix(5)).map { item in
            TaskSuggestion(
                id: item.task.uuid,
                title: item.task.title,
                isCompleted: item.task.isCompleted,
                completedAt: item.task.completedAt
            )
        }
    }

    /// Checks if a similar task already exists (>80% similarity).
    /// Uses both Levenshtein and containment scoring for robustness.
    /// Returns the best match or nil. Returns nil when feature is disabled.
    func findDuplicate(for title: String) async -> DuplicateMatch? {
        guard AppSettings.shared.taskSuggestionsEnabled else { return nil }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        let allTasks = fetchAllTasks()
        let query = trimmed.lowercased()

        var bestMatch: (task: LocalTask, similarity: Double)?

        for task in allTasks {
            let taskTitle = task.title.lowercased()
            // Use the higher of Levenshtein similarity or containment score
            let levenshtein = Self.similarity(query, taskTitle)
            let containment = Self.containmentSimilarity(query, taskTitle)
            let sim = max(levenshtein, containment)
            if sim > 0.8 {
                if bestMatch == nil || sim > bestMatch!.similarity {
                    bestMatch = (task, sim)
                }
            }
        }

        guard let match = bestMatch else { return nil }
        return DuplicateMatch(
            task: TaskSuggestion(
                id: match.task.uuid,
                title: match.task.title,
                isCompleted: match.task.isCompleted,
                completedAt: match.task.completedAt
            ),
            similarity: match.similarity
        )
    }

    // MARK: - Private

    private func fetchAllTasks() -> [LocalTask] {
        // Fetch all tasks (both incomplete and recently completed)
        var descriptor = FetchDescriptor<LocalTask>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        let allTasks = (try? modelContext.fetch(descriptor)) ?? []

        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return allTasks.filter { task in
            // Include incomplete tasks and tasks completed within last 90 days
            if !task.isCompleted { return true }
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= cutoff
        }
    }

    /// Containment similarity: if the shorter string is a prefix of the longer one,
    /// returns a high score based on the shorter string's proportion.
    /// "Zahnarzt Termin" is a prefix of "Zahnarzt Termin vereinbaren" → 0.85+
    /// This catches cases where a user adds more detail to an existing task title.
    static func containmentSimilarity(_ a: String, _ b: String) -> Double {
        let shorter = a.count <= b.count ? a : b
        let longer = a.count > b.count ? a : b
        if shorter.isEmpty { return 0.0 }
        // Prefix match: existing task is start of new input (or vice versa)
        if longer.hasPrefix(shorter) {
            // Scale: shorter/longer but boost since prefix is strong signal
            // "Zahnarzt Termin" (15) / "Zahnarzt Termin vereinbaren" (27) = 0.556
            // With boost: min(0.556 * 1.5, 1.0) = 0.833 → above 0.8 threshold
            return min(Double(shorter.count) / Double(longer.count) * 1.5, 1.0)
        }
        // Full containment (not prefix): weaker signal
        if longer.contains(shorter) {
            return Double(shorter.count) / Double(longer.count)
        }
        return 0.0
    }

    /// Normalized Levenshtein similarity (0.0 = completely different, 1.0 = identical)
    static func similarity(_ a: String, _ b: String) -> Double {
        let aChars = Array(a)
        let bChars = Array(b)
        let aLen = aChars.count
        let bLen = bChars.count

        if aLen == 0 && bLen == 0 { return 1.0 }
        if aLen == 0 || bLen == 0 { return 0.0 }

        // Levenshtein distance via dynamic programming
        var prev = Array(0...bLen)
        var curr = [Int](repeating: 0, count: bLen + 1)

        for i in 1...aLen {
            curr[0] = i
            for j in 1...bLen {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,      // deletion
                    curr[j - 1] + 1,   // insertion
                    prev[j - 1] + cost // substitution
                )
            }
            prev = curr
        }

        let maxLen = max(aLen, bLen)
        return 1.0 - Double(prev[bLen]) / Double(maxLen)
    }
}

// MARK: - Models

struct TaskSuggestion: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let completedAt: Date?
}

struct DuplicateMatch {
    let task: TaskSuggestion
    let similarity: Double
}
