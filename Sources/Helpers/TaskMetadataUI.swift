import SwiftUI

/// Shared display properties for task importance levels.
/// Replaces duplicated switch statements across 5+ view files.
enum ImportanceUI {
    static func icon(for level: Int?) -> String {
        switch level {
        case 3: "exclamationmark.3"
        case 2: "exclamationmark.2"
        case 1: "exclamationmark"
        default: "questionmark"
        }
    }

    static func color(for level: Int?) -> Color {
        switch level {
        case 3: .red
        case 2: .yellow
        case 1: .blue
        default: .gray
        }
    }

    static func label(for level: Int?) -> String {
        switch level {
        case 3: "Hoch"
        case 2: "Mittel"
        case 1: "Niedrig"
        default: "Nicht gesetzt"
        }
    }
}

/// Shared display properties for task urgency values.
/// Replaces duplicated switch statements across 5+ view files.
enum UrgencyUI {
    static func icon(for urgency: String?) -> String {
        switch urgency {
        case "urgent": "flame.fill"
        case "not_urgent": "flame"
        default: "questionmark"
        }
    }

    static func color(for urgency: String?) -> Color {
        switch urgency {
        case "urgent": .orange
        default: .gray
        }
    }

    static func label(for urgency: String?) -> String {
        switch urgency {
        case "urgent": "Dringend"
        case "not_urgent": "Nicht dringend"
        default: "Nicht gesetzt"
        }
    }
}
