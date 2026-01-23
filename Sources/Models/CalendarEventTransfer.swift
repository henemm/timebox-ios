import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let calendarEvent = UTType(exportedAs: "com.henning.timebox.calendarevent")
}

struct CalendarEventTransfer: Codable, Transferable, Sendable {
    let id: String
    let title: String
    let duration: Int
    let reminderID: String?

    init(from event: CalendarEvent) {
        self.id = event.id
        self.title = event.title
        self.duration = event.durationMinutes
        self.reminderID = event.reminderID
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .calendarEvent)
    }
}
