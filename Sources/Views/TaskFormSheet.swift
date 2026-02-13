import SwiftUI
import SwiftData

/// Unified Task Form for both creating and editing tasks.
/// Uses the same design for native FocusBlox tasks and imported Apple Reminders.
struct TaskFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Mode

    enum Mode {
        case create
        case edit(PlanItem)

        var title: String {
            switch self {
            case .create: return "Neuer Task"
            case .edit: return "Task bearbeiten"
            }
        }
    }

    let mode: Mode
    let onSave: ((String, TaskPriority, Int?, [String], String?, String, Date?, String?, String, [Int]?, Int?) -> Void)?
    let onDelete: (() -> Void)?
    var onCreateComplete: (() -> Void)?

    // MARK: - State

    @State private var title = ""
    @State private var priority: Int? = nil  // nil = TBD (not set)
    @State private var duration: Int? = nil  // nil = TBD (not set)
    @State private var tags: [String] = []
    @State private var urgency: String? = nil  // nil = TBD (not set)
    @State private var taskType: String = ""  // Empty = TBD (not set)
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var taskDescription: String = ""
    @State private var isSaving = false

    // Recurrence State
    @State private var recurrencePattern: RecurrencePattern = .none
    @State private var selectedWeekdays: Set<Int> = []
    @State private var monthDay: Int = 1

    // MARK: - Initializers

    /// Create mode initializer
    init(onComplete: (() -> Void)? = nil) {
        self.mode = .create
        self.onSave = nil
        self.onDelete = nil
        self.onCreateComplete = onComplete
    }

    /// Edit mode initializer
    init(task: PlanItem,
         onSave: @escaping (String, TaskPriority, Int?, [String], String?, String, Date?, String?, String, [Int]?, Int?) -> Void,
         onDelete: @escaping () -> Void) {
        self.mode = .edit(task)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCreateComplete = nil

        // Initialize state from task - preserve nil for TBD fields
        _title = State(initialValue: task.title)
        _priority = State(initialValue: task.importance)  // Keep nil if task is TBD
        _duration = State(initialValue: task.estimatedDuration)  // Keep nil if task is TBD
        _tags = State(initialValue: task.tags)
        _urgency = State(initialValue: task.urgency)  // Keep nil if task is TBD
        _taskType = State(initialValue: task.taskType)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
        _taskDescription = State(initialValue: task.taskDescription ?? "")

        // Initialize recurrence state from task
        _recurrencePattern = State(initialValue: RecurrencePattern(rawValue: task.recurrencePattern ?? "none") ?? .none)
        _selectedWeekdays = State(initialValue: Set(task.recurrenceWeekdays ?? []))
        _monthDay = State(initialValue: task.recurrenceMonthDay ?? 1)
    }

    // MARK: - Task Type Options

    private let taskTypeOptions = TaskCategory.allCases.map { ($0.rawValue, $0.displayName, $0.icon) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Title
                    glassCardSection(id: "title") {
                        TextField("Task-Titel", text: $title)
                            .font(.title3.weight(.medium))
                            .accessibilityIdentifier("taskTitle")
                    }

                    // MARK: - Duration (Quick Select) - all unselected by default
                    glassCardSection(id: "duration", header: "Dauer") {
                        HStack(spacing: 8) {
                            OptionalDurationButton(minutes: 5, selectedMinutes: $duration)
                            OptionalDurationButton(minutes: 15, selectedMinutes: $duration)
                            OptionalDurationButton(minutes: 30, selectedMinutes: $duration)
                            OptionalDurationButton(minutes: 60, selectedMinutes: $duration)
                        }
                    }

                    // MARK: - Importance (3 Levels) - all unselected by default
                    glassCardSection(id: "importance", header: "Wichtigkeit") {
                        HStack(spacing: 6) {
                            OptionalPriorityButton(priority: 1, selectedPriority: $priority)
                            OptionalPriorityButton(priority: 2, selectedPriority: $priority)
                            OptionalPriorityButton(priority: 3, selectedPriority: $priority)
                        }
                        .accessibilityIdentifier("Wichtigkeit")
                    }

                    // MARK: - Urgency - Flame Toggle (like BacklogRow badge)
                    glassCardSection(id: "urgency", header: "Dringlichkeit") {
                        Button {
                            // Cycle: nil → not_urgent → urgent → nil
                            switch urgency {
                            case nil: urgency = "not_urgent"
                            case "not_urgent": urgency = "urgent"
                            case "urgent": urgency = nil
                            default: urgency = nil
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: urgencyIcon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(urgencyColor)
                                Text(urgencyLabel)
                                    .foregroundStyle(urgencyColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(urgencyColor.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .medium), trigger: urgency)
                        .accessibilityIdentifier("urgencyFlameToggle")

                        Text("Dringend = Deadline oder zeitkritisch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // MARK: - Task Type - Horizontal Chip Row (like BacklogRow categoryBadge)
                    glassCardSection(id: "type", header: "Typ") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(taskTypeOptions, id: \.0) { value, label, icon in
                                    Button {
                                        taskType = value
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: icon)
                                                .font(.system(size: 14))
                                            Text(label)
                                                .font(.caption)
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(categoryColor(for: value))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(categoryColor(for: value).opacity(taskType == value ? 0.3 : 0.15))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(taskType == value ? categoryColor(for: value) : .clear, lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("taskTypeChip_\(value)")
                                }
                            }
                        }
                        .accessibilityIdentifier("taskTypeChipRow")
                    }

                    // MARK: - Tags
                    glassCardSection(id: "tags", header: "Tags") {
                        TagInputView(tags: $tags)
                    }

                    // MARK: - Due Date
                    glassCardSection(id: "dueDate", header: "Fälligkeit") {
                        Toggle("Fälligkeitsdatum", isOn: $hasDueDate)
                            .accessibilityIdentifier("Fälligkeitsdatum")
                        if hasDueDate {
                            DatePicker(
                                "Datum",
                                selection: $dueDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }

                    // MARK: - Recurrence
                    glassCardSection(id: "recurrence", header: "Wiederholung") {
                        Picker("Wiederholt sich", selection: $recurrencePattern) {
                            ForEach(RecurrencePattern.allCases) { pattern in
                                Text(pattern.displayName).tag(pattern)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("recurrencePicker")

                        // Inline: Weekdays for weekly/biweekly
                        if recurrencePattern.requiresWeekdays {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("An folgenden Tagen:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    ForEach(Weekday.all) { weekday in
                                        WeekdayButton(weekday: weekday, selectedWeekdays: $selectedWeekdays)
                                            .accessibilityIdentifier("weekdayButton_\(weekday.value)")
                                    }
                                }
                            }
                        }

                        // Inline: Month day for monthly
                        if recurrencePattern.requiresMonthDay {
                            Picker("Am Tag", selection: $monthDay) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day).").tag(day)
                                }
                                Text("Letzter Tag").tag(32)
                            }
                            .accessibilityIdentifier("monthDayPicker")
                        }
                    }

                    // MARK: - Description
                    glassCardSection(id: "description", header: "Beschreibung (optional)") {
                        TextEditor(text: $taskDescription)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .accessibilityIdentifier("Beschreibung")
                            .overlay(alignment: .topLeading) {
                                if taskDescription.isEmpty {
                                    Text("Notizen zur Aufgabe...")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    // MARK: - Delete (Edit mode only)
                    if case .edit = mode, let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("Task löschen", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                }
                .padding()
            }
            .accessibilityIdentifier("taskFormScrollView")
            .background(Color(.systemGroupedBackground))
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Urgency Helper Properties

    private var urgencyIcon: String {
        switch urgency {
        case "urgent": return "flame.fill"
        case "not_urgent": return "flame"
        default: return "questionmark"  // TBD
        }
    }

    private var urgencyColor: Color {
        switch urgency {
        case "urgent": return .orange
        case "not_urgent": return .gray
        default: return .gray  // TBD
        }
    }

    private var urgencyLabel: String {
        switch urgency {
        case "urgent": return "Dringend"
        case "not_urgent": return "Nicht dringend"
        default: return "Nicht gesetzt"  // TBD
        }
    }

    // MARK: - Category Color Helper

    private func categoryColor(for type: String) -> Color {
        TaskCategory(rawValue: type)?.color ?? .gray
    }

    // MARK: - Glass Card Section Helper

    @ViewBuilder
    private func glassCardSection<Content: View>(
        id: String,
        header: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header {
                Text(header)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .accessibilityIdentifier("taskFormSection_\(id)")
    }

    // MARK: - Save

    private func saveTask() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSaving = true

        let finalDueDate: Date? = hasDueDate ? dueDate : nil
        let finalDescription: String? = taskDescription.isEmpty ? nil : taskDescription
        let taskPriority: TaskPriority = priority.flatMap { TaskPriority(rawValue: $0) } ?? .medium

        switch mode {
        case .create:
            // Prepare recurrence data
            let weekdays: [Int]? = recurrencePattern.requiresWeekdays ? Array(selectedWeekdays).sorted() : nil
            let monthDayValue: Int? = recurrencePattern.requiresMonthDay ? monthDay : nil

            Task {
                do {
                    let taskSource = LocalTaskSource(modelContext: modelContext)
                    _ = try await taskSource.createTask(
                        title: title.trimmingCharacters(in: .whitespaces),
                        tags: tags,
                        dueDate: finalDueDate,
                        importance: priority,
                        estimatedDuration: duration,
                        urgency: urgency,
                        taskType: taskType,
                        recurrencePattern: recurrencePattern.rawValue,
                        recurrenceWeekdays: weekdays,
                        recurrenceMonthDay: monthDayValue,
                        description: finalDescription
                    )

                    await MainActor.run {
                        onCreateComplete?()
                        dismiss()
                    }
                } catch {
                    isSaving = false
                }
            }

        case .edit:
            // Prepare recurrence data
            let weekdays: [Int]? = recurrencePattern.requiresWeekdays ? Array(selectedWeekdays).sorted() : nil
            let monthDayValue: Int? = recurrencePattern.requiresMonthDay ? monthDay : nil

            onSave?(
                title.trimmingCharacters(in: .whitespaces),
                taskPriority,
                duration,
                tags,
                urgency,
                taskType,
                finalDueDate,
                finalDescription,
                recurrencePattern.rawValue,
                weekdays,
                monthDayValue
            )
            dismiss()
        }
    }
}

#Preview("Create Mode") {
    TaskFormSheet()
        .modelContainer(for: LocalTask.self, inMemory: true)
}
