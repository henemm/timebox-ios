import SwiftUI
import SwiftData

struct BlockPlanningView: View {
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var focusBlocks: [FocusBlock] = []
    @State private var allTasks: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isPermissionDenied = false
    @State private var selectedSlot: TimeSlot?
    @State private var blockToEdit: FocusBlock?
    @State private var blockForTasks: FocusBlock?
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
                    timelineContent
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
            .sheet(item: $blockForTasks) { block in
                FocusBlockTasksSheet(
                    block: block,
                    tasks: tasksForBlock(block),
                    onReorder: { newOrder in
                        reorderTasksInBlock(block, taskIDs: newOrder)
                    },
                    onRemoveTask: { taskID in
                        removeTaskFromBlock(block, taskID: taskID)
                    },
                    onAddTask: {
                        // Will be implemented: show task picker
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

    // MARK: - Timeline Content (Unified Planning View)

    private var timelineContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hour rows with events and blocks
                ForEach(startHour..<endHour, id: \.self) { hour in
                    TimelineHourRow(
                        hour: hour,
                        hourHeight: hourHeight,
                        date: selectedDate,
                        events: calendarEvents.filter { !$0.isAllDay && !$0.isFocusBlock },
                        focusBlocks: focusBlocks,
                        freeSlots: computedFreeSlots,
                        onTapBlock: { block in
                            blockForTasks = block
                        },
                        onTapEditBlock: { block in
                            blockToEdit = block
                        },
                        onTapFreeSlot: { slot in
                            selectedSlot = slot
                        },
                        onTapEvent: { event in
                            eventToCategories = event
                        }
                    )
                }
            }
            .padding(.top, 8)
        }
        .accessibilityIdentifier("planningTimeline")
        .refreshable {
            await loadData()
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

    private func reorderTasksInBlock(_ block: FocusBlock, taskIDs: [String]) {
        Task {
            do {
                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: taskIDs,
                    completedTaskIDs: block.completedTaskIDs,
                    taskTimes: block.taskTimes
                )
                await loadData()
            } catch {
                errorMessage = "Task-Reihenfolge konnte nicht gespeichert werden."
            }
        }
    }

    private func removeTaskFromBlock(_ block: FocusBlock, taskID: String) {
        Task {
            do {
                var newTaskIDs = block.taskIDs
                newTaskIDs.removeAll { $0 == taskID }
                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: newTaskIDs,
                    completedTaskIDs: block.completedTaskIDs,
                    taskTimes: block.taskTimes
                )
                await loadData()
            } catch {
                errorMessage = "Task konnte nicht entfernt werden."
            }
        }
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
        isPermissionDenied = false

        do {
            let hasAccess = try await eventKitRepo.requestAccess()

            guard hasAccess else {
                errorMessage = "Zugriff auf Kalender/Erinnerungen verweigert. Bitte in den Einstellungen aktivieren."
                isPermissionDenied = true
                isLoading = false
                return
            }

            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: selectedDate)
            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: selectedDate)

