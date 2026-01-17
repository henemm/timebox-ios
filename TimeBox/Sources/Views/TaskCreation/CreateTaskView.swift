import SwiftUI
import SwiftData

struct CreateTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var priority = 1  // Default: Low
    @State private var isSaving = false

    // MARK: - Refactored Task Fields

    @State private var duration: Int = 15  // Quick select: 5, 15, 30, 60
    @State private var urgency: String = "not_urgent"
    @State private var taskType: String = "maintenance"
    @State private var recurrencePattern: RecurrencePattern = .none
    @State private var selectedWeekdays: Set<Int> = []
    @State private var monthDay: Int = 1
    @State private var taskDescription: String = ""

    var onSave: (() -> Void)?

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

                // MARK: - Priority (3 Levels)

                Section {
                    HStack(spacing: 12) {
                        QuickPriorityButton(priority: 1, selectedPriority: $priority)
                        QuickPriorityButton(priority: 2, selectedPriority: $priority)
                        QuickPriorityButton(priority: 3, selectedPriority: $priority)
                    }
                } header: {
                    Text("Priorität")
                }

                // MARK: - Urgency

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

                // MARK: - Task Type

                Section {
                    Picker("Aufgabentyp", selection: $taskType) {
                        Label("Geld verdienen", systemImage: "dollarsign.circle").tag("income")
                        Label("Schneeschaufeln", systemImage: "wrench.and.screwdriver").tag("maintenance")
                        Label("Energie aufladen", systemImage: "battery.100").tag("recharge")
                    }
                } header: {
                    Text("Typ")
                }

                // MARK: - Tags (Multi-Select)

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
                } footer: {
                    Text("Z.B. 'Hausarbeit', 'Recherche', 'Besorgungen'")
                }

                // MARK: - Due Date

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

                // MARK: - Recurrence (Pattern with Inline Expansion)

                Section {
                    Picker("Wiederholt sich", selection: $recurrencePattern) {
                        ForEach(RecurrencePattern.allCases) { pattern in
                            Text(pattern.displayName).tag(pattern)
                        }
                    }

                    // Inline expansion: Weekdays for weekly/biweekly
                    if recurrencePattern.requiresWeekdays {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("An folgenden Tagen:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                ForEach(Weekday.all) { weekday in
                                    WeekdayButton(weekday: weekday, selectedWeekdays: $selectedWeekdays)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Inline expansion: Month day for monthly
                    if recurrencePattern.requiresMonthDay {
                        Picker("Am Tag", selection: $monthDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day).").tag(day)
                            }
                            Text("Letzter Tag").tag(32)
                        }
                    }
                } header: {
                    Text("Wiederholung")
                }

                // MARK: - Description

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

                // Prepare recurrence data
                let weekdays: [Int]? = recurrencePattern.requiresWeekdays ? Array(selectedWeekdays).sorted() : nil
                let monthDay: Int? = recurrencePattern.requiresMonthDay ? self.monthDay : nil

                _ = try await taskSource.createTask(
                    title: title.trimmingCharacters(in: .whitespaces),
                    tags: tags,
                    dueDate: hasDueDate ? dueDate : nil,
                    priority: priority,
                    duration: duration,
                    urgency: urgency,
                    taskType: taskType,
                    recurrencePattern: recurrencePattern.rawValue,
                    recurrenceWeekdays: weekdays,
                    recurrenceMonthDay: monthDay,
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

// MARK: - Supporting Types (TODO: Extract to separate files when added to Xcode project)

/// Recurrence pattern options for recurring tasks
enum RecurrencePattern: String, CaseIterable, Identifiable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "Nie"
        case .daily:
            return "Täglich"
        case .weekly:
            return "Wöchentlich"
        case .biweekly:
            return "Zweiwöchentlich"
        case .monthly:
            return "Monatlich"
        }
    }

    var requiresWeekdays: Bool {
        self == .weekly || self == .biweekly
    }

    var requiresMonthDay: Bool {
        self == .monthly
    }
}

/// Quick duration selection button
struct QuickDurationButton: View {
    let minutes: Int
    @Binding var selectedMinutes: Int

    private var isSelected: Bool {
        selectedMinutes == minutes
    }

    var body: some View {
        Button {
            selectedMinutes = minutes
        } label: {
            Text("\(minutes)m")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemFill))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Quick priority selection button
struct QuickPriorityButton: View {
    let priority: Int
    @Binding var selectedPriority: Int

    private var isSelected: Bool {
        selectedPriority == priority
    }

    var displayName: String {
        switch priority {
        case 1: return "🟦 Niedrig"
        case 2: return "🟨 Mittel"
        case 3: return "🔴 Hoch"
        default: return ""
        }
    }

    var body: some View {
        Button {
            selectedPriority = priority
        } label: {
            Text(displayName)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemFill))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Weekday toggle button for recurrence selection
struct WeekdayButton: View {
    let weekday: Weekday
    @Binding var selectedWeekdays: Set<Int>

    private var isSelected: Bool {
        selectedWeekdays.contains(weekday.value)
    }

    var body: some View {
        Button {
            if isSelected {
                selectedWeekdays.remove(weekday.value)
            } else {
                selectedWeekdays.insert(weekday.value)
            }
        } label: {
            Text(weekday.shortName)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

/// Weekday representation for recurrence
struct Weekday: Identifiable {
    let value: Int  // 1=Mon, 2=Tue, ..., 7=Sun
    let shortName: String
    let fullName: String

    var id: Int { value }

    static let monday = Weekday(value: 1, shortName: "Mo", fullName: "Montag")
    static let tuesday = Weekday(value: 2, shortName: "Di", fullName: "Dienstag")
    static let wednesday = Weekday(value: 3, shortName: "Mi", fullName: "Mittwoch")
    static let thursday = Weekday(value: 4, shortName: "Do", fullName: "Donnerstag")
    static let friday = Weekday(value: 5, shortName: "Fr", fullName: "Freitag")
    static let saturday = Weekday(value: 6, shortName: "Sa", fullName: "Samstag")
    static let sunday = Weekday(value: 7, shortName: "So", fullName: "Sonntag")

    static let all: [Weekday] = [
        monday, tuesday, wednesday, thursday, friday, saturday, sunday
    ]
}
