import Foundation
import EventKit

/// Simple struct representing a reminder list's display info
/// Used instead of EKCalendar to enable easier mocking
struct ReminderListInfo: Identifiable, Sendable {
    let id: String           // calendarIdentifier
    let title: String        // List name (e.g., "Arbeit", "Privat")
    let colorHex: String?    // Optional color for display

    init(id: String, title: String, colorHex: String? = nil) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
    }

    init(from calendar: EKCalendar) {
        self.id = calendar.calendarIdentifier
        self.title = calendar.title
        // Convert CGColor to hex string
        if let cgColor = calendar.cgColor {
            let color = cgColor.components ?? [0, 0, 0, 1]
            let r = Int(color[0] * 255)
            let g = Int(color[1] * 255)
            let b = Int(color[2] * 255)
            self.colorHex = String(format: "#%02X%02X%02X", r, g, b)
        } else {
            self.colorHex = nil
        }
    }
}