            // Load tasks for the blocks
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            allTasks = try await syncEngine.sync()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func tasksForBlock(_ block: FocusBlock) -> [PlanItem] {
        block.taskIDs.compactMap { taskID in
            allTasks.first { $0.id == taskID }
        }
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

// MARK: - Timeline Hour Row (Unified Planning View)

/// A single hour row in the unified timeline view
/// Displays hour marker, focus blocks, free slots, and calendar events
struct TimelineHourRow: View {
    let hour: Int
    let hourHeight: CGFloat
    let date: Date
    let events: [CalendarEvent]
    let focusBlocks: [FocusBlock]
    let freeSlots: [TimeSlot]
    let onTapBlock: (FocusBlock) -> Void
    let onTapEditBlock: (FocusBlock) -> Void
    let onTapFreeSlot: (TimeSlot) -> Void
    let onTapEvent: (CalendarEvent) -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Hour marker
            Text(String(format: "%02d:00", hour))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .trailing)
                .accessibilityIdentifier("hourMarker_\(hour)")

            // Content area for this hour
            VStack(alignment: .leading, spacing: 4) {
                // Horizontal line
                Rectangle()
                    .fill(.secondary.opacity(0.2))
                    .frame(height: 1)

                // Focus blocks that start in this hour
                ForEach(blocksInHour) { block in
                    TimelineFocusBlockRow(
                        block: block,
                        onTapBlock: { onTapBlock(block) },
                        onTapEdit: { onTapEditBlock(block) }
                    )
                }

                // Free slots in this hour
                ForEach(slotsInHour) { slot in
                    TimelineFreeSlotRow(
                        slot: slot,
                        timeFormatter: timeFormatter,
                        onTap: { onTapFreeSlot(slot) }
                    )
                }

                // Calendar events in this hour
                ForEach(eventsInHour) { event in
                    TimelineEventRow(
                        event: event,
                        timeFormatter: timeFormatter,
                        onTap: { onTapEvent(event) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: hourHeight)
        .padding(.trailing)
    }

    // MARK: - Filtered Items

    private var blocksInHour: [FocusBlock] {
        let hourStart = createDateForHour(hour: hour, minute: 0)
        let hourEnd = createDateForHour(hour: hour + 1, minute: 0)
        return focusBlocks.filter { block in
            block.startDate >= hourStart && block.startDate < hourEnd
        }
    }

    private var slotsInHour: [TimeSlot] {
        let hourStart = createDateForHour(hour: hour, minute: 0)
        let hourEnd = createDateForHour(hour: hour + 1, minute: 0)
        return freeSlots.filter { slot in
            slot.startDate >= hourStart && slot.startDate < hourEnd
        }
    }

    private var eventsInHour: [CalendarEvent] {
        let hourStart = createDateForHour(hour: hour, minute: 0)
        let hourEnd = createDateForHour(hour: hour + 1, minute: 0)
        return events.filter { event in
            event.startDate >= hourStart && event.startDate < hourEnd
        }
    }

    private func createDateForHour(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? date
    }
}

// MARK: - Timeline Focus Block Row

/// A focus block displayed in the timeline
struct TimelineFocusBlockRow: View {
    let block: FocusBlock
    let onTapBlock: () -> Void
    let onTapEdit: () -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            // Tappable content area (opens Tasks Sheet)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("\(timeFormatter.string(from: block.startDate)) - \(timeFormatter.string(from: block.endDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !block.taskIDs.isEmpty {
                        Text("\(block.taskIDs.count) Tasks")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.blue.opacity(0.15)))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onTapBlock()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Tasks anzeigen")

            // Edit button (ellipsis) - opens Edit Sheet
            Button {
                onTapEdit()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Block bearbeiten")
            .accessibilityIdentifier("focusBlockEditButton_\(block.id)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focusBlock_\(block.id)")
    }
}

// MARK: - Timeline Free Slot Row

/// A free slot displayed in the timeline (dashed green border)
struct TimelineFreeSlotRow: View {
    let slot: TimeSlot
    let timeFormatter: DateFormatter
    let onTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Freier Slot")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)

                Text("\(timeFormatter.string(from: slot.startDate)) - \(timeFormatter.string(from: slot.endDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(slot.durationMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.green.opacity(0.15)))

            Button {
                onTap()
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
                .fill(.green.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.green.opacity(0.5))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .accessibilityIdentifier("freeSlot_\(timeFormatter.string(from: slot.startDate))")
    }
}

// MARK: - Timeline Event Row

/// A calendar event displayed in the timeline
struct TimelineEventRow: View {
    let event: CalendarEvent
    let timeFormatter: DateFormatter
    let onTap: () -> Void

    /// Get category color if event has a category
    private var categoryColor: Color? {
        guard let categoryString = event.category,
              let category = CategoryConfig(rawValue: categoryString) else {
            return nil
        }
        return category.color
    }

    var body: some View {
        HStack(spacing: 8) {
            // Category indicator
            if let color = categoryColor {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "tag")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, categoryColor == nil ? 12 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.1))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
