import SwiftUI
import SwiftData

struct PlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var eventKitRepo = EventKitRepository()
    @State private var selectedDate = Date()
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var unscheduledTasks: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var scheduleFeedback = false

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
                        onScheduleTask: scheduleTask
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
            let syncEngine = SyncEngine(eventKitRepo: eventKitRepo, modelContext: modelContext)
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
                    endDate: endTime
                )

                // Reload data to show new event
                await loadData()
                scheduleFeedback.toggle()

            } catch {
                errorMessage = "Event konnte nicht erstellt werden."
            }
        }
    }
}
