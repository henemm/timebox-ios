import SwiftUI

struct TaskDetailSheet: View {
    let task: PlanItem
    let onSave: (String, Int?, Int?, [String], String?, String, Date?, String?, String, [Int]?, Int?, Int?) -> Void
    let onDelete: () -> Void

    @State private var showEditSheet = false
    @Environment(\.dismiss) private var dismiss

    private var priorityText: String {
        switch task.importance {
        case 1: return "Niedrig"
        case 2: return "Mittel"
        case 3: return "Hoch"
        default: return "Unbekannt"
        }
    }

    private var priorityColor: Color {
        switch task.importance {
        case 1: return .blue
        case 2: return .yellow
        case 3: return .red
        default: return .gray
        }
    }

    private var urgencyText: String {
        task.urgency == "urgent" ? "Dringend" : "Nicht dringend"
    }

    private var categoryText: String {
        TaskCategory(rawValue: task.taskType)?.displayName ?? task.taskType.capitalized
    }

    var body: some View {
        NavigationStack {
            List {
                // Header with Title + Priority
                Section {
                    titleSection
                }

                // Category + Urgency
                Section("Einordnung") {
                    categorySection
                }

                // Tags
                if !task.tags.isEmpty {
                    Section("Tags") {
                        tagsSection
                    }
                }

                // Due Date + Duration
                Section("Zeit") {
                    timeSection
                }

                // Description
                if let desc = task.taskDescription, !desc.isEmpty {
                    Section("Notizen") {
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Bearbeiten") {
                        showEditSheet = true
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                TaskFormSheet(
                    task: task,
                    onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay, recurrenceInterval in
                        onSave(title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay, recurrenceInterval)
                        dismiss()
                    },
                    onDelete: {
                        onDelete()
                        dismiss()
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Title Section

    private var titleSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(priorityColor)
                .frame(width: 12, height: 12)

            Text(task.title)
                .font(.headline)

            Spacer()

            Text(priorityText)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(priorityColor.opacity(0.15))
                .foregroundStyle(priorityColor)
                .clipShape(Capsule())
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Kategorie", systemImage: "folder")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(categoryText)
            }

            Divider()
                .padding(.vertical, 8)

            HStack {
                Label("Dringlichkeit", systemImage: task.urgency == "urgent" ? "exclamationmark.circle" : "clock")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(urgencyText)
                    .foregroundStyle(task.urgency == "urgent" ? .red : .primary)
            }
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        FlowLayout(spacing: 8) {
            ForEach(task.tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Dauer", systemImage: "clock")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(task.effectiveDuration) min")
                    .foregroundStyle(task.durationSource == .default ? .secondary : .primary)
            }

            if let dueDate = task.dueDate {
                Divider()
                    .padding(.vertical, 8)

                HStack {
                    Label("Fällig", systemImage: "calendar")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(dueDate.dueDateText(style: .full))
                        .foregroundStyle(dueDate.isDueToday ? .red : .primary)
                }
            }
        }
    }

}

// FlowLayout is defined in TagInputView.swift (shared between iOS and macOS)
