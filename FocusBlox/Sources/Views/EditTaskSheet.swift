import SwiftUI

struct EditTaskSheet: View {
    let task: PlanItem
    let onSave: (String, TaskPriority, Int) -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var priority: TaskPriority
    @State private var duration: Int
    @Environment(\.dismiss) private var dismiss

    init(task: PlanItem, onSave: @escaping (String, TaskPriority, Int) -> Void, onDelete: @escaping () -> Void) {
        self.task = task
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: task.title)
        _priority = State(initialValue: task.priority)
        _duration = State(initialValue: task.effectiveDuration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Titel", text: $title)
                }

                Section("Details") {
                    Picker("Priorität", selection: $priority) {
                        Text("Niedrig").tag(TaskPriority.low)
                        Text("Mittel").tag(TaskPriority.medium)
                        Text("Hoch").tag(TaskPriority.high)
                    }

                    Stepper("Dauer: \(duration) min", value: $duration, in: 5...180, step: 5)
                }

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
                        onSave(title, priority, duration)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
