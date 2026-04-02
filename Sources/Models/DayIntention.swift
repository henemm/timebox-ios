import Foundation
import SwiftData

@Model
final class DayIntention {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var text: String = ""
    var createdAt: Date = Date()

    init(date: Date, text: String) {
        self.uuid = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.text = text
        self.createdAt = Date()
    }
}
