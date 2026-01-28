import AppIntents

/// Importance level for Eisenhower Matrix (maps to LocalTask.importance Int)
enum TaskImportanceEnum: String, AppEnum {
    case low
    case medium
    case high

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Wichtigkeit")

    static let caseDisplayRepresentations: [TaskImportanceEnum: DisplayRepresentation] = [
        .low: "Niedrig",
        .medium: "Mittel",
        .high: "Hoch"
    ]

    /// Maps to LocalTask.importance Int value (1/2/3)
    var intValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    init?(intValue: Int) {
        switch intValue {
        case 1: self = .low
        case 2: self = .medium
        case 3: self = .high
        default: return nil
        }
    }
}

/// Urgency for Eisenhower Matrix (maps to LocalTask.urgency String)
enum TaskUrgencyEnum: String, AppEnum {
    case urgent
    case notUrgent

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dringlichkeit")

    static let caseDisplayRepresentations: [TaskUrgencyEnum: DisplayRepresentation] = [
        .urgent: "Dringend",
        .notUrgent: "Nicht dringend"
    ]

    /// Maps to LocalTask.urgency String value
    var stringValue: String {
        switch self {
        case .urgent: return "urgent"
        case .notUrgent: return "not_urgent"
        }
    }

    init?(stringValue: String) {
        switch stringValue {
        case "urgent": self = .urgent
        case "not_urgent": self = .notUrgent
        default: return nil
        }
    }
}

/// Task category (maps to LocalTask.taskType String)
enum TaskCategoryEnum: String, AppEnum {
    case income
    case maintenance
    case recharge
    case learning
    case givingBack

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Kategorie")

    static let caseDisplayRepresentations: [TaskCategoryEnum: DisplayRepresentation] = [
        .income: "Einkommen",
        .maintenance: "Pflege",
        .recharge: "Aufladen",
        .learning: "Lernen",
        .givingBack: "Zurueckgeben"
    ]

    /// Maps to LocalTask.taskType String value
    var stringValue: String {
        switch self {
        case .income: return "income"
        case .maintenance: return "maintenance"
        case .recharge: return "recharge"
        case .learning: return "learning"
        case .givingBack: return "giving_back"
        }
    }

    init?(stringValue: String) {
        switch stringValue {
        case "income": self = .income
        case "maintenance": self = .maintenance
        case "recharge": self = .recharge
        case "learning": self = .learning
        case "giving_back": self = .givingBack
        default: return nil
        }
    }
}
