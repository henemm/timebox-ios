import Foundation

/// Recurrence pattern options for recurring tasks
enum RecurrencePattern: String, CaseIterable, Identifiable {
    case none = "none"
    case daily = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case semiannually = "semiannually"
    case yearly = "yearly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "Nie"
        case .daily:
            return "Täglich"
        case .weekdays:
            return "An Wochentagen"
        case .weekends:
            return "An Wochenenden"
        case .weekly:
            return "Wöchentlich"
        case .biweekly:
            return "Alle 2 Wochen"
        case .monthly:
            return "Monatlich"
        case .quarterly:
            return "Alle 3 Monate"
        case .semiannually:
            return "Alle 6 Monate"
        case .yearly:
            return "Jährlich"
        }
    }

    /// Whether this pattern requires weekday selection
    var requiresWeekdays: Bool {
        self == .weekly || self == .biweekly
    }

    /// Whether this pattern requires month day selection
    var requiresMonthDay: Bool {
        self == .monthly
    }
}
