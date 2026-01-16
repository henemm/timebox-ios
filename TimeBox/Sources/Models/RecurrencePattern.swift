import Foundation

/// Recurrence pattern options for recurring tasks
enum RecurrencePattern: String, CaseIterable, Identifiable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "Nie"
        case .daily:
            return "Täglich"
        case .weekly:
            return "Wöchentlich"
        case .biweekly:
            return "Zweiwöchentlich"
        case .monthly:
            return "Monatlich"
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
