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

    init(from block: FocusBlock) {
        self.id = block.id
        self.title = block.title
        self.duration = block.durationMinutes
        self.reminderID = nil
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .calendarEvent)
    }
}
