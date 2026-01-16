import SwiftUI
import SwiftData

struct PlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.eventKitRepository) private var eventKitRepo
    @State private var selectedDate = Date()
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var unscheduledTasks: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var scheduleFeedback = false
    @State private var selectedEvent: CalendarEvent?
    @State private var showEventActions = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Lade Daten...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    ContentUnavailableView(
                        "Fehler",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    Spacer()
                } else {
                    TimelineView(
                        date: selectedDate,
                        events: calendarEvents,
                        onScheduleTask: scheduleTask,
                        onMoveEvent: moveEvent,
                        onEventTap: { event in
                            selectedEvent = event
                            showEventActions = true
                        },
                        onRefresh: loadData
                    )

                    if !unscheduledTasks.isEmpty {
                        Divider()
                        MiniBacklogView(tasks: unscheduledTasks)
                            .frame(height: 60)
                    }
                }
            }
            .navigationTitle("Planen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
            }
            .sensoryFeedback(.success, trigger: scheduleFeedback)
            .confirmationDialog(
                selectedEvent?.title ?? "Event",
                isPresented: $showEventActions,
                titleVisibility: .visible
            ) {
                if let event = selectedEvent {
                    if event.reminderID != nil {
                        Button("Unschedule (zurück in Backlog)") {
                            unscheduleEvent(event)
                        }
                    }
                    Button("Löschen", role: .destructive) {
                        deleteEvent(event)
                    }
                    Button("Abbrechen", role: .cancel) {}
                }
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedDate) {
            Task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Request both permissions
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                errorMessage = "Zugriff auf Kalender/Erinnerungen verweigert."
                isLoading = false
                return
            }

            // Load calendar events
            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: selectedDate)

            // Load unscheduled tasks
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            unscheduledTasks = try await syncEngine.sync()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func scheduleTask(_ transfer: PlanItemTransfer, at startTime: Date) {
        Task {
            do {
                let endTime = Calendar.current.date(
                    byAdding: .minute,
                    value: transfer.duration,
                    to: startTime
                ) ?? startTime

                try eventKitRepo.createCalendarEvent(
                    title: transfer.title,
                    startDate: startTime,
                    endDate: endTime,
                    reminderID: transfer.id
                )

                // Mark reminder as complete
                try eventKitRepo.markReminderComplete(reminderID: transfer.id)

                // Reload data to show new event
                await loadData()
                scheduleFeedback.toggle()

            } catch {
                errorMessage = "Event konnte nicht erstellt werden."
            }
        }
    }

    private func unscheduleEvent(_ event: CalendarEvent) {
        Task {
            do {
                // Delete the calendar event
                try eventKitRepo.deleteCalendarEvent(eventID: event.id)

                // Mark reminder as incomplete (back to backlog)
                if let reminderID = event.reminderID {
                    try eventKitRepo.markReminderIncomplete(reminderID: reminderID)
                }

                // Reload data
                await loadData()
                scheduleFeedback.toggle()

            } catch {
                errorMessage = "Event konnte nicht entfernt werden."
            }
        }
    }

    private func deleteEvent(_ event: CalendarEvent) {
        Task {
            do {
                try eventKitRepo.deleteCalendarEvent(eventID: event.id)
                await loadData()
                scheduleFeedback.toggle()
            } catch {
                errorMessage = "Event konnte nicht gelöscht werden."
            }
        }
    }

    private func moveEvent(_ transfer: CalendarEventTransfer, to newStartTime: Date) {
        Task {
            do {
                try eventKitRepo.moveCalendarEvent(
                    eventID: transfer.id,
                    to: newStartTime,
                    duration: transfer.duration
                )
                await loadData()
                scheduleFeedback.toggle()
            } catch {
                errorMessage = "Event konnte nicht verschoben werden."
            }
        }
    }
}
