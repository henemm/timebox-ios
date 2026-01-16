import SwiftUI

struct BlockPlanningView: View {
    @Environment(\.eventKitRepository) private var eventKitRepo
    @State private var selectedDate = Date()
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var focusBlocks: [FocusBlock] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var selectedSlot: TimeSlot?

    private let hourHeight: CGFloat = 60
    private let startHour = 6
    private let endHour = 22

    var body: some View {
        let bodyMsg = "🟢 BlockPlanningView.body rendered - isLoading: \(isLoading), errorMessage: \(errorMessage ?? "nil")"
        let _ = print(bodyMsg)
        let _ = DebugLogger.log(bodyMsg)

        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    let loadingMsg = "🟡 Showing: ProgressView (Loading)"
                    let _ = print(loadingMsg)
                    let _ = DebugLogger.log(loadingMsg)
                    Spacer()
                    ProgressView("Lade Kalender...")
                    Spacer()
                } else if let error = errorMessage {
                    let errorMsg = "🔴 Showing: ContentUnavailableView (Error: \(error))"
                    let _ = print(errorMsg)
                    let _ = DebugLogger.log(errorMsg)
                    Spacer()
                    ContentUnavailableView(
                        "Fehler",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    Spacer()
                } else {
                    let timelineMsg = "🟢 Showing: blockPlanningTimeline (\(calendarEvents.count) events, \(focusBlocks.count) blocks)"
                    let _ = print(timelineMsg)
                    let _ = DebugLogger.log(timelineMsg)
                    blockPlanningTimeline
                }
            }
            .navigationTitle("Blöcke")
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
            .withSettingsToolbar()
            .sheet(isPresented: $showCreateSheet) {
                if let slot = selectedSlot {
                    CreateFocusBlockSheet(
                        slot: slot,
                        onCreate: { startDate, endDate in
                            createFocusBlock(startDate: startDate, endDate: endDate)
                        }
                    )
                }
            }
        }
        .task {
            print("🟣 .task modifier triggered - calling loadData()")
            await loadData()
        }
        .onChange(of: selectedDate) {
            print("🟣 selectedDate changed - calling loadData()")
            Task {
                await loadData()
            }
        }
    }

    private var blockPlanningTimeline: some View {
        GeometryReader { _ in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            BlockPlanningHourRow(
                                hour: hour,
                                hourHeight: hourHeight,
                                date: selectedDate,
                                events: calendarEvents,
                                focusBlocks: focusBlocks,
                                onTapFreeSlot: { slot in
                                    selectedSlot = slot
                                    showCreateSheet = true
                                }
                            )
                        }
                    }

                    // Existing events overlay (grayed out)
                    ForEach(nonFocusBlockEvents) { event in
                        ExistingEventBlock(
                            event: event,
                            hourHeight: hourHeight,
                            startHour: startHour
                        )
                    }

                    // Focus blocks overlay (highlighted)
                    ForEach(focusBlocks) { block in
                        FocusBlockView(
                            block: block,
                            hourHeight: hourHeight,
                            startHour: startHour
                        )
                    }
                }
                .padding(.top, 8)
                .frame(minHeight: CGFloat(endHour - startHour) * hourHeight)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await loadData()
            }
        }
    }

    private var nonFocusBlockEvents: [CalendarEvent] {
        calendarEvents.filter { !$0.isAllDay && !$0.isFocusBlock }
    }

    private func loadData() async {
        let msg1 = "🔵 BlockPlanningView.loadData() START"
        print(msg1)
        DebugLogger.log(msg1)

        isLoading = true
        errorMessage = nil

        let msg2 = "🔵   isLoading = true"
        print(msg2)
        DebugLogger.log(msg2)

        do {
            let msg3 = "🔵   Calling eventKitRepo.requestAccess()..."
            print(msg3)
            DebugLogger.log(msg3)

            let hasAccess = try await eventKitRepo.requestAccess()

            let msg4 = "🔵   requestAccess() returned: \(hasAccess)"
            print(msg4)
            DebugLogger.log(msg4)

            guard hasAccess else {
                errorMessage = "Zugriff auf Kalender verweigert."
                isLoading = false
                let msg5 = "🔵   ❌ No access! errorMessage = \(errorMessage!), isLoading = false"
                print(msg5)
                DebugLogger.log(msg5)
                return
            }

            let msg6 = "🔵   Fetching calendar events..."
            print(msg6)
            DebugLogger.log(msg6)

            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: selectedDate)

            let msg7 = "🔵   ✅ Fetched \(calendarEvents.count) calendar events"
            print(msg7)
            DebugLogger.log(msg7)

            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: selectedDate)

            let msg8 = "🔵   ✅ Fetched \(focusBlocks.count) focus blocks"
            print(msg8)
            DebugLogger.log(msg8)
        } catch {
            errorMessage = error.localizedDescription
            let msg9 = "🔵   ❌ ERROR: \(error.localizedDescription)"
            print(msg9)
            DebugLogger.log(msg9)
        }

        isLoading = false

        let msgFinal = "🔵 BlockPlanningView.loadData() END - isLoading=\(isLoading), errorMessage=\(errorMessage ?? "nil"), events=\(calendarEvents.count), blocks=\(focusBlocks.count)"
        print(msgFinal)
        DebugLogger.log(msgFinal)
    }

    private func createFocusBlock(startDate: Date, endDate: Date) {
        Task {
            do {
                _ = try eventKitRepo.createFocusBlock(startDate: startDate, endDate: endDate)
                await loadData()
            } catch {
                errorMessage = "Focus Block konnte nicht erstellt werden."
            }
        }
    }
}

