import Foundation

/// A Focus Block represents a time slot for focused work with assigned tasks
struct FocusBlock: Identifiable, Sendable {
    let id: String              // Calendar Event ID
    let title: String
    let startDate: Date
    let endDate: Date
    var taskIDs: [String]       // Ordered list of assigned task IDs
    var completedTaskIDs: [String]

    /// Check if block is currently active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }

    /// Check if block is in the past
    var isPast: Bool {
        Date() >= endDate
    }

    /// Check if block is in the future
    var isFuture: Bool {
        Date() < startDate
    }

    /// Duration in minutes
    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Create from CalendarEvent if it's a focus block
    init?(from event: CalendarEvent) {
        guard event.isFocusBlock else { return nil }

        self.id = event.id
        self.title = event.title
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.taskIDs = event.focusBlockTaskIDs
        self.completedTaskIDs = event.focusBlockCompletedIDs
    }

    /// Create a new focus block
    init(id: String, title: String, startDate: Date, endDate: Date, taskIDs: [String] = [], completedTaskIDs: [String] = []) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.taskIDs = taskIDs
        self.completedTaskIDs = completedTaskIDs
    }
}

// MARK: - Notes Serialization

extension FocusBlock {
    /// Serialize focus block metadata to notes string
    /// Format:
    /// focusBlock:true
    /// tasks:id1|id2|id3
    /// completed:id1
    static func serializeToNotes(taskIDs: [String], completedTaskIDs: [String]) -> String {
        var lines = ["focusBlock:true"]

        if !taskIDs.isEmpty {
            lines.append("tasks:\(taskIDs.joined(separator: "|"))")
        }

        if !completedTaskIDs.isEmpty {
            lines.append("completed:\(completedTaskIDs.joined(separator: "|"))")
        }

        return lines.joined(separator: "\n")
    }

    /// Generate notes string for this block
    var notesString: String {
        Self.serializeToNotes(taskIDs: taskIDs, completedTaskIDs: completedTaskIDs)
    }
}
