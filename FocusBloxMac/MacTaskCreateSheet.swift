import SwiftUI
import SwiftData

struct MacTaskCreateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onComplete: (() -> Void)?

    @State private var title = ""
    @State private var duration: Int? = nil
    @State private var importance: Int? = nil
    @State private var urgency: String? = nil
    @State private var taskType: String = ""
    @State private var tags: [String] = []
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var taskDescription = ""
    @State private var isSaving = false

    private let taskTypeOptions = TaskCategory.allCases.map { ($0.rawValue, $0.displayName, $0.icon) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Titel") {
                    TextField("Was gibt es zu tun?", text: $title)
                        .accessibilityIdentifier("taskTitle")
                }

                Section("Metadaten") {
                    Picker("Dauer", selection: Binding(
                        get: { duration ?? 0 },
                        set: { duration = $0 == 0 ? nil : $0 }
                    )) {
                        Text("Nicht gesetzt").tag(0)
                        Text("5 Min").tag(5)
                        Text("15 Min").tag(15)
                        Text("30 Min").tag(30)
                        Text("60 Min").tag(60)
                    }

                    Picker("Wichtigkeit", selection: Binding(
                        get: { importance ?? 0 },
                        set: { importance = $0 == 0 ? nil : $0 }
                    )) {
                        Text("Nicht gesetzt").tag(0)
                        Text("Niedrig").tag(1)
                        Text("Mittel").tag(2)
                        Text("Hoch").tag(3)
                    }

                    Picker("Dringlichkeit", selection: Binding(
                        get: { urgency ?? "" },
                        set: { urgency = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Nicht gesetzt").tag("")
                        Text("Nicht dringend").tag("not_urgent")
                        Text("Dringend").tag("urgent")
                    }

                    Picker("Typ", selection: $taskType) {
                        Text("Nicht gesetzt").tag("")
                        ForEach(taskTypeOptions, id: \.0) { value, label, icon in
                            Label(label, systemImage: icon).tag(value)
                        }
                    }
                }

                Section("Tags") {
                    TagInputView(tags: $tags)
                }

                Section("Fälligkeit") {
                    Toggle("Fälligkeitsdatum", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Datum", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Beschreibung") {
                    TextEditor(text: $taskDescription)
                        .frame(minHeight: 60)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Abbrechen") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Erstellen") {
                    saveTask()
                }
                .accessibilityIdentifier("createTaskButton")
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
            .padding()
        }
        .frame(minWidth: 450, minHeight: 500)
        .accessibilityIdentifier("taskFormScrollView")
    }

    private func saveTask() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let finalDueDate: Date? = hasDueDate ? dueDate : nil
        let finalDescription: String? = taskDescription.isEmpty ? nil : taskDescription
        let capturedTags = tags
        let capturedImportance = importance
        let capturedDuration = duration
        let capturedUrgency = urgency
        let capturedTaskType = taskType
        let capturedContext = modelContext

        onComplete?()
        dismiss()

        Task {
            let taskSource = LocalTaskSource(modelContext: capturedContext)
            _ = try? await taskSource.createTask(
                title: trimmedTitle,
                tags: capturedTags,
                dueDate: finalDueDate,
                importance: capturedImportance,
                estimatedDuration: capturedDuration,
                urgency: capturedUrgency,
                taskType: capturedTaskType,
                description: finalDescription
            )
        }
    }
}
