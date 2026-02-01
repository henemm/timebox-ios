//
//  TaskInspector.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI

/// Inspector panel for editing task details
struct TaskInspector: View {
    @Bindable var task: LocalTask
    @Environment(\.modelContext) private var modelContext
    var onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false

    // Computed binding for optional Int importance
    private var importanceBinding: Binding<Int> {
        Binding(
            get: { task.importance ?? 1 },
            set: { task.importance = $0 }
        )
    }

    // Computed binding for duration with default
    private var durationBinding: Binding<Int> {
        Binding(
            get: { task.estimatedDuration ?? 15 },
            set: { task.estimatedDuration = $0 }
        )
    }

    // Computed binding for urgency
    private var isUrgent: Binding<Bool> {
        Binding(
            get: { task.urgency == "urgent" },
            set: { task.urgency = $0 ? "urgent" : "not_urgent" }
        )
    }

    var body: some View {
        Form {
            Section("Task") {
                TextField("Titel", text: $task.title)
                    .font(.headline)

                if let description = Binding($task.taskDescription) {
                    TextField("Beschreibung", text: description, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    Button("Beschreibung hinzufügen") {
                        task.taskDescription = ""
                    }
                }
            }

            Section("Priorisierung") {
                Picker("Wichtigkeit", selection: importanceBinding) {
                    Text("Niedrig").tag(1)
                    Text("Mittel").tag(2)
                    Text("Hoch").tag(3)
                }

                Toggle("Dringend", isOn: isUrgent)

                if task.isTbd {
                    Label("Unvollständig - bitte alle Felder ausfüllen", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            Section("Zeit") {
                Stepper("Dauer: \(durationBinding.wrappedValue) min",
                        value: durationBinding,
                        in: 5...180,
                        step: 5)

                DatePicker("Fällig",
                           selection: Binding(
                               get: { task.dueDate ?? Date() },
                               set: { task.dueDate = $0 }
                           ),
                           displayedComponents: .date)

                if task.dueDate != nil {
                    Button("Fälligkeitsdatum entfernen", role: .destructive) {
                        task.dueDate = nil
                    }
                    .font(.caption)
                }
            }

            Section("Kategorie") {
                Picker("Typ", selection: $task.taskType) {
                    Label("Geld verdienen", systemImage: "dollarsign.circle").tag("income")
                    Label("Pflege", systemImage: "wrench.and.screwdriver.fill").tag("maintenance")
                    Label("Energie", systemImage: "battery.100").tag("recharge")
                    Label("Lernen", systemImage: "book").tag("learning")
                    Label("Weitergeben", systemImage: "gift").tag("giving_back")
                    Label("Deep Work", systemImage: "brain").tag("deep_work")
                    Label("Shallow Work", systemImage: "tray").tag("shallow_work")
                    Label("Meetings", systemImage: "person.2").tag("meetings")
                    Label("Kreativ", systemImage: "paintbrush").tag("creative")
                    Label("Strategie", systemImage: "lightbulb").tag("strategic")
                }
            }

            Section("Status") {
                Toggle("Erledigt", isOn: $task.isCompleted)
                Toggle("Next Up", isOn: $task.isNextUp)
            }

            Section {
                Button("Task löschen", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Details")
        .confirmationDialog("Task löschen?",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                onDelete?()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }
}

// MARK: - Empty State

struct TaskInspectorEmptyState: View {
    var body: some View {
        ContentUnavailableView(
            "Kein Task ausgewählt",
            systemImage: "sidebar.right",
            description: Text("Wähle einen Task aus der Liste, um Details zu sehen.")
        )
    }
}

// MARK: - Multi-Selection State

struct TaskInspectorMultiSelection: View {
    let count: Int
    var onSetCategory: ((String) -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("\(count) Tasks ausgewählt")
                .font(.headline)

            Divider()

            VStack(spacing: 12) {
                Text("Bulk-Aktionen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Menu("Kategorie setzen") {
                    Button("Geld verdienen") { onSetCategory?("income") }
                    Button("Pflege") { onSetCategory?("maintenance") }
                    Button("Energie") { onSetCategory?("recharge") }
                    Button("Lernen") { onSetCategory?("learning") }
                    Button("Weitergeben") { onSetCategory?("giving_back") }
                    Divider()
                    Button("Deep Work") { onSetCategory?("deep_work") }
                    Button("Shallow Work") { onSetCategory?("shallow_work") }
                    Button("Meetings") { onSetCategory?("meetings") }
                    Button("Kreativ") { onSetCategory?("creative") }
                    Button("Strategie") { onSetCategory?("strategic") }
                }
                .buttonStyle(.bordered)

                Button("Ausgewählte löschen", role: .destructive) {
                    onDelete?()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

#Preview("Inspector") {
    TaskInspector(task: LocalTask(title: "Sample Task", importance: 2, estimatedDuration: 30))
        .frame(width: 300)
}

#Preview("Empty State") {
    TaskInspectorEmptyState()
        .frame(width: 300)
}

#Preview("Multi-Selection") {
    TaskInspectorMultiSelection(count: 3)
        .frame(width: 300)
}
