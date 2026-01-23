import Foundation
import SwiftData

/// Metadata for tasks synced from external sources (e.g., Apple Reminders).
/// Note: CloudKit requires all attributes to have default values.
@Model
final class TaskMetadata {
    var reminderID: String = ""
    var sortOrder: Int = 0
    var manualDuration: Int?

    init(reminderID: String, sortOrder: Int) {
        self.reminderID = reminderID
        self.sortOrder = sortOrder
        self.manualDuration = nil
    }
}
