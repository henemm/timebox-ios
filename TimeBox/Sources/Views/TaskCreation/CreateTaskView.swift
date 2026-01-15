import SwiftUI
import SwiftData

struct CreateTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var priority = 0
    @State private var isSaving = false

    var onSave: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task-Titel", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section {
                    TextField("Kategorie (optional)", text: $category)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Toggle("Faelligkeitsdatum", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "Datum",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section {
                    Picker("Prioritaet", selection: $priority) {
                        Text("Keine").tag(0)
                        Text("Niedrig").tag(1)
                        Text("Mittel").tag(2)
                        Text("Hoch").tag(3)
                    }
                }
            }
            .navigationTitle("Neuer Task")
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
    }

    private func saveTask() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSaving = true

        Task {
            do {
                let taskSource = LocalTaskSource(modelContext: modelContext)
                _ = try await taskSource.createTask(
                    title: title.trimmingCharacters(in: .whitespaces),
                    category: category.isEmpty ? nil : category,
                    dueDate: hasDueDate ? dueDate : nil,
                    priority: priority
                )

                await MainActor.run {
                    onSave?()
                    dismiss()
                }
            } catch {
                isSaving = false
            }
        }
    }
}

#Preview {
    CreateTaskView()
        .modelContainer(for: LocalTask.self, inMemory: true)
}
