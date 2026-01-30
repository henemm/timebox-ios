import SwiftUI

struct BlockPlanningView: View {
    @Environment(\.eventKitRepository) private var eventKitRepo
    @State private var selectedDate = Date()
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var focusBlocks: [FocusBlock] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSlot: TimeSlot?
    @State private var blockToEdit: FocusBlock?
    @State private var eventToCategories: CalendarEvent?

    private let hourHeight: CGFloat = 60
    private let startHour = 6
    private let endHour = 22

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Lade Kalender...")
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
                    smartGapsContent
                }
            }
            .navigationTitle("Blox")
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
            .sheet(item: $selectedSlot) { slot in
                CreateFocusBlockSheet(
                    slot: slot,
                    onCreate: { startDate, endDate in
                        createFocusBlock(startDate: startDate, endDate: endDate)
                    }
                )
            }
            .sheet(item: $blockToEdit) { block in
                EditFocusBlockSheet(
                    block: block,
                    onSave: { start, end in
                        updateBlock(block, startDate: start, endDate: end)
                    },
                    onDelete: {
                        deleteBlock(block)
                    }
                )
            }
            .sheet(item: $eventToCategories) { event in
                EventCategorySheet(
                    event: event,
                    onSelect: { category in
                        updateEventCategory(event: event, category: category)
                    }
                )
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
                                }
                            )
                        }
                    }

                    // Existing events overlay (grayed out, tappable for categorization)
                    ForEach(nonFocusBlockEvents) { event in
                        ExistingEventBlock(
                            event: event,
                            hourHeight: hourHeight,
                            startHour: startHour,
                            onTap: {
                                eventToCategories = event
                            }
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

    // MARK: - Smart Gaps Content

    private var smartGapsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Smart Gaps Section
                SmartGapsSection(
                    slots: computedFreeSlots,
                    isDayFree: isDayMostlyFree,
                    onCreateBlock: { slot in
                        createFocusBlock(startDate: slot.startDate, endDate: slot.endDate)
                    }
                )

                // Manual Block Creation Button
                Button {
                    let startDate = roundedCurrentTime()
                    selectedSlot = TimeSlot(
                        startDate: startDate,
                        endDate: startDate.addingTimeInterval(3600)
                    )
                } label: {
                    Label("Eigenen Block erstellen", systemImage: "plus.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .accessibilityIdentifier("createCustomBlockButton")

                // Existing Focus Blocks
                if !focusBlocks.isEmpty {
                    existingBlocksSection
                }

                // Calendar Events (tappable for categorization)
                if !nonFocusBlockEvents.isEmpty {
                    calendarEventsSection
                }
            }
            .padding()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Calendar Events Section

    private var calendarEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.gray)
                Text("Heutige Termine")
                    .font(.headline)
                Spacer()
                Text("\(nonFocusBlockEvents.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.gray.opacity(0.15)))
            }

            VStack(spacing: 8) {
                ForEach(nonFocusBlockEvents) { event in
                    CalendarEventRow(event: event) {
                        eventToCategories = event
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private var computedFreeSlots: [TimeSlot] {
        let finder = GapFinder(events: calendarEvents, focusBlocks: focusBlocks, date: selectedDate)
        return finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)
    }

    private var isDayMostlyFree: Bool {
        let nonAllDayEvents = calendarEvents.filter { !$0.isAllDay && !$0.isFocusBlock }
        let totalBusyMinutes = nonAllDayEvents.reduce(0) { $0 + $1.durationMinutes }
        return totalBusyMinutes < 120 // Less than 2 hours of meetings
    }

    private var existingBlocksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "rectangle.split.3x1.fill")
                    .foregroundStyle(.blue)
                Text("Today's Blox")
                    .font(.headline)
                Spacer()
                Text("\(focusBlocks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.blue.opacity(0.15)))
            }

            LazyVStack(spacing: 8) {
                ForEach(focusBlocks) { block in
                    ExistingBlockRow(block: block)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            blockToEdit = block
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteBlock(block)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private func deleteBlock(_ block: FocusBlock) {
        Task {
            do {
                try eventKitRepo.deleteFocusBlock(eventID: block.id)
                NotificationService.cancelFocusBlockNotification(blockID: block.id)
                await loadData()
            } catch {
                errorMessage = "Block konnte nicht gelöscht werden."
            }
        }
    }

    private func updateBlock(_ block: FocusBlock, startDate: Date, endDate: Date) {
        Task {
            do {
                try eventKitRepo.updateFocusBlockTime(eventID: block.id, startDate: startDate, endDate: endDate)

                // Reschedule notification with new start time
                NotificationService.cancelFocusBlockNotification(blockID: block.id)
                NotificationService.scheduleFocusBlockStartNotification(
                    blockID: block.id,
                    blockTitle: block.title,
                    startDate: startDate
                )

                await loadData()
            } catch {
                errorMessage = "Block konnte nicht aktualisiert werden."
            }
        }
    }

    private func updateEventCategory(event: CalendarEvent, category: String?) {
        Task {
            do {
                try eventKitRepo.updateEventCategory(eventID: event.id, category: category)
                await loadData()
            } catch {
                errorMessage = "Kategorie konnte nicht gespeichert werden."
            }
        }
    }

    private var nonFocusBlockEvents: [CalendarEvent] {
        calendarEvents.filter { !$0.isAllDay && !$0.isFocusBlock }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let hasAccess = try await eventKitRepo.requestAccess()

            guard hasAccess else {
                errorMessage = "Zugriff auf Kalender verweigert."
                isLoading = false
                return
            }

            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: selectedDate)
            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: selectedDate)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func createFocusBlock(startDate: Date, endDate: Date) {
        Task {
            do {
                let blockID = try eventKitRepo.createFocusBlock(startDate: startDate, endDate: endDate)

                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let title = "Focus Block \(formatter.string(from: startDate))"
                NotificationService.scheduleFocusBlockStartNotification(
                    blockID: blockID,
                    blockTitle: title,
                    startDate: startDate
                )

                await loadData()
            } catch {
                errorMessage = "Focus Block konnte nicht erstellt werden."
            }
        }
    }

    /// Returns the current time rounded up to the next full hour
    private func roundedCurrentTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        guard let hourStart = calendar.date(from: components) else { return now }
        // If we're past the hour start, go to next hour
        if now > hourStart {
            return hourStart.addingTimeInterval(3600)
        }
        return hourStart
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

// MARK: - Gap Finder

/// Finds free time slots between calendar events for focus blocks
struct GapFinder {
    let events: [CalendarEvent]
    let focusBlocks: [FocusBlock]
    let date: Date

    private let startHour = 6
    private let endHour = 22
    private let defaultSuggestionHours = [9, 11, 14, 16]

    /// Find free slots within the min/max duration range
    func findFreeSlots(minMinutes: Int = 30, maxMinutes: Int = 60) -> [TimeSlot] {
        let calendar = Calendar.current

        // Get day boundaries
        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startComponents.hour = startHour
        startComponents.minute = 0
        let dayStart = calendar.date(from: startComponents) ?? date

        var endComponents = calendar.dateComponents([.year, .month, .day], from: date)
        endComponents.hour = endHour
        endComponents.minute = 0
        let dayEnd = calendar.date(from: endComponents) ?? date

        // Collect all busy periods
        var busyPeriods: [(start: Date, end: Date)] = []

        for event in events where !event.isAllDay && !event.isFocusBlock {
            busyPeriods.append((event.startDate, event.endDate))
        }

        for block in focusBlocks {
            busyPeriods.append((block.startDate, block.endDate))
        }

        // Sort by start time
        busyPeriods.sort { $0.start < $1.start }

        // Find gaps
        var gaps: [TimeSlot] = []
        // Bug 9 Fix: Start from current time, not day start (06:00)
        // This prevents showing past time slots
        let now = Date()
        var currentTime = Calendar.current.isDate(now, inSameDayAs: date) ? max(dayStart, now) : dayStart

        for period in busyPeriods {
            // Skip periods outside our time range
            if period.end <= dayStart || period.start >= dayEnd {
                continue
            }

            // Clamp to day boundaries
            let periodStart = max(period.start, dayStart)

            // Found a gap before this period
            if currentTime < periodStart {
                let gapDuration = Int(periodStart.timeIntervalSince(currentTime) / 60)
                if gapDuration >= minMinutes {
                    // If gap is larger than max, create a slot at the start
                    let slotEnd: Date
                    if gapDuration > maxMinutes {
                        slotEnd = currentTime.addingTimeInterval(Double(maxMinutes) * 60)
                    } else {
                        slotEnd = periodStart
                    }
                    gaps.append(TimeSlot(startDate: currentTime, endDate: slotEnd))
                }
            }

            // Move current time to end of this period
            currentTime = max(currentTime, min(period.end, dayEnd))
        }

        // Check for gap at the end of the day
        if currentTime < dayEnd {
            let gapDuration = Int(dayEnd.timeIntervalSince(currentTime) / 60)
            if gapDuration >= minMinutes {
                let slotEnd: Date
                if gapDuration > maxMinutes {
                    slotEnd = currentTime.addingTimeInterval(Double(maxMinutes) * 60)
                } else {
                    slotEnd = dayEnd
                }
                gaps.append(TimeSlot(startDate: currentTime, endDate: slotEnd))
            }
        }

        // If day is mostly free (no gaps found or only huge gaps), show default suggestions
        if gaps.isEmpty || isWholeDayFree(busyPeriods: busyPeriods, dayStart: dayStart, dayEnd: dayEnd) {
            return createDefaultSuggestions(maxMinutes: maxMinutes)
        }

        return gaps
    }

    private func isWholeDayFree(busyPeriods: [(start: Date, end: Date)], dayStart: Date, dayEnd: Date) -> Bool {
        // Day is considered "free" if total busy time is less than 2 hours
        let totalBusyMinutes = busyPeriods
            .filter { $0.end > dayStart && $0.start < dayEnd }
            .reduce(0) { total, period in
                let start = max(period.start, dayStart)
                let end = min(period.end, dayEnd)
                return total + Int(end.timeIntervalSince(start) / 60)
            }
        return totalBusyMinutes < 120
    }

    private func createDefaultSuggestions(maxMinutes: Int) -> [TimeSlot] {
        let calendar = Calendar.current
        let now = Date()
        let isToday = calendar.isDate(now, inSameDayAs: date)

        return defaultSuggestionHours.compactMap { hour in
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = 0
            guard let start = calendar.date(from: components) else { return nil }

            // Bug 9 Fix: Filter out past suggestions for today
            if isToday && start < now {
                return nil
            }

            let end = start.addingTimeInterval(Double(maxMinutes) * 60)
            return TimeSlot(startDate: start, endDate: end)
        }
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

// MARK: - Existing Event Block (grayed out, tappable for categorization)

struct ExistingEventBlock: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    let startHour: Int
    var onTap: (() -> Void)? = nil

    /// Get category color if event has a category
    private var categoryColor: Color? {
        guard let categoryString = event.category,
              let category = CategoryConfig(rawValue: categoryString) else {
            return nil
        }
        return category.color
    }

    var body: some View {
        let yOffset = calculateYOffset()
        let height = calculateHeight()

        RoundedRectangle(cornerRadius: 6)
            .fill(.gray.opacity(0.3))
            .overlay(
                HStack(spacing: 4) {
                    // Category indicator (left edge)
                    if let color = categoryColor {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: 4)
                            .accessibilityIdentifier("eventCategory_\(event.title)")
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 6)
                    .padding(.trailing, 6)
                    .padding(.leading, categoryColor == nil ? 6 : 2)

                    Spacer()
                }
            )
            .frame(height: max(height, 25))
            .padding(.leading, 55)
            .padding(.trailing, 8)
            .offset(y: yOffset)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
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

// MARK: - Smart Gaps Section

struct SmartGapsSection: View {
    let slots: [TimeSlot]
    let isDayFree: Bool
    let onCreateBlock: (TimeSlot) -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: isDayFree ? "sun.max.fill" : "clock.fill")
                    .foregroundStyle(isDayFree ? .orange : .green)
                Text(isDayFree ? "Tag ist frei!" : "Freie Slots")
                    .font(.headline)
                Spacer()
                if !slots.isEmpty {
                    Text("\(slots.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.green.opacity(0.15)))
                }
            }

            if isDayFree {
                Text("Vorgeschlagene Zeiten:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Slots
            if slots.isEmpty {
                Text("Keine freien Slots (30-60 min) verfügbar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(slots) { slot in
                        GapRow(slot: slot, timeFormatter: timeFormatter) {
                            onCreateBlock(slot)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.green.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Gap Row

struct GapRow: View {
    let slot: TimeSlot
    let timeFormatter: DateFormatter
    let onCreate: () -> Void

    var body: some View {
        HStack {
            Text("\(timeFormatter.string(from: slot.startDate)) - \(timeFormatter.string(from: slot.endDate))")
                .font(.subheadline)

            Spacer()

            Text("\(slot.durationMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.green.opacity(0.15)))

            Button {
                onCreate()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.green.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Existing Block Row

struct ExistingBlockRow: View {
    let block: FocusBlock

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline.weight(.medium))
                Text("\(timeFormatter.string(from: block.startDate)) - \(timeFormatter.string(from: block.endDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !block.taskIDs.isEmpty {
                Text("\(block.taskIDs.count) Tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.blue.opacity(0.15)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.opacity(0.1))
        )
        .accessibilityIdentifier("existingBlock_\(block.id)")
    }
}

// MARK: - Event Category Sheet

/// Sheet for selecting a category for a calendar event
struct EventCategorySheet: View {
    let event: CalendarEvent
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(CategoryConfig.allCases, id: \.self) { category in
                    Button {
                        onSelect(category.rawValue)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                                .frame(width: 30)

                            Text(category.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if event.category == category.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .accessibilityIdentifier("categoryOption_\(category.rawValue)")
                }

                // Option to clear category
                if event.category != nil {
                    Button(role: .destructive) {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.red)
                                .frame(width: 30)

                            Text("Kategorie entfernen")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Kategorie wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Calendar Event Row

/// Row for displaying a calendar event with tap-to-categorize
struct CalendarEventRow: View {
    let event: CalendarEvent
    let onTap: () -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    /// Get category color if event has a category
    private var categoryColor: Color? {
        guard let categoryString = event.category,
              let category = CategoryConfig(rawValue: categoryString) else {
            return nil
        }
        return category.color
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Category indicator (left edge)
                if let color = categoryColor {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 4, height: 40)
                        .accessibilityIdentifier("eventCategory_\(event.title)")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Tap hint
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
