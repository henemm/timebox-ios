import Foundation

// MARK: - NextUpSuggestion

struct NextUpSuggestion: Identifiable, Equatable {
    let id: String
    let planItem: PlanItem
    let slot: TimeSlot
    let score: Double

    static func == (lhs: NextUpSuggestion, rhs: NextUpSuggestion) -> Bool {
        lhs.id == rhs.id && lhs.score == rhs.score
    }
}

// MARK: - NextUpSuggestionService

enum NextUpSuggestionService {

    // MARK: - Cache

    private struct CacheEntry {
        let suggestions: [NextUpSuggestion]
        let date: Date
    }

    nonisolated(unsafe) private static var _cache: CacheEntry?

    // MARK: - Public API

    static func suggestions(
        items: [PlanItem],
        slots: [TimeSlot],
        profile: BehavioralProfile,
        calendarEvents: [CalendarEvent],
        now: Date = Date()
    ) -> [NextUpSuggestion] {
        if let cached = _cache,
           Calendar.current.isDate(cached.date, inSameDayAs: now) {
            return cached.suggestions
        }
        let result = compute(items: items, slots: slots, profile: profile,
                             calendarEvents: calendarEvents, now: now)
        _cache = CacheEntry(suggestions: result, date: now)
        return result
    }

    static func invalidateCache() {
        _cache = nil
    }

    // MARK: - Internal (testable)

    static func compute(
        items: [PlanItem],
        slots: [TimeSlot],
        profile: BehavioralProfile,
        calendarEvents: [CalendarEvent],
        now: Date
    ) -> [NextUpSuggestion] {
        let load = meetingLoadForToday(events: calendarEvents, date: now)
        let maxCount = maxSuggestionsForLoad(load)

        var usedIDs = Set<String>()
        var suggestions: [NextUpSuggestion] = []

        for slot in slots.sorted(by: { $0.startDate < $1.startDate }) {
            let candidates = items.filter { item in
                !item.isCompleted &&
                item.isActionable &&
                !item.isNextUp &&
                item.estimatedDuration != nil &&
                item.estimatedDuration! <= slot.durationMinutes &&
                !usedIDs.contains(item.id)
            }

            guard let best = candidates
                .map({ (item: $0, score: score(item: $0, slot: slot, profile: profile, now: now)) })
                .max(by: { $0.score < $1.score })
            else { continue }

            suggestions.append(NextUpSuggestion(
                id: best.item.id, planItem: best.item,
                slot: slot, score: best.score
            ))
            usedIDs.insert(best.item.id)

            if suggestions.count >= maxCount { break }
        }

        return suggestions
    }

    static func score(
        item: PlanItem,
        slot: TimeSlot,
        profile: BehavioralProfile,
        now: Date
    ) -> Double {
        let base = Double(item.priorityScore)
        let affinity = timeAffinityBonus(item: item, slot: slot, profile: profile)
        let reschedule = rescheduleBonus(count: item.rescheduleCount)
        return base * affinity * reschedule
    }

    static func meetingLoadForToday(events: [CalendarEvent], date: Date) -> MeetingLoad {
        let count = events.filter { !$0.isAllDay &&
            Calendar.current.isDate($0.startDate, inSameDayAs: date) }.count
        switch count {
        case 0...2: return .low
        case 3...4: return .medium
        default:    return .high
        }
    }

    static func maxSuggestionsForLoad(_ load: MeetingLoad) -> Int {
        switch load {
        case .low:    return 5
        case .medium: return 4
        case .high:   return 3
        }
    }

    // MARK: - Reason Text

    static func reasonText(for item: PlanItem, now: Date = Date()) -> String {
        // Deadline innerhalb 48h
        if let due = item.dueDate {
            let days = Calendar.current.dateComponents([.day], from: now, to: due).day ?? 99
            if days <= 0 { return "Deadline heute" }
            if days == 1 { return "Deadline morgen" }
            if days == 2 { return "Deadline übermorgen" }
        }

        // Oft verschoben
        if item.rescheduleCount >= 3 {
            return "Schon \(item.rescheduleCount)x verschoben"
        }

        // Hohe Wichtigkeit
        if item.importance == 3 {
            return "Sehr wichtig"
        }

        // Hoher AI-Score
        if let score = item.aiScore, score > 70 {
            return "Hohe Priorität"
        }

        // Fallback: Kategorie
        if let cat = TaskCategory(rawValue: item.taskType) {
            return "Guter Zeitpunkt für \(cat.localizedName)"
        }

        return "Im Backlog bereit"
    }

    // MARK: - Private Scoring

    private static func timeAffinityBonus(
        item: PlanItem, slot: TimeSlot, profile: BehavioralProfile
    ) -> Double {
        guard let affinity = profile.categoryTimeAffinity,
              let category = TaskCategory(rawValue: item.taskType) else { return 1.0 }
        let period = BehavioralProfileService.dayPeriod(for: slot.startDate)
        guard let value = affinity[category]?[period] else { return 1.0 }
        return 0.5 + value
    }

    private static func rescheduleBonus(count: Int) -> Double {
        switch count {
        case 0:    return 1.0
        case 1...2: return 1.1
        case 3...4: return 1.25
        default:   return 1.5
        }
    }
}
