import Foundation
import SwiftData

@Model
final class TaskMetadata {
    @Attribute(.unique) var reminderID: String
    var sortOrder: Int
    var manualDuration: Int?

    init(reminderID: String, sortOrder: Int) {
        self.reminderID = reminderID
        self.sortOrder = sortOrder
        self.manualDuration = nil
    }
}
