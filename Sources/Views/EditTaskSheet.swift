import SwiftUI
import SwiftData

struct EditTaskSheet: View {
    let task: PlanItem
    let onSave: (String, Int?, Int?, [String], String?, String, Date?, String?) -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var priority: TaskPriority
    @State private var duration: Int
    @State private var tags: [String]
    @State private var urgency: String?
    @State private var taskType: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var taskDescription: String
    @Environment(\.dismiss) private var dismiss

    private let urgencyOptions: [(String?, String)] = [
        (nil, "Nicht gesetzt"),
        ("not_urgent", "Nicht dringend"),
        ("urgent", "Dringend")
    ]

    private let taskTypeOptions = TaskCategory.allCases.map { ($0.rawValue, $0.displayName) }

    init(task: PlanItem, onSave: @escaping (String, Int?, Int?, [String], String?, String, Date?, String?) -> Void, onDelete: @escaping () -> Void) {
        self.task = task
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: task.title)
        _priority = State(initialValue: task.priority)
        _duration = State(initialValue: task.effectiveDuration)
        _tags = State(initialValue: task.tags)
        _urgency = State(initialValue: task.urgency)
        _taskType = State(initialValue: task.taskType)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
        _taskDescription = State(initialValue: task.taskDescription ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Basis
                Section("Task") {
                    TextField("Titel", text: $title)
                }

                Section("Details") {
                    Picker("Wichtigkeit", selection: $priority) {
                        Text("Niedrig").tag(TaskPriority.low)
                        Text("Mittel").tag(TaskPriority.medium)
                        Text("Hoch").tag(TaskPriority.high)
                    }
                    .accessibilityIdentifier("Wichtigkeit")

                    Stepper("Dauer: \(duration) min", value: $duration, in: 5...180, step: 5)
                }

                // MARK: - Kategorisierung
                Section("Kategorisierung") {
                    TagInputView(tags: $tags)

                    Picker("Dringlichkeit", selection: $urgency) {
                        ForEach(urgencyOptions, id: \.1) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .accessibilityIdentifier("Dringlichkeit")

                    Picker("Typ", selection: $taskType) {
                        ForEach(taskTypeOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .accessibilityIdentifier("Typ")
                }

                // MARK: - Zeitplanung
                Section("Zeitplanung") {
                    Toggle("Fälligkeitsdatum", isOn: $hasDueDate)
                        .accessibilityIdentifier("Fälligkeitsdatum")

                    if hasDueDate {
                        DatePicker(
                            "Datum",
                            selection: $dueDate,
                            displayedComponents: [.date]
                        )
                    }
                }

                // MARK: - Beschreibung
                Section("Beschreibung") {
                    TextEditor(text: $taskDescription)
                        .frame(minHeight: 80)
                        .accessibilityIdentifier("Beschreibung")
                }

                // MARK: - Löschen
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Task löschen", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Task bearbeiten")
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
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func saveTask() {
        let finalDueDate: Date? = hasDueDate ? dueDate : nil
        let finalDescription: String? = taskDescription.isEmpty ? nil : taskDescription

        onSave(
            title,
            priority.rawValue,
            duration,
            tags,
            urgency,
            taskType,
            finalDueDate,
            finalDescription
        )
    }
}
