import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generiert persönliche Begründungen für Coach-Vorschläge via Apple Intelligence.
/// Fallback auf deterministische `reasonText()` wenn AI nicht verfügbar.
enum AICoachReasonService {

    // MARK: - Availability

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - Cache

    private struct CacheEntry {
        let text: String
        let date: Date
    }

    nonisolated(unsafe) private static var _cache: [String: CacheEntry] = [:]

    static func invalidateCache() {
        _cache.removeAll()
    }

    // MARK: - Public API

    /// Liefert eine persönliche Begründung für einen Vorschlags-Task.
    /// Nutzt Apple Intelligence wenn verfügbar, sonst deterministischen Fallback.
    @MainActor
    static func reason(
        for item: PlanItem,
        slot: TimeSlot?,
        profile: BehavioralProfile?,
        allItems: [PlanItem]
    ) async -> String {
        let today = Calendar.current.startOfDay(for: Date())

        // Cache hit
        if let cached = _cache[item.id],
           Calendar.current.isDate(cached.date, inSameDayAs: today) {
            return cached.text
        }

        var text: String
        if isAvailable {
            text = await generateWithAI(for: item, slot: slot, profile: profile, allItems: allItems)
                ?? NextUpSuggestionService.reasonText(for: item)
        } else {
            text = NextUpSuggestionService.reasonText(for: item)
        }

        _cache[item.id] = CacheEntry(text: text, date: today)
        return text
    }

    // MARK: - AI Generation

    private static func generateWithAI(
        for item: PlanItem,
        slot: TimeSlot?,
        profile: BehavioralProfile?,
        allItems: [PlanItem]
    ) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }

        let prompt = buildPrompt(for: item, slot: slot, profile: profile, allItems: allItems)

        do {
            let session = LanguageModelSession {
                """
                Du bist ein knapper Produktivitäts-Coach.
                Erkläre in einem natürlichen deutschen Satz (max 15 Worte) \
                warum dieser Task JETZT für den User passt.
                Sei persönlich und ermutigend, nicht belehrend.
                Keine Floskeln, keine Aufzählungen.
                Antworte ausschließlich mit dem fertigen Satz.
                """
            }
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Prompt Building (testable)

    static func buildPrompt(
        for item: PlanItem,
        slot: TimeSlot?,
        profile: BehavioralProfile?,
        allItems: [PlanItem]
    ) -> String {
        var parts: [String] = []

        // Task-Grunddaten
        parts.append("Task: \(item.title)")
        if !item.taskType.isEmpty {
            parts.append("Kategorie: \(item.taskType)")
        }
        if let duration = item.estimatedDuration {
            parts.append("Geschätzte Dauer: \(duration) Minuten")
        }

        // Verschiebungen
        if item.rescheduleCount > 0 {
            parts.append("Bereits \(item.rescheduleCount)x verschoben")
        }

        // Energy-Level
        if let energy = item.aiEnergyLevel {
            parts.append("Energie-Anforderung: \(energy == "high" ? "Tiefenarbeit" : "Routine")")
        }

        // Tags + Cluster
        if !item.tags.isEmpty {
            parts.append("Tags: \(item.tags.joined(separator: ", "))")
            for tag in item.tags {
                let others = allItems.filter { $0.id != item.id && $0.tags.contains(tag) }
                if !others.isEmpty {
                    parts.append("\(others.count) weitere Tasks mit #\(tag) offen")
                }
            }
        }

        // Zeitfenster
        if let slot {
            parts.append("Freies Zeitfenster: \(slot.durationMinutes) Minuten")
            let hour = Calendar.current.component(.hour, from: slot.startDate)
            parts.append("Tageszeit: \(hour < 12 ? "morgens" : "nachmittags")")
        }

        // Verhaltensprofil — Zeitpräferenz
        if let profile, let affinity = profile.categoryTimeAffinity,
           let category = TaskCategory(rawValue: item.taskType),
           let periods = affinity[category] {
            if let bestPeriod = periods.max(by: { $0.value < $1.value }) {
                let periodName: String
                switch bestPeriod.key {
                case .morning: periodName = "morgens"
                case .afternoon: periodName = "nachmittags"
                case .evening: periodName = "abends"
                }
                let pct = Int(bestPeriod.value * 100)
                parts.append("User erledigt \(item.taskType) bevorzugt \(periodName) (\(pct)%)")
            }
        }

        return parts.joined(separator: "\n")
    }
}
