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

    // MARK: - Reason Category (Gruppen-Key)

    enum ReasonCategory: String {
        case deadline, stuck, important, priority, category, backlog
    }

    static func reasonCategory(for item: PlanItem, now: Date = Date()) -> ReasonCategory {
        if let due = item.dueDate {
            let days = Calendar.current.dateComponents([.day], from: now, to: due).day ?? 99
            if days <= 2 { return .deadline }
        }
        if item.rescheduleCount >= 3 { return .stuck }
        if item.importance == 3 { return .important }
        if let score = item.aiScore, score > 70 { return .priority }
        if TaskCategory(rawValue: item.taskType) != nil { return .category }
        return .backlog
    }

    static func groupReasonText(category: ReasonCategory, tasks: [PlanItem], now: Date = Date()) -> String {
        let count = tasks.count
        let totalMinutes = tasks.compactMap(\.estimatedDuration).reduce(0, +)
        let minuteHint = totalMinutes > 0 ? " Insgesamt \(totalMinutes) Minuten." : ""

        switch category {
        case .deadline:
            if count == 1, let due = tasks.first?.dueDate {
                let days = Calendar.current.dateComponents([.day], from: now, to: due).day ?? 0
                if days <= 0 { return "Deadline ist heute.\(minuteHint) Wenn du es jetzt erledigst, ist es vom Tisch — und du kannst morgen frei planen." }
                if days == 1 { return "Deadline morgen.\(minuteHint) Heute anfangen heißt morgen entspannt sein." }
                return "Deadline übermorgen.\(minuteHint) Wer vorarbeitet, hat den Kopf frei für Unerwartetes."
            }
            return "\(count) Aufgaben haben bald Deadline.\(minuteHint) Pack sie heute an — danach ist der Kopf frei."

        case .stuck:
            let maxCount = tasks.map(\.rescheduleCount).max() ?? 3
            if count == 1 {
                return "Diese Aufgabe schiebst du schon \(maxCount)x vor dir her.\(minuteHint) Heute durchziehen — danach ist sie Geschichte."
            }
            return "\(count) Aufgaben warten schon länger.\(minuteHint) Heute loszuwerden fühlt sich gut an."

        case .important:
            if count == 1 {
                return "Sehr wichtig.\(minuteHint) Was wichtig ist, verdient den frischesten Moment des Tages — also jetzt."
            }
            return "\(count) wichtige Aufgaben.\(minuteHint) Je früher erledigt, desto besser der Tag."

        case .priority:
            return "Hohe Priorität laut deinem Backlog.\(minuteHint) Heute ist ein guter Zeitpunkt."

        case .category:
            if let cat = TaskCategory(rawValue: tasks.first?.taskType ?? "") {
                return "\(cat.localizedName) — diese Kategorie kommt im Alltag oft zu kurz.\(minuteHint)"
            }
            return "Passt gut in deinen Tag.\(minuteHint)"

        case .backlog:
            let daysOld = tasks.compactMap { Calendar.current.dateComponents([.day], from: $0.createdAt, to: now).day }.max() ?? 0
            if daysOld > 14 {
                return "Seit über \(daysOld) Tagen im Backlog.\(minuteHint) Heute wäre der perfekte Tag, es anzupacken."
            }
            return "Offen im Backlog.\(minuteHint) Heute wäre ein guter Tag dafür."
        }
    }

    // MARK: - Reason Text

    static func reasonText(for item: PlanItem, now: Date = Date()) -> String {
        let duration = item.estimatedDuration.map { "\($0) Min" } ?? ""
        let catName = TaskCategory(rawValue: item.taskType)?.localizedName

        // Deadline innerhalb 48h — höchste Priorität
        if let due = item.dueDate {
            let days = Calendar.current.dateComponents([.day], from: now, to: due).day ?? 99
            if days <= 0 {
                return "Deadline ist heute\(duration.isEmpty ? "" : " (\(duration))"). Wenn du es heute erledigst, ist es vom Tisch — und du kannst morgen frei planen."
            }
            if days == 1 {
                return "Deadline morgen\(duration.isEmpty ? "" : " — geschätzt \(duration)"). Heute anfangen heißt morgen entspannt sein."
            }
            if days == 2 {
                return "Deadline in 2 Tagen. Wer vorarbeitet, hat den Kopf frei für Unerwartetes."
            }
        }

        // Oft verschoben — mit konkreter Ermutigung
        if item.rescheduleCount >= 5 {
            return "Schon \(item.rescheduleCount)x verschoben\(duration.isEmpty ? "" : ", aber nur \(duration)"). Heute durchziehen — danach ist es Geschichte."
        }
        if item.rescheduleCount >= 3 {
            return "\(item.rescheduleCount)x verschoben\(duration.isEmpty ? "" : " (\(duration))"). Kleine Aufgaben wachsen im Kopf — heute abhaken und Ballast loswerden."
        }

        // Hohe Wichtigkeit
        if item.importance == 3 {
            return "Sehr wichtig\(duration.isEmpty ? "" : " (\(duration))"). Was wichtig ist, verdient den frischesten Moment des Tages — also jetzt."
        }

        // Hoher AI-Score
        if let score = item.aiScore, score > 70 {
            return "Priorität \(score)/100 in deinem Backlog\(catName.map { " (\($0))" } ?? ""). Heute ist ein guter Tag, das anzugehen."
        }

        // Kategorie-basiert mit Kontext
        if let cat = catName {
            let durationHint = duration.isEmpty ? "" : " \(duration) reichen."
            return "\(cat) — diese Kategorie kommt in deinem Alltag oft zu kurz.\(durationHint)"
        }

        // Alter-basiert
        let daysOld = Calendar.current.dateComponents([.day], from: item.createdAt, to: now).day ?? 0
        if daysOld > 14 {
            return "Seit \(daysOld) Tagen im Backlog. Heute wäre der perfekte Tag, es endlich anzupacken."
        }

        return "Offen im Backlog\(duration.isEmpty ? "" : " (\(duration))") — heute wäre ein guter Tag dafür."
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
