//
//  MacPlanningView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData

/// Planning view with calendar timeline and next up tasks side by side
struct MacPlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<LocalTask> { $0.isNextUp && !$0.isCompleted },
           sort: \LocalTask.nextUpSortOrder)
    private var nextUpTasks: [LocalTask]

    @Binding var selectedDate: Date
    let onNavigateToBlock: (String) -> Void

    @State private var calendarEvents: [CalendarEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasCalendarAccess = false

    // Sheet state for editing block time
    @State private var blockToEdit: FocusBlock?

    // EventKit repository for real calendar access
    private let eventKitRepo = EventKitRepository()

    // Focus blocks extracted from calendar events
    private var focusBlocks: [FocusBlock] {
        calendarEvents.compactMap { FocusBlock(from: $0) }
    }

    // Free time slots for smart suggestions
    private var computedFreeSlots: [TimeSlot] {
        let finder = GapFinder(events: calendarEvents, focusBlocks: focusBlocks, date: selectedDate)
        return finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)
    }

    // Sheet state for creating new blocks from free slots
    @State private var selectedSlot: TimeSlot?

    var body: some View {
        HSplitView {
            // Left: Timeline
            timelineSection
                .frame(minWidth: 400)

            // Right: Next Up Tasks
            nextUpSection
                .frame(minWidth: 250, maxWidth: 350, maxHeight: .infinity)
        }
        .navigationTitle("Planen")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                MacDateNavigator(selectedDate: $selectedDate)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadCalendarEvents() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Aktualisieren")
            }
        }
        .task {
            await requestCalendarAccess()
        }
        .onChange(of: selectedDate) {
            Task { await loadCalendarEvents() }
        }
        .sheet(item: $blockToEdit) { block in
            EditFocusBlockSheet(
                block: block,
                onSave: { start, end in
                    updateBlockTime(block: block, start: start, end: end)
                },
                onDelete: {
                    deleteBlock(block: block)
                }
            )
        }
        .sheet(item: $selectedSlot) { slot in
            MacCreateFocusBlockSheet(
                slot: slot,
                onCreate: { start, end in
                    Task { await createFocusBlockFromSlot(start: start, end: end) }
                }
            )
        }
    }

    // MARK: - Timeline Section

    @ViewBuilder
    private var timelineSection: some View {
        if isLoading {
            ProgressView("Lade Kalender...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage {
            ContentUnavailableView(
                "Fehler",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !hasCalendarAccess {
            ContentUnavailableView(
                "Kalender-Zugriff erforderlich",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Bitte erlaube den Zugriff auf deinen Kalender in den Systemeinstellungen.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            MacTimelineView(
                date: selectedDate,
                events: calendarEvents,
                focusBlocks: focusBlocks,
                freeSlots: computedFreeSlots,
                onCreateFocusBlock: { startTime, duration, taskID in
                    Task { await createFocusBlock(at: startTime, duration: duration, taskID: taskID) }
                },
                onAddTaskToBlock: { blockID, taskID in
                    Task { await addTaskToBlock(blockID: blockID, taskID: taskID) }
                },
                onTapBlock: { block in
                    onNavigateToBlock(block.id)
                },
                onTapEditBlock: { block in
                    blockToEdit = block
                },
                onTapFreeSlot: { slot in
                    selectedSlot = slot
                }
            )
        }
    }

    // MARK: - Next Up Section

    private var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Next Up", systemImage: "arrow.up.circle.fill")
                    .font(.headline)
                Spacer()
                Text("\(nextUpTasks.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding()

            Divider()

            // Task List
            if nextUpTasks.isEmpty {
                ContentUnavailableView(
                    "Keine Tasks",
                    systemImage: "tray",
                    description: Text("Füge Tasks zu Next Up hinzu, um sie hier zu planen.")
                )
            } else {
                List {
                    ForEach(nextUpTasks, id: \.uuid) { task in
                        NextUpTaskRow(task: task)
                            .draggable(MacTaskTransfer(from: task))
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Info Footer
            Text("Tasks in die Timeline ziehen")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Calendar Access

    private func requestCalendarAccess() async {
        do {
            let granted = try await eventKitRepo.requestCalendarAccess()
            hasCalendarAccess = granted
            if granted {
                await loadCalendarEvents()
            } else {
                errorMessage = "Kalender-Zugriff verweigert"
            }
        } catch {
            hasCalendarAccess = false
            errorMessage = "Kalender-Zugriff verweigert"
        }
    }

    private func loadCalendarEvents(showSpinner: Bool = true) async {
        if showSpinner { isLoading = true }
        errorMessage = nil

        do {
            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: selectedDate)
            hasCalendarAccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        if showSpinner { isLoading = false }
    }

    // MARK: - Focus Block Actions

    private func createFocusBlock(at startTime: Date, duration: Int, taskID: String) async {
        do {
            // Calculate end time
            let endTime = Calendar.current.date(byAdding: .minute, value: duration, to: startTime) ?? startTime

            // Create focus block in calendar via EventKit
            let blockID = try eventKitRepo.createFocusBlock(startDate: startTime, endDate: endTime)

            // Add the task to the newly created block
            try eventKitRepo.updateFocusBlock(
                eventID: blockID,
                taskIDs: [taskID],
                completedTaskIDs: [],
                taskTimes: [:]
            )

            // Optimistic UI: add synthetic event to local array immediately
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let notes = FocusBlock.serializeToNotes(taskIDs: [taskID], completedTaskIDs: [])
            let syntheticEvent = CalendarEvent(
                id: blockID,
                title: "Focus Block \(formatter.string(from: startTime))",
                startDate: startTime,
                endDate: endTime,
                isAllDay: false,
                calendarColor: nil,
                notes: notes
            )
            calendarEvents.append(syntheticEvent)

            // Remove task from Next Up
            if let task = nextUpTasks.first(where: { $0.id == taskID }) {
                task.isNextUp = false
                try? modelContext.save()
            }

            // Background sync to get accurate calendar colors etc.
            await loadCalendarEvents(showSpinner: false)
        } catch {
            errorMessage = "Fehler beim Erstellen: \(error.localizedDescription)"
        }
    }

    private func addTaskToBlock(blockID: String, taskID: String) async {
        // Find the event to get current task list
        guard let eventIndex = calendarEvents.firstIndex(where: { $0.id == blockID }) else { return }
        let event = calendarEvents[eventIndex]

        var taskIDs = event.focusBlockTaskIDs

        // Don't add duplicate
        guard !taskIDs.contains(taskID) else { return }
        taskIDs.append(taskID)

        // Optimistic UI: update local event notes immediately
        let updatedNotes = FocusBlock.serializeToNotes(
            taskIDs: taskIDs,
            completedTaskIDs: event.focusBlockCompletedIDs,
            taskTimes: event.focusBlockTaskTimes
        )
        let updatedEvent = CalendarEvent(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarColor: event.calendarColor,
            notes: updatedNotes
        )
        calendarEvents[eventIndex] = updatedEvent

        // Remove task from Next Up immediately
        if let task = nextUpTasks.first(where: { $0.id == taskID }) {
            task.isNextUp = false
            try? modelContext.save()
        }

        // Persist to EventKit in background
        do {
            try eventKitRepo.updateFocusBlock(
                eventID: blockID,
                taskIDs: taskIDs,
                completedTaskIDs: event.focusBlockCompletedIDs,
                taskTimes: [:]
            )
        } catch {
            // Rollback on failure
            calendarEvents[eventIndex] = event
            errorMessage = "Fehler beim Zuweisen: \(error.localizedDescription)"
        }
    }

    // MARK: - Focus Block Edit Actions

    private func updateBlockTime(block: FocusBlock, start: Date, end: Date) {
        guard let index = calendarEvents.firstIndex(where: { $0.id == block.id }) else { return }

        let event = calendarEvents[index]
        let updatedEvent = CalendarEvent(
            id: event.id,
            title: event.title,
            startDate: start,
            endDate: end,
            isAllDay: event.isAllDay,
            calendarColor: event.calendarColor,
            notes: event.notes
        )

        calendarEvents[index] = updatedEvent
    }

    private func deleteBlock(block: FocusBlock) {
        calendarEvents.removeAll { $0.id == block.id }
    }

    private func createFocusBlockFromSlot(start: Date, end: Date) async {
        do {
            // Create focus block in calendar via EventKit
            _ = try eventKitRepo.createFocusBlock(startDate: start, endDate: end)

            // Reload to show new block
            await loadCalendarEvents()
        } catch {
            errorMessage = "Fehler beim Erstellen: \(error.localizedDescription)"
        }
    }
}

// MARK: - Create Focus Block Sheet (macOS)

struct MacCreateFocusBlockSheet: View {
    let slot: TimeSlot
    let onCreate: (Date, Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var startTime: Date
    @State private var endTime: Date

    init(slot: TimeSlot, onCreate: @escaping (Date, Date) -> Void) {
        self.slot = slot
        self.onCreate = onCreate
        _startTime = State(initialValue: slot.startDate)
        _endTime = State(initialValue: slot.endDate)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Focus Block erstellen")
                .font(.headline)

            Form {
                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                Text("Dauer: \(durationText)")
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)

            HStack {
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Erstellen") {
                    onCreate(startTime, endTime)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(endTime <= startTime)
            }
        }
        .padding()
        .frame(width: 350, height: 280)
    }

    private var durationText: String {
        let minutes = Int(endTime.timeIntervalSince(startTime) / 60)
        if minutes < 60 { return "\(minutes) Min" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "\(hours) Std" : "\(hours) Std \(rem) Min"
    }
}

// MARK: - Next Up Task Row

struct NextUpTaskRow: View {
    let task: LocalTask

    var body: some View {
        HStack(spacing: 10) {
            // Drag handle (visual indicator for future drag & drop)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let duration = task.estimatedDuration {
                        Label("\(duration) min", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    CategoryBadge(taskType: task.taskType)
                }
            }

            Spacer()

            if task.isTbd {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Date Navigator

/// Custom date navigation toolbar component with readable format
struct MacDateNavigator: View {
    @Binding var selectedDate: Date
    @State private var showDatePicker = false

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")

        if Calendar.current.isDateInToday(selectedDate) {
            return "Heute"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Gestern"
        } else if Calendar.current.isDateInTomorrow(selectedDate) {
            return "Morgen"
        } else {
            formatter.dateFormat = "E, d. MMM yyyy"
            return formatter.string(from: selectedDate)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Previous day
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("Vorheriger Tag")

            // Date display - tap to open calendar
            Button {
                showDatePicker.toggle()
            } label: {
                Text(dateText)
                    .font(.system(size: 13, weight: .medium))
                    .frame(minWidth: 100)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                VStack(spacing: 12) {
                    DatePicker(
                        "Datum",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                    Divider()

                    Button("Heute") {
                        selectedDate = Date()
                        showDatePicker = false
                    }
                    .buttonStyle(.link)
                }
                .padding()
                .frame(width: 280)
            }

            // Next day
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("Nächster Tag")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

#Preview {
    MacPlanningView(
        selectedDate: .constant(Date()),
        onNavigateToBlock: { _ in }
    )
    .frame(width: 800, height: 600)
}
