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

    @State private var selectedDate = Date()
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasCalendarAccess = false

    // Focus blocks extracted from calendar events
    private var focusBlocks: [FocusBlock] {
        calendarEvents.compactMap { FocusBlock(from: $0) }
    }

    var body: some View {
        HSplitView {
            // Left: Timeline
            timelineSection
                .frame(minWidth: 400)

            // Right: Next Up Tasks
            nextUpSection
                .frame(minWidth: 250, maxWidth: 350)
        }
        .navigationTitle("Planen")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
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
        } else if !hasCalendarAccess {
            ContentUnavailableView(
                "Kalender-Zugriff erforderlich",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Bitte erlaube den Zugriff auf deinen Kalender in den Systemeinstellungen.")
            )
        } else {
            MacTimelineView(
                date: selectedDate,
                events: calendarEvents,
                focusBlocks: focusBlocks,
                onCreateFocusBlock: { startTime, duration, taskID in
                    Task { await createFocusBlock(at: startTime, duration: duration, taskID: taskID) }
                },
                onAddTaskToBlock: { blockID, taskID in
                    Task { await addTaskToBlock(blockID: blockID, taskID: taskID) }
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
        // For now, we'll use a simple check
        // In production, this would use EventKit's requestAccess
        do {
            // Try to load events - this will trigger permission dialog
            await loadCalendarEvents()
            hasCalendarAccess = true
        } catch {
            hasCalendarAccess = false
            errorMessage = "Kalender-Zugriff verweigert"
        }
    }

    private func loadCalendarEvents() async {
        isLoading = true
        errorMessage = nil

        // Simulate loading calendar events
        // In production, this would use EventKitRepository
        do {
            try await Task.sleep(for: .milliseconds(300))

            // For now, create sample events to show the UI works
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: selectedDate)

            // Sample events for demonstration
            calendarEvents = [
                CalendarEvent(
                    id: "sample-1",
                    title: "Team Meeting",
                    startDate: calendar.date(byAdding: .hour, value: 9, to: today)!,
                    endDate: calendar.date(byAdding: .hour, value: 10, to: today)!,
                    isAllDay: false,
                    calendarColor: nil,
                    notes: nil
                ),
                CalendarEvent(
                    id: "sample-2",
                    title: "Lunch",
                    startDate: calendar.date(byAdding: .hour, value: 12, to: today)!,
                    endDate: calendar.date(byAdding: .hour, value: 13, to: today)!,
                    isAllDay: false,
                    calendarColor: nil,
                    notes: nil
                ),
                CalendarEvent(
                    id: "focus-1",
                    title: "Deep Work",
                    startDate: calendar.date(byAdding: .hour, value: 14, to: today)!,
                    endDate: calendar.date(byAdding: .hour, value: 16, to: today)!,
                    isAllDay: false,
                    calendarColor: nil,
                    notes: "focusBlock:true\ntasks:task1|task2"
                )
            ]

            hasCalendarAccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Focus Block Actions

    private func createFocusBlock(at startTime: Date, duration: Int, taskID: String) async {
        // Calculate end time
        let endTime = Calendar.current.date(byAdding: .minute, value: duration, to: startTime) ?? startTime

        // Create new focus block event
        let newBlock = CalendarEvent(
            id: UUID().uuidString,
            title: "Focus Block",
            startDate: startTime,
            endDate: endTime,
            isAllDay: false,
            calendarColor: nil,
            notes: FocusBlock.serializeToNotes(taskIDs: [taskID], completedTaskIDs: [])
        )

        // Add to calendar events (in production, this would use EventKit)
        calendarEvents.append(newBlock)

        // Remove task from Next Up
        if let task = nextUpTasks.first(where: { $0.id == taskID }) {
            task.isNextUp = false
            try? modelContext.save()
        }
    }

    private func addTaskToBlock(blockID: String, taskID: String) async {
        // Find the event and update its notes
        guard let index = calendarEvents.firstIndex(where: { $0.id == blockID }) else { return }

        let event = calendarEvents[index]
        var taskIDs = event.focusBlockTaskIDs

        // Don't add duplicate
        guard !taskIDs.contains(taskID) else { return }
        taskIDs.append(taskID)

        // Update the event with new task list
        let updatedEvent = CalendarEvent(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarColor: event.calendarColor,
            notes: FocusBlock.serializeToNotes(taskIDs: taskIDs, completedTaskIDs: event.focusBlockCompletedIDs)
        )

        calendarEvents[index] = updatedEvent

        // Remove task from Next Up
        if let task = nextUpTasks.first(where: { $0.id == taskID }) {
            task.isNextUp = false
            try? modelContext.save()
        }
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

#Preview {
    MacPlanningView()
        .frame(width: 800, height: 600)
}
