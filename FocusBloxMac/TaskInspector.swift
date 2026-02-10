//
//  TaskInspector.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI

/// Inspector panel for editing task details with iOS-style chip controls
struct TaskInspector: View {
    @Bindable var task: LocalTask
    @Environment(\.modelContext) private var modelContext
    var onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Title & Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    TextField("Titel", text: $task.title)
                        .font(.title3.weight(.semibold))
                        .textFieldStyle(.plain)

                    if let description = Binding($task.taskDescription) {
                        TextField("Beschreibung", text: description, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("+ Beschreibung hinzufügen") {
                            task.taskDescription = ""
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .font(.callout)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))

                // MARK: - Priority Section (Importance + Urgency)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Priorisierung")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        // Importance Chips
                        ForEach([1, 2, 3], id: \.self) { level in
                            importanceChip(level)
                        }
                    }

                    HStack(spacing: 12) {
                        // Urgency Chips
                        urgencyChip(nil, "?", "Ungesetzt", .gray)
                        urgencyChip("not_urgent", "flame", "Nicht dringend", .gray)
                        urgencyChip("urgent", "flame.fill", "Dringend", .orange)
                    }

                    if task.isTbd {
                        Label("Unvollständig - bitte alle Felder ausfüllen", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))

                // MARK: - Time Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Zeit")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Duration Chips
                    HStack(spacing: 8) {
                        Text("Dauer:")
                            .foregroundStyle(.secondary)

                        ForEach([5, 15, 30, 60], id: \.self) { mins in
                            durationChip(mins)
                        }
                    }

                    // Due Date
                    HStack {
                        Text("Fällig:")
                            .foregroundStyle(.secondary)

                        if task.dueDate != nil {
                            DatePicker("",
                                       selection: Binding(
                                           get: { task.dueDate ?? Date() },
                                           set: { task.dueDate = $0 }
                                       ),
                                       displayedComponents: .date)
                                .labelsHidden()

                            Button {
                                task.dueDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button("+ Datum setzen") {
                                task.dueDate = Date()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))

                // MARK: - Category Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kategorie")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Category Grid - nur die 5 definierten Kategorien
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        categoryChip("income", "Geld", "dollarsign.circle", .green)
                        categoryChip("maintenance", "Pflege", "wrench.and.screwdriver.fill", .orange)
                        categoryChip("recharge", "Energie", "battery.100", .cyan)
                        categoryChip("learning", "Lernen", "book", .purple)
                        categoryChip("giving_back", "Geben", "gift", .pink)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))

                // MARK: - Status Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Status")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        statusChip("Erledigt", "checkmark.circle.fill", task.isCompleted, .green) {
                            task.isCompleted.toggle()
                        }

                        statusChip("Next Up", "arrow.up.circle.fill", task.isNextUp, .blue) {
                            task.isNextUp.toggle()
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))

                // MARK: - Delete Button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Task löschen", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding()
        }
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

    // MARK: - Chip Views

    private func importanceChip(_ level: Int) -> some View {
        let isSelected = task.importance == level
        let color: Color = level == 3 ? .red : (level == 2 ? .yellow : .blue)
        let icon = level == 3 ? "exclamationmark.3" : (level == 2 ? "exclamationmark.2" : "exclamationmark")
        let label = level == 3 ? "Hoch" : (level == 2 ? "Mittel" : "Niedrig")

        return Button {
            task.importance = level
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.3) : Color.clear)
                    .stroke(color, lineWidth: isSelected ? 2 : 1)
            )
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("importanceChip_\(level)")
    }

    private func urgencyChip(_ value: String?, _ icon: String, _ label: String, _ color: Color) -> some View {
        let isSelected = task.urgency == value

        return Button {
            task.urgency = value
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.3) : Color.clear)
                    .stroke(color, lineWidth: isSelected ? 2 : 1)
            )
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("urgencyChip_\(value ?? "nil")")
    }

    private func durationChip(_ minutes: Int) -> some View {
        let isSelected = task.estimatedDuration == minutes

        return Button {
            task.estimatedDuration = minutes
        } label: {
            Text("\(minutes)m")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue.opacity(0.3) : Color.clear)
                        .stroke(Color.blue, lineWidth: isSelected ? 2 : 1)
                )
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("durationChip_\(minutes)")
    }

    private func categoryChip(_ id: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        let isSelected = task.taskType == id

        return Button {
            task.taskType = id
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.3) : Color.clear)
                    .stroke(color, lineWidth: isSelected ? 2 : 1)
            )
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("categoryChip_\(id)")
    }

    private func statusChip(_ label: String, _ icon: String, _ isActive: Bool, _ color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isActive ? icon : icon.replacingOccurrences(of: ".fill", with: ""))
                Text(label)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? color.opacity(0.3) : Color.clear)
                    .stroke(color, lineWidth: isActive ? 2 : 1)
            )
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
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
        .frame(width: 320)
}

#Preview("Empty State") {
    TaskInspectorEmptyState()
        .frame(width: 320)
}

#Preview("Multi-Selection") {
    TaskInspectorMultiSelection(count: 3)
        .frame(width: 320)
}