// MARK: - Time Slot

struct TimeSlot: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
}

// MARK: - Hour Row for Block Planning

struct BlockPlanningHourRow: View {
    let hour: Int
    let hourHeight: CGFloat
    let date: Date
    let events: [CalendarEvent]
    let focusBlocks: [FocusBlock]
    let onTapFreeSlot: (TimeSlot) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%02d:00", hour))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .trailing)

            // Slot area
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.secondary.opacity(0.2))
                    .frame(height: 1)

                // If this hour is free, show tappable area
                if isHourFree {
                    Rectangle()
                        .fill(.green.opacity(0.1))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let slot = createSlotForHour()
                            onTapFreeSlot(slot)
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: hourHeight)
        .padding(.trailing)
    }

    private var isHourFree: Bool {
        let hourStart = createDateForHour(hour: hour, minute: 0)
        let hourEnd = createDateForHour(hour: hour + 1, minute: 0)

        // Check if any non-focus-block event overlaps
        let hasConflict = events.contains { event in
            guard !event.isAllDay && !event.isFocusBlock else { return false }
            return event.startDate < hourEnd && event.endDate > hourStart
        }

        // Check if any focus block overlaps
        let hasFocusBlock = focusBlocks.contains { block in
            return block.startDate < hourEnd && block.endDate > hourStart
        }

        return !hasConflict && !hasFocusBlock
    }

    private func createSlotForHour() -> TimeSlot {
        let startDate = createDateForHour(hour: hour, minute: 0)
        let endDate = createDateForHour(hour: hour + 1, minute: 0)
        return TimeSlot(startDate: startDate, endDate: endDate)
    }

    private func createDateForHour(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? date
    }
}

// MARK: - Existing Event Block (grayed out)

struct ExistingEventBlock: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    let startHour: Int

    var body: some View {
        let yOffset = calculateYOffset()
        let height = calculateHeight()

        RoundedRectangle(cornerRadius: 6)
            .fill(.gray.opacity(0.3))
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(6),
                alignment: .topLeading
            )
            .frame(height: max(height, 25))
            .padding(.leading, 55)
            .padding(.trailing, 8)
            .offset(y: yOffset)
    }

    private func calculateYOffset() -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        let hoursFromStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursFromStart * hourHeight
    }

    private func calculateHeight() -> CGFloat {
        let durationHours = CGFloat(event.durationMinutes) / 60.0
        return durationHours * hourHeight
    }
}

// MARK: - Focus Block View (highlighted)

struct FocusBlockView: View {
    let block: FocusBlock
    let hourHeight: CGFloat
    let startHour: Int

    var body: some View {
        let yOffset = calculateYOffset()
        let height = calculateHeight()

        RoundedRectangle(cornerRadius: 6)
            .fill(.blue.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.blue, lineWidth: 2)
            )
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    if !block.taskIDs.isEmpty {
                        Text("\(block.taskIDs.count) Tasks")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Keine Tasks")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(6),
                alignment: .topLeading
            )
            .frame(height: max(height, 25))
            .padding(.leading, 55)
            .padding(.trailing, 8)
            .offset(y: yOffset)
    }

    private func calculateYOffset() -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: block.startDate)
        let minute = calendar.component(.minute, from: block.startDate)
        let hoursFromStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursFromStart * hourHeight
    }

    private func calculateHeight() -> CGFloat {
        let durationHours = CGFloat(block.durationMinutes) / 60.0
        return durationHours * hourHeight
    }
}

// MARK: - Create Focus Block Sheet

struct CreateFocusBlockSheet: View {
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
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section {
                    Text("Dauer: \(durationText)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Focus Block erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        onCreate(startTime, endTime)
                        dismiss()
                    }
                    .disabled(endTime <= startTime)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var durationText: String {
        let minutes = Int(endTime.timeIntervalSince(startTime) / 60)
        if minutes < 60 {
            return "\(minutes) Min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) Std"
            } else {
                return "\(hours) Std \(remainingMinutes) Min"
            }
        }
    }
}
