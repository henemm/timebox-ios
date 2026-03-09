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
    @State private var assignmentFeedback = false
    @State private var dropTargetTime: Date?

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
            .sensoryFeedback(.success, trigger: assignmentFeedback)
            .sheet(item: $blockForTasks) { block in
                FocusBlockTasksSheet(
                    block: block,
                    tasks: tasksForBlock(block),
                    nextUpTasks: nextUpTasksNotInBlock(block),
                    allTasks: backlogTasksNotInBlock(block),
                    onReorder: { newOrder in
                        reorderTasksInBlock(block, taskIDs: newOrder)
                    },
                    onRemoveTask: { taskID in
                        removeTaskFromBlock(block, taskID: taskID)
                    },
                    onAssignTask: { taskID in
                        assignTaskToBlock(taskID: taskID, block: block)
                    }
                )
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
        .onChange(of: eventKitRepo.eventStoreChangeCount) {
            Task {
                await loadData()
            }
        }
    }

    // MARK: - Timeline Content (Canvas-based, Bug 70c-1b)

    private let timeColumnWidth: CGFloat = 45

    private var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    private var timelineContent: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Hour grid background
                hourGrid

                // Canvas layout — positions all items by time with collision detection
                TimelineLayout(hourHeight: hourHeight, startHour: startHour, endHour: endHour) {
                    // Calendar events
                    ForEach(positionedEvents) { positioned in
                        TimelineEventRow(
                            event: positioned.event,
                            timeFormatter: sharedTimeFormatter,
                            onTap: { eventToCategories = positioned.event }
                        )
                        .frame(maxHeight: .infinity)
                        .timelinePosition(
                            hour: Calendar.current.component(.hour, from: positioned.event.startDate),
                            minute: Calendar.current.component(.minute, from: positioned.event.startDate),
                            durationMinutes: positioned.event.durationMinutes,
                            column: positioned.column,
                            totalColumns: positioned.totalColumns
                        )
                    }

                    // Focus blocks
                    ForEach(positionedFocusBlocks) { positioned in
                        TimelineFocusBlockRow(
                            block: positioned.block,
                            hourHeight: hourHeight,
                            onTapBlock: { blockForTasks = positioned.block },
                            onTapEdit: { blockToEdit = positioned.block },
                            onResize: { newEndDate in
                                resizeFocusBlock(positioned.block, newEndDate: newEndDate)
                            }
                        )
                        .frame(maxHeight: .infinity)
                        .timelinePosition(
                            hour: Calendar.current.component(.hour, from: positioned.block.startDate),
                            minute: Calendar.current.component(.minute, from: positioned.block.startDate),
                            durationMinutes: positioned.block.durationMinutes,
                            column: positioned.column,
                            totalColumns: positioned.totalColumns
                        )
                    }

                    // Free slots
                    ForEach(computedFreeSlots) { slot in
                        TimelineFreeSlotRow(
                            slot: slot,
                            timeFormatter: sharedTimeFormatter,
                            onTap: { selectedSlot = slot }
                        )
                        .frame(minHeight: 50)
                        .timelinePosition(
                            hour: Calendar.current.component(.hour, from: slot.startDate),
                            minute: Calendar.current.component(.minute, from: slot.startDate),
                            durationMinutes: slot.durationMinutes,
                            column: 0,
                            totalColumns: 1
                        )
                    }
                }
                .padding(.leading, timeColumnWidth)

                // Drop preview indicator (always in hierarchy for accessibility; visible only during drag)
                DropPreviewIndicator(time: dropTargetTime ?? selectedDate)
                    .offset(x: timeColumnWidth, y: {
                        guard let dropTime = dropTargetTime else { return 0 }
                        let dropHour = Calendar.current.component(.hour, from: dropTime)
                        let dropMinute = Calendar.current.component(.minute, from: dropTime)
                        return CGFloat(dropHour - startHour) * hourHeight + CGFloat(dropMinute) / 60.0 * hourHeight
                    }())
                    .opacity(dropTargetTime != nil ? 1 : 0)
                    .accessibilityIdentifier("dropPreviewIndicator")
            }
            .frame(height: totalHeight)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("canvasDropZone")
            .onDrop(of: [.calendarEvent], delegate: TimelineDropDelegate(
                hourHeight: hourHeight,
                startHour: startHour,
                selectedDate: selectedDate,
                focusBlocks: focusBlocks,
                dropTargetTime: $dropTargetTime,
                onDrop: { blockID, snappedTime in
                    moveFocusBlock(blockID: blockID, to: snappedTime)
                }
            ))
        }
        .accessibilityIdentifier("planningTimeline")
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Canvas Positioning (Collision Detection)

    private var positionedItems: [PositionedItem] {
        let regularEvents = calendarEvents.filter { event in
            !event.isFocusBlock && !event.isAllDay && event.durationMinutes <= 480
        }

        var allItems: [TimelineItem] = []
        allItems.append(contentsOf: regularEvents.map { TimelineItem(event: $0) })
        allItems.append(contentsOf: focusBlocks.map { TimelineItem(block: $0) })

        let groups = TimelineItem.groupOverlapping(allItems)

        var result: [PositionedItem] = []
        for group in groups {
            let columns = TimelineItem.assignColumns(group)
            for entry in columns {
                result.append(PositionedItem(
                    id: entry.item.id, item: entry.item,
                    column: entry.column, totalColumns: entry.totalColumns
                ))
            }
        }
        return result
    }

    private var positionedEvents: [PositionedEvent] {
        positionedItems.compactMap { positioned -> PositionedEvent? in
            if case .event(let event) = positioned.item.type {
                return PositionedEvent(
                    id: positioned.id, event: event,
                    column: positioned.column, totalColumns: positioned.totalColumns
                )
            }
            return nil
        }
    }

    private var positionedFocusBlocks: [PositionedFocusBlock] {
        positionedItems.compactMap { positioned -> PositionedFocusBlock? in
            if case .focusBlock(let block) = positioned.item.type {
                return PositionedFocusBlock(
                    id: positioned.id, block: block,
                    column: positioned.column, totalColumns: positioned.totalColumns
                )
            }
            return nil
        }
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth, alignment: .trailing)
                        .accessibilityIdentifier("hourMarker_\(hour)")

                    Rectangle()
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 1)
                }
                .frame(height: hourHeight)
            }
        }
    }

    private let sharedTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

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

                // Clear assignedFocusBlockID and restore to Next Up
                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                try syncEngine.updateAssignedFocusBlock(itemID: taskID, focusBlockID: nil)
                try syncEngine.updateNextUp(itemID: taskID, isNextUp: true)

                await loadData()
                assignmentFeedback.toggle()
            } catch {
                errorMessage = "Task konnte nicht entfernt werden."
            }
        }
    }

    private func assignTaskToBlock(taskID: String, block: FocusBlock) {
        Task {
            do {
                // Bug 81 Fix: Read CURRENT block from focusBlocks, not stale sheet snapshot
                let currentBlock = focusBlocks.first { $0.id == block.id } ?? block
                var updatedTaskIDs = currentBlock.taskIDs
                if !updatedTaskIDs.contains(taskID) {
                    updatedTaskIDs.append(taskID)
                }

                try eventKitRepo.updateFocusBlock(
                    eventID: currentBlock.id,
                    taskIDs: updatedTaskIDs,
                    completedTaskIDs: currentBlock.completedTaskIDs,
                    taskTimes: currentBlock.taskTimes
                )

                // Remove from Next Up and set assignedFocusBlockID
                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                try syncEngine.updateNextUp(itemID: taskID, isNextUp: false)
                try syncEngine.updateAssignedFocusBlock(itemID: taskID, focusBlockID: block.id)

                await loadData()
                // Bug 81 Fix: Update sheet binding so it re-renders with current block
                if let refreshedBlock = focusBlocks.first(where: { $0.id == block.id }) {
                    blockForTasks = refreshedBlock
                }
                assignmentFeedback.toggle()
            } catch {
                errorMessage = "Task konnte nicht zugeordnet werden."
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

                // Reschedule notifications with new title and times
                let updatedTitle = FocusBlock.generateTitle(for: startDate)
                NotificationService.cancelFocusBlockNotification(blockID: block.id)
                NotificationService.scheduleFocusBlockStartNotification(
                    blockID: block.id,
                    blockTitle: updatedTitle,
                    startDate: startDate
                )
                NotificationService.scheduleFocusBlockEndNotification(
                    blockID: block.id,
                    blockTitle: updatedTitle,
                    endDate: endDate,
                    completedCount: block.completedTaskIDs.count,
                    totalCount: block.taskIDs.count
                )

                await loadData()
            } catch {
                errorMessage = "Block konnte nicht aktualisiert werden."
            }
        }
    }

    private func moveFocusBlock(blockID: String, to newStart: Date) {
        guard let block = focusBlocks.first(where: { $0.id == blockID }),
              block.isFuture else { return }
        let duration = block.endDate.timeIntervalSince(block.startDate)
        let newEnd = newStart.addingTimeInterval(duration)
        updateBlock(block, startDate: newStart, endDate: newEnd)
    }

    private func resizeFocusBlock(_ block: FocusBlock, newEndDate: Date) {
        guard block.isFuture else { return }
        updateBlock(block, startDate: block.startDate, endDate: newEndDate)
    }

    private func updateEventCategory(event: CalendarEvent, category: String?) {
        Task {
            do {
                try eventKitRepo.updateEventCategory(calendarItemID: event.calendarItemIdentifier, category: category)
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

            // Bug 81 Recovery: Clean orphaned block assignments (tasks with
            // assignedFocusBlockID set but not listed in any block's taskIDs)
            let cleaned = try syncEngine.cleanOrphanedBlockAssignments(focusBlocks: focusBlocks)
            if cleaned > 0 {
                allTasks = try await syncEngine.sync() // Refresh to show recovered tasks
            }
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

    private func nextUpTasksNotInBlock(_ block: FocusBlock) -> [PlanItem] {
        let blockTaskIDs = Set(block.taskIDs)
        return allTasks.filter { $0.isNextUp && !$0.isCompleted && !blockTaskIDs.contains($0.id) }
    }

    private func backlogTasksNotInBlock(_ block: FocusBlock) -> [PlanItem] {
        let blockTaskIDs = Set(block.taskIDs)
        return allTasks.filter { !$0.isCompleted && !$0.isNextUp && !blockTaskIDs.contains($0.id) }
    }

    private func createFocusBlock(startDate: Date, endDate: Date) {
        Task {
            do {
                let blockID = try eventKitRepo.createFocusBlock(startDate: startDate, endDate: endDate)

                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let title = "FocusBlox \(formatter.string(from: startDate))"
                NotificationService.scheduleFocusBlockStartNotification(
                    blockID: blockID,
                    blockTitle: title,
                    startDate: startDate
                )
                NotificationService.scheduleFocusBlockEndNotification(
                    blockID: blockID,
                    blockTitle: title,
                    endDate: endDate,
                    completedCount: 0,
                    totalCount: 0
                )

                await loadData()
            } catch {
                errorMessage = "FocusBlox konnte nicht erstellt werden."
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
              let category = TaskCategory(rawValue: categoryString) else {
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

// MARK: - Create Focus Block Sheet

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
              let category = TaskCategory(rawValue: categoryString) else {
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

                if let categoryString = event.category,
                   let config = TaskCategory(rawValue: categoryString) {
                    CategoryIconBadge(category: config)
                }
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

// MARK: - Timeline Focus Block Row

/// A focus block displayed in the timeline
struct TimelineFocusBlockRow: View {
    let block: FocusBlock
    let hourHeight: CGFloat
    let onTapBlock: () -> Void
    let onTapEdit: () -> Void
    var onResize: ((_ newEndDate: Date) -> Void)?

    @State private var resizeDragOffset: CGFloat = 0
    @State private var isResizing = false

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
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

                // Edit button (gear) - opens Edit Sheet
                Button {
                    onTapEdit()
                } label: {
                    Image(systemName: "gearshape")
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

            // Resize handle at bottom edge (only for future blocks)
            if block.isFuture, onResize != nil {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isResizing ? Color.blue : Color.blue.opacity(0.4))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)
                    .contentShape(Rectangle().size(width: 1000, height: 20).offset(y: -8))
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                isResizing = true
                                resizeDragOffset = value.translation.height
                            }
                            .onEnded { _ in
                                let newEnd = FocusBlock.resizedEndDate(
                                    startDate: block.startDate,
                                    originalEndDate: block.endDate,
                                    dragOffsetY: resizeDragOffset,
                                    hourHeight: hourHeight
                                )
                                onResize?(newEnd)
                                resizeDragOffset = 0
                                isResizing = false
                            }
                    )
                    .accessibilityLabel("Block-Dauer aendern")
                    .accessibilityIdentifier("focusBlockResizeHandle_\(block.id)")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isResizing ? .blue : .blue.opacity(0.3), lineWidth: isResizing ? 2 : 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focusBlock_\(block.id)")
        .if(block.isFuture) { view in
            view.draggable(CalendarEventTransfer(from: block))
        }
    }
}

// MARK: - Drop Preview Indicator

/// Visual indicator showing where a dragged FocusBlock will land
struct DropPreviewIndicator: View {
    let time: Date

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(timeString)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Rectangle()
                .fill(Color.blue)
                .frame(height: 2)
        }
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
              let category = TaskCategory(rawValue: categoryString) else {
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

            if let categoryString = event.category,
               let config = TaskCategory(rawValue: categoryString) {
                CategoryIconBadge(category: config)
            }
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
        .accessibilityIdentifier("timelineEvent_\(event.id)")
    }
}

// MARK: - Timeline Drop Delegate

/// DropDelegate that provides continuous position updates during drag
struct TimelineDropDelegate: DropDelegate {
    let hourHeight: CGFloat
    let startHour: Int
    let selectedDate: Date
    let focusBlocks: [FocusBlock]
    @Binding var dropTargetTime: Date?
    var onDrop: (String, Date) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let dropTime = TimelineLocationCalculator.timeFromLocation(
            y: info.location.y,
            hourHeight: hourHeight,
            startHour: startHour,
            referenceDate: selectedDate
        )
        dropTargetTime = FocusBlock.snapToQuarterHour(dropTime)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dropTargetTime = nil
        let providers = info.itemProviders(for: [.calendarEvent])
        guard let provider = providers.first else { return false }

        provider.loadTransferable(type: CalendarEventTransfer.self) { result in
            if case .success(let transfer) = result {
                let dropTime = TimelineLocationCalculator.timeFromLocation(
                    y: info.location.y,
                    hourHeight: hourHeight,
                    startHour: startHour,
                    referenceDate: selectedDate
                )
                let snapped = FocusBlock.snapToQuarterHour(dropTime)
                DispatchQueue.main.async {
                    onDrop(transfer.id, snapped)
                }
            }
        }
        return true
    }

    func dropExited(info: DropInfo) {
        dropTargetTime = nil
    }
}
