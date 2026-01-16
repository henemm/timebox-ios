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

    // MARK: - Phase 1: Enhanced Task Fields

    @State private var duration: Int = 15
    @State private var urgency: String = "not_urgent"
    @State private var taskType: String = "maintenance"
    @State private var isRecurring: Bool = false
    @State private var taskDescription: String = ""

    var onSave: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task-Titel", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                // MARK: - Duration Section

                Section {
                    Stepper("Dauer: \(duration) min", value: $duration, in: 5...240, step: 5)
                } header: {
                    Text("Zeitbedarf")
                } footer: {
                    Text("Geschätzte Dauer für diese Aufgabe")
                }

                // MARK: - Priority Section

                Section {
                    Picker("Priorität", selection: $priority) {
                        Text("Keine").tag(0)
                        Text("Niedrig").tag(1)
                        Text("Mittel").tag(2)
                        Text("Hoch").tag(3)
                    }
                }

                // MARK: - Urgency Section

                Section {
                    Picker("Dringlichkeit", selection: $urgency) {
                        Text("Nicht dringend").tag("not_urgent")
                        Text("Dringend").tag("urgent")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Dringlichkeit")
                } footer: {
                    Text("Dringend = Deadline oder zeitkritisch")
                }

                // MARK: - Task Type Section

                Section {
                    Picker("Aufgabentyp", selection: $taskType) {
                        Label("Geld verdienen", systemImage: "dollarsign.circle").tag("income")
                        Label("Schneeschaufeln", systemImage: "wrench.and.screwdriver").tag("maintenance")
                        Label("Energie aufladen", systemImage: "battery.100").tag("recharge")
                    }
                } header: {
                    Text("Kategorie")
                }

                // MARK: - Category Section

                Section {
                    TextField("Kategorie (optional)", text: $category)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("Z.B. 'Hausarbeit', 'Recherche', 'Besorgungen'")
                }

                // MARK: - Due Date Section

                Section {
                    Toggle("Fälligkeitsdatum", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "Datum",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                // MARK: - Recurring Section

                Section {
                    Toggle("Wiederkehrende Aufgabe", isOn: $isRecurring)
                } footer: {
                    Text("Aufgabe bleibt nach Abschluss im Backlog")
                }

                // MARK: - Description Section

                Section {
                    TextEditor(text: $taskDescription)
                        .frame(minHeight: 100)
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
                    priority: priority,
                    duration: duration,
                    urgency: urgency,
                    taskType: taskType,
                    isRecurring: isRecurring,
                    description: taskDescription.isEmpty ? nil : taskDescription
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
