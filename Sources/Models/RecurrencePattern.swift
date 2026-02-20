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
    case custom = "custom"

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
        case .custom:
            return "Eigene"
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

    /// Whether this pattern needs the custom configuration UI (base frequency + interval)
    var requiresCustomConfig: Bool {
        self == .custom
    }

    /// Base frequency options for custom pattern
    static let customBaseFrequencies: [(pattern: String, label: String, unit: String, unitPlural: String)] = [
        ("daily", "Täglich", "Tag", "Tage"),
        ("weekly", "Wöchentlich", "Woche", "Wochen"),
        ("monthly", "Monatlich", "Monat", "Monate"),
        ("yearly", "Jährlich", "Jahr", "Jahre"),
    ]

    /// Display text for custom interval, e.g. "Alle 3 Tage", "Jeden Tag"
    static func customDisplayName(basePattern: String, interval: Int) -> String {
        guard let freq = customBaseFrequencies.first(where: { $0.pattern == basePattern }) else {
            return "Eigene"
        }
        if interval == 1 {
            switch basePattern {
            case "daily": return "Jeden Tag"
            case "weekly": return "Jede Woche"
            case "monthly": return "Jeden Monat"
            case "yearly": return "Jedes Jahr"
            default: return freq.label
            }
        }
        return "Alle \(interval) \(freq.unitPlural)"
    }
}
