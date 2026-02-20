import SwiftUI

/// Read-only preview of all task attributes for Long Press context menu.
/// Used by NextUpRow and DraggableTaskRow to show hidden attributes.
struct TaskPreviewView: View {
    let task: PlanItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            Text(task.title)
                .font(.headline)
                .lineLimit(3)

            // Attribute badges
            HStack(spacing: 8) {
                // Importance
                Label(ImportanceUI.label(for: task.importance),
                      systemImage: ImportanceUI.icon(for: task.importance))
                    .font(.caption)
                    .foregroundStyle(ImportanceUI.color(for: task.importance))

                // Urgency
                Label(UrgencyUI.label(for: task.urgency),
                      systemImage: UrgencyUI.icon(for: task.urgency))
                    .font(.caption)
                    .foregroundStyle(UrgencyUI.color(for: task.urgency))
            }

            HStack(spacing: 8) {
                // Category
                let category = TaskCategory(rawValue: task.taskType)
                Label(category?.displayName ?? task.taskType.capitalized,
                      systemImage: category?.icon ?? "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(category?.color ?? .gray)

                // Duration
                Label("\(task.effectiveDuration) min", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            // Recurrence
            if let pattern = task.recurrencePattern, pattern != "none" {
                Label(RecurrencePattern(rawValue: pattern)?.displayName ?? pattern,
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }

            // Tags
            if !task.tags.isEmpty {
                Text(task.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Due Date
            if let dueDate = task.dueDate {
                Label(dueDate.dueDateText(), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(dueDate.isDueToday ? .red : .secondary)
            }

            // Description
            if let desc = task.taskDescription, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(width: 260)
    }
}
