import SwiftData
import SwiftUI

// MARK: - Day Phase

enum DayPhase: Equatable {
    case morning
    case daytime
    case evening

    /// Determines the current phase from a given hour and settings.
    /// - Parameters:
    ///   - hour: Hour of day (0-23)
    ///   - morningEnd: Hour when morning ends (exclusive)
    ///   - eveningStart: Hour when evening starts (inclusive)
    static func from(hour: Int, morningEnd: Int, eveningStart: Int) -> DayPhase {
        if hour < morningEnd { return .morning }
        if hour < eveningStart { return .daytime }
        return .evening
    }
}

// MARK: - Day View

struct DayView: View {
    @AppStorage("morningEndHour") private var morningEndHour = 12
    @AppStorage("eveningStartHour") private var eveningStartHour = 18
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(\.modelContext) private var modelContext

    @State private var calendarEvents: [CalendarEvent] = []
    @State private var focusBlocks: [FocusBlock] = []
    @State private var nextUpTasks: [PlanItem] = []
    @State private var freeSlots: [TimeSlot] = []
    @State private var isLoading = false
    @State private var isPermissionDenied = false

    private var phase: DayPhase {
        let hour = Calendar.current.component(.hour, from: Date())
        return DayPhase.from(hour: hour, morningEnd: morningEndHour, eveningStart: eveningStartHour)
    }

    var body: some View {
        NavigationStack {
            phaseContent
                .navigationTitle(navigationTitle)
        }
        .task {
            if phase == .morning { await loadMorningData() }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .morning:
            morningContent
        case .daytime:
            ContentUnavailableView(
                "Dein Tag",
                systemImage: "sun.max",
                description: Text("Timeline kommt bald")
            )
        case .evening:
            ContentUnavailableView(
                "Tagesrueckblick",
                systemImage: "moon.stars",
                description: Text("Reflexion kommt bald")
            )
        }
    }

    // MARK: - Morning Content

    @ViewBuilder
    private var morningContent: some View {
        if isLoading {
            ProgressView("Lade Kalender...")
        } else if isPermissionDenied {
            permissionDeniedContent
        } else if calendarEvents.isEmpty && nextUpTasks.isEmpty {
            ContentUnavailableView(
                "Keine Vorschlaege",
                systemImage: "sunrise",
                description: Text("Plan deinen Tag selbst")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !calendarEvents.isEmpty { morningEventsSection }
                    if !freeSlots.isEmpty { morningGapsSection }
                    if !nextUpTasks.isEmpty { morningNextUpSection }
                }
                .padding()
            }
        }
    }

    private var permissionDeniedContent: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Kein Kalender-Zugriff",
                systemImage: "lock.shield",
                description: Text("Bitte Kalender-Zugriff in den Einstellungen aktivieren.")
            )
            #if os(iOS)
            Button("Einstellungen oeffnen", systemImage: "gear") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            #endif
        }
    }

    // MARK: - Morning Sections

    private var morningEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Termine")
                .font(.headline)
            ForEach(calendarEvents.filter { !$0.isAllDay && !$0.isFocusBlock }) { event in
                HStack {
                    Text(event.startDate, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 55, alignment: .leading)
                    Text(event.title)
                        .font(.subheadline)
                }
            }
        }
    }

    private var morningGapsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Freie Luecken")
                .font(.headline)
            ForEach(freeSlots) { slot in
                HStack {
                    Text(slot.startDate, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 55, alignment: .leading)
                    Text("\(slot.durationMinutes) Min frei")
                        .font(.subheadline)
                }
                .padding(8)
                .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var morningNextUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Up")
                .font(.headline)
            ForEach(nextUpTasks) { task in
                HStack {
                    Text(task.title)
                        .font(.subheadline)
                    Spacer()
                    if let duration = task.estimatedDuration {
                        Text("\(duration) Min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadMorningData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                isPermissionDenied = true
                return
            }
            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: Date())
            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: Date())

            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            let allTasks = try await syncEngine.sync()
            nextUpTasks = allTasks.filter { $0.isNextUp && !$0.isCompleted && $0.isActionable }

            let scheduledPairs = allTasks
                .filter { $0.isScheduled }
                .map { (
                    start: $0.scheduledDate!,
                    end: $0.scheduledDate!.addingTimeInterval(
                        Double($0.scheduledDuration ?? $0.estimatedDuration ?? 30) * 60
                    )
                ) }
            freeSlots = GapFinder(
                events: calendarEvents, focusBlocks: focusBlocks,
                scheduledTasks: scheduledPairs, date: Date()
            ).findFreeSlots(minMinutes: 30, maxMinutes: 60)
        } catch {
            // Silently fail — view shows empty state
        }
    }

    // MARK: - Navigation

    private var navigationTitle: String {
        switch phase {
        case .morning: return "Guten Morgen"
        case .daytime: return "Dein Tag"
        case .evening: return "Tagesrueckblick"
        }
    }
}
