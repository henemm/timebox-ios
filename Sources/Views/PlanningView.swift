import SwiftUI
import SwiftData

struct PlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.eventKitRepository) private var eventKitRepo
    @State private var selectedDate = Date()
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var scheduledTasks: [TimelineItem] = []
    @State private var unscheduledTasks: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isPermissionDenied = false
    @State private var scheduleFeedback = false
    @State private var selectedEvent: CalendarEvent?
    @State private var showEventActions = false
    @State private var focusSprintFeedback = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Lade Daten...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            isPermissionDenied ? "Berechtigung erforderlich" : "Fehler",
                            systemImage: isPermissionDenied ? "lock.shield" : "exclamationmark.triangle",
                            description: Text(error)
                        )

                        if isPermissionDenied {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Einstellungen öffnen", systemImage: "gear")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    Spacer()
                } else {
                    TimelineView(
                        date: selectedDate,
                        events: calendarEvents,
                        scheduledTasks: scheduledTasks,
                        onScheduleTask: scheduleTask,
                        onMoveEvent: moveEvent,
                        onEventTap: { event in
                            selectedEvent = event
                            showEventActions = true
                        },
                        onUnscheduleTask: { taskID in
                            unscheduleTask(taskID)
                        },
                        onStartFocusSprint: { taskID in
                            startFocusSprint(taskID)
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
            .sensoryFeedback(.success, trigger: focusSprintFeedback)
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedDate) {
            Task {
                await loadData()
            }
        }
        .errorAlert(message: $errorMessage)
    }

    private func loadData() async {
        isLoading = true
        isPermissionDenied = false

        do {
            // Request both permissions
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                errorMessage = "Zugriff auf Kalender/Erinnerungen verweigert. Bitte in den Einstellungen aktivieren."
                isPermissionDenied = true
                isLoading = false
                return
            }

            // Load calendar events
            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: selectedDate)

            // Load tasks via SyncEngine
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            let allTasks = try await syncEngine.sync()

            // Split: scheduled tasks for timeline, unscheduled for backlog
            let dayStart = Calendar.current.startOfDay(for: selectedDate)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

            scheduledTasks = allTasks
                .filter { $0.isScheduled && $0.scheduledDate! >= dayStart && $0.scheduledDate! < dayEnd }
                .map { item in
                    TimelineItem(
                        scheduledTaskID: item.id,
                        title: item.title,
                        scheduledDate: item.scheduledDate!,
                        durationMinutes: item.scheduledDuration ?? item.estimatedDuration ?? 30
                    )
                }

            unscheduledTasks = allTasks.filter { !$0.isScheduled }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func scheduleTask(_ transfer: PlanItemTransfer, at startTime: Date) {
        Task {
            do {
                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                try syncEngine.scheduleTask(
                    itemID: transfer.id,
                    date: startTime,
                    duration: transfer.duration
                )
                await SmartNotificationEngine.reconcile(
                    reason: .taskChanged, context: modelContext, eventKitRepo: eventKitRepo
                )

                await loadData()
                scheduleFeedback.toggle()

            } catch {
                errorMessage = "Task konnte nicht eingeplant werden."
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

    private func unscheduleTask(_ taskID: String) {
        Task {
            do {
                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                try syncEngine.unscheduleTask(itemID: taskID)
                await SmartNotificationEngine.reconcile(
                    reason: .taskChanged, context: modelContext, eventKitRepo: eventKitRepo
                )

                await loadData()
                scheduleFeedback.toggle()

            } catch {
                errorMessage = "Task konnte nicht entplant werden."
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

    private func startFocusSprint(_ taskID: String) {
        Task {
            do {
                _ = try FocusBlockActionService.startImmediate(
                    taskID: taskID,
                    eventKitRepo: eventKitRepo,
                    modelContext: modelContext
                )
                await loadData()
                focusSprintFeedback.toggle()
            } catch {
                errorMessage = "Focus Sprint konnte nicht gestartet werden."
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
