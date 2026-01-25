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
    let onSave: ((String, TaskPriority, Int, [String], String, String, Date?, String?) -> Void)?
    let onDelete: (() -> Void)?
    var onCreateComplete: (() -> Void)?

    // MARK: - State

    @State private var title = ""
    @State private var priority = 2  // Default: Medium
    @State private var duration: Int = 15
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var urgency: String = "not_urgent"
    @State private var taskType: String = "maintenance"
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var taskDescription: String = ""
    @State private var isSaving = false

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
         onSave: @escaping (String, TaskPriority, Int, [String], String, String, Date?, String?) -> Void,
         onDelete: @escaping () -> Void) {
        self.mode = .edit(task)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCreateComplete = nil

        // Initialize state from task
        _title = State(initialValue: task.title)
        _priority = State(initialValue: task.importance ?? 2)
        _duration = State(initialValue: task.effectiveDuration)
        _tags = State(initialValue: task.tags)
        _urgency = State(initialValue: task.urgency ?? "not_urgent")
        _taskType = State(initialValue: task.taskType)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
        _taskDescription = State(initialValue: task.taskDescription ?? "")
    }

    // MARK: - Task Type Options

    private let taskTypeOptions = [
        ("income", "Geld verdienen", "dollarsign.circle"),
        ("maintenance", "Schneeschaufeln", "wrench.and.screwdriver"),
        ("recharge", "Energie aufladen", "battery.100"),
        ("learning", "Lernen", "book"),
        ("giving_back", "Weitergeben", "gift"),
        ("deep_work", "Deep Work", "brain"),
        ("shallow_work", "Shallow Work", "tray"),
        ("meetings", "Meetings", "person.2"),
        ("creative", "Kreativ", "paintbrush"),
        ("strategic", "Strategisch", "map")
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Title
                Section {
                    TextField("Task-Titel", text: $title)
                }

                // MARK: - Duration (Quick Select)
                Section {
                    HStack(spacing: 12) {
                        QuickDurationButton(minutes: 5, selectedMinutes: $duration)
                        QuickDurationButton(minutes: 15, selectedMinutes: $duration)
                        QuickDurationButton(minutes: 30, selectedMinutes: $duration)
                        QuickDurationButton(minutes: 60, selectedMinutes: $duration)
                    }
                } header: {
                    Text("Dauer")
                }

                // MARK: - Importance (3 Levels)
                Section {
                    HStack(spacing: 12) {
                        QuickPriorityButton(priority: 1, selectedPriority: $priority)
                        QuickPriorityButton(priority: 2, selectedPriority: $priority)
                        QuickPriorityButton(priority: 3, selectedPriority: $priority)
                    }
                    .accessibilityIdentifier("Wichtigkeit")
                } header: {
                    Text("Wichtigkeit")
                }

                // MARK: - Urgency
                Section {
                    Picker("Dringlichkeit", selection: $urgency) {
                        Text("Nicht dringend").tag("not_urgent")
                        Text("Dringend").tag("urgent")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("Dringlichkeit")
                } header: {
                    Text("Dringlichkeit")
                } footer: {
                    Text("Dringend = Deadline oder zeitkritisch")
                }

                // MARK: - Task Type
                Section {
                    Picker("Aufgabentyp", selection: $taskType) {
                        ForEach(taskTypeOptions, id: \.0) { value, label, icon in
                            Label(label, systemImage: icon).tag(value)
                        }
                    }
                    .accessibilityIdentifier("Typ")
                } header: {
                    Text("Typ")
                }

                // MARK: - Tags
                Section {
                    if !tags.isEmpty {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField("Neuer Tag", text: $newTag)
                            .accessibilityIdentifier("Tags")
                        Button("Hinzufügen") {
                            let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !tags.contains(trimmed) {
                                tags.append(trimmed)
                                newTag = ""
                            }
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Tags")
                }

                // MARK: - Due Date
                Section {
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

                // MARK: - Description
                Section {
                    TextEditor(text: $taskDescription)
                        .frame(minHeight: 80)
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
                } header: {
                    Text("Beschreibung (optional)")
                }

                // MARK: - Delete (Edit mode only)
                if case .edit = mode, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("Task löschen", systemImage: "trash")
                        }
                    }
                }
            }
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

    // MARK: - Save

    private func saveTask() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSaving = true

        let finalDueDate: Date? = hasDueDate ? dueDate : nil
        let finalDescription: String? = taskDescription.isEmpty ? nil : taskDescription
        let taskPriority = TaskPriority(rawValue: priority) ?? .medium

        switch mode {
        case .create:
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
                        recurrencePattern: "none",
                        recurrenceWeekdays: nil,
                        recurrenceMonthDay: nil,
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
            onSave?(
                title.trimmingCharacters(in: .whitespaces),
                taskPriority,
                duration,
                tags,
                urgency,
                taskType,
                finalDueDate,
                finalDescription
            )
            dismiss()
        }
    }
}

#Preview("Create Mode") {
    TaskFormSheet()
        .modelContainer(for: LocalTask.self, inMemory: true)
}
