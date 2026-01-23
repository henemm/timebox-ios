import SwiftUI
import SwiftData

struct BacklogView: View {
    // MARK: - ViewMode Definition
    enum ViewMode: String, CaseIterable, Identifiable {
        case list = "Liste"
        case eisenhowerMatrix = "Matrix"
        case category = "Kategorie"
        case duration = "Dauer"
        case dueDate = "Fälligkeit"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .eisenhowerMatrix: return "square.grid.2x2"
            case .category: return "folder"
            case .duration: return "clock"
            case .dueDate: return "calendar"
            }
        }

        var emptyStateMessage: (title: String, description: String) {
            switch self {
            case .list:
                return ("Keine Tasks", "Tippe auf + um einen neuen Task zu erstellen.")
            case .eisenhowerMatrix:
                return ("Keine Tasks für Matrix", "Setze Priorität und Dringlichkeit für deine Tasks.")
            case .category:
                return ("Keine Tasks in Kategorien", "Erstelle Tasks und weise ihnen Kategorien zu.")
            case .duration:
                return ("Keine Tasks mit Dauer", "Setze geschätzte Dauern für deine Tasks.")
            case .dueDate:
                return ("Keine Tasks mit Fälligkeitsdatum", "Setze Fälligkeitsdaten für deine Tasks.")
            }
        }
    }

    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext
    @AppStorage("backlogViewMode") private var selectedMode: ViewMode = .list
    @State private var planItems: [PlanItem] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var reorderTrigger = false
    @State private var selectedItemForDuration: PlanItem?
    @State private var durationFeedback = false
    @State private var showCreateTask = false
    @State private var nextUpFeedback = false
    @State private var taskToEdit: PlanItem?

    // MARK: - Next Up Tasks
    private var nextUpTasks: [PlanItem] {
        planItems.filter { $0.isNextUp && !$0.isCompleted }
    }

    private var backlogTasks: [PlanItem] {
        planItems.filter { !$0.isCompleted && !$0.isNextUp }
    }

    // MARK: - Eisenhower Matrix Filters
    private var doFirstTasks: [PlanItem] {
        planItems.filter { $0.urgency == "urgent" && $0.priorityValue == 3 && !$0.isCompleted && !$0.isNextUp }
    }

    private var scheduleTasks: [PlanItem] {
        planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue == 3 && !$0.isCompleted && !$0.isNextUp }
    }

    private var delegateTasks: [PlanItem] {
        planItems.filter { $0.urgency == "urgent" && $0.priorityValue < 3 && !$0.isCompleted && !$0.isNextUp }
    }

    private var eliminateTasks: [PlanItem] {
        planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue < 3 && !$0.isCompleted && !$0.isNextUp }
    }

    // MARK: - Category Grouping
    private var tasksByCategory: [(category: String, tasks: [PlanItem])] {
        let categories = ["deep_work", "shallow_work", "meetings", "maintenance", "creative", "strategic"]
        return categories.compactMap { category in
            let filtered = planItems.filter { $0.taskType == category && !$0.isCompleted && !$0.isNextUp }
            guard !filtered.isEmpty else { return nil }
            return (category: category.localizedCategory, tasks: filtered)
        }
    }

    // MARK: - Duration Grouping
    private var tasksByDuration: [(bucket: String, tasks: [PlanItem])] {
        let buckets: [(String, ClosedRange<Int>)] = [
            ("< 15 Min", 0...14),
            ("15-30 Min", 15...29),
            ("30-60 Min", 30...59),
            ("> 60 Min", 60...999)
        ]
        return buckets.compactMap { (label, range) in
            let filtered = planItems.filter {
                !$0.isCompleted && !$0.isNextUp && range.contains($0.effectiveDuration)
            }
            guard !filtered.isEmpty else { return nil }
            return (bucket: label, tasks: filtered)
        }
    }

    // MARK: - Due Date Grouping
    private var tasksByDueDate: [(section: String, tasks: [PlanItem])] {
        let calendar = Calendar.current
        let today = Date()

        var grouped: [(String, [PlanItem])] = []

        let todayTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted, !$0.isNextUp else { return false }
            return calendar.isDateInToday(due)
        }
        if !todayTasks.isEmpty { grouped.append(("Heute", todayTasks)) }

        let tomorrowTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted, !$0.isNextUp else { return false }
            return calendar.isDateInTomorrow(due)
        }
        if !tomorrowTasks.isEmpty { grouped.append(("Morgen", tomorrowTasks)) }

        let weekTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted, !$0.isNextUp else { return false }
            return calendar.isDate(due, equalTo: today, toGranularity: .weekOfYear) &&
                   !calendar.isDateInToday(due) && !calendar.isDateInTomorrow(due)
        }
        if !weekTasks.isEmpty { grouped.append(("Diese Woche", weekTasks)) }

        let laterTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted, !$0.isNextUp else { return false }
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: today) else { return false }
            return due > nextWeek
        }
        if !laterTasks.isEmpty { grouped.append(("Später", laterTasks)) }

        let noDueDateTasks = planItems.filter { $0.dueDate == nil && !$0.isCompleted && !$0.isNextUp }
        if !noDueDateTasks.isEmpty { grouped.append(("Ohne Fälligkeitsdatum", noDueDateTasks)) }

        return grouped
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Lade Tasks...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Fehler",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if planItems.isEmpty {
                    let emptyState = selectedMode.emptyStateMessage
                    ContentUnavailableView(
                        emptyState.title,
                        systemImage: "checklist",
                        description: Text(emptyState.description)
                    )
                } else {
                    VStack(spacing: 16) {
                        // Next Up Section
                        NextUpSection(
                            tasks: nextUpTasks,
                            onRemoveFromNextUp: { taskID in
                                if let item = planItems.first(where: { $0.id == taskID }) {
                                    updateNextUp(for: item, isNextUp: false)
                                }
                            }
                        )

                        // Main content based on view mode
                        switch selectedMode {
                        case .list:
                            listView
                        case .eisenhowerMatrix:
                            eisenhowerMatrixView
                        case .category:
                            categoryView
                        case .duration:
                            durationView
                        case .dueDate:
                            dueDateView
                        }
                    }
                }
            }
            .navigationTitle("FocusBlox")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedMode == .list {
                        EditButton()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    viewModeSwitcher

                    Button {
                        showCreateTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addTaskButton")
                }
            }
            .withSettingsToolbar()
            .sensoryFeedback(.impact(weight: .medium), trigger: reorderTrigger)
            .sensoryFeedback(.success, trigger: durationFeedback)
            .sensoryFeedback(.success, trigger: nextUpFeedback)
            .sheet(item: $selectedItemForDuration) { item in
                DurationPicker(currentDuration: item.effectiveDuration) { newDuration in
                    updateDuration(for: item, minutes: newDuration)
                    selectedItemForDuration = nil
                }
            }
            .sheet(isPresented: $showCreateTask) {
                CreateTaskView {
                    Task {
                        await loadTasks()
                    }
                }
            }
            .sheet(item: $taskToEdit) { task in
                EditTaskSheet(
                    task: task,
                    onSave: { title, priority, duration in
                        updateTask(task, title: title, priority: priority, duration: duration)
                    },
                    onDelete: {
                        deleteTask(task)
                    }
                )
            }
        }
        .task {
            await loadTasks()
        }
    }

    private func loadTasks() async {
        isLoading = true
        errorMessage = nil

        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            planItems = try await syncEngine.sync()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        planItems.move(fromOffsets: source, toOffset: destination)

        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateSortOrder(for: planItems)
            reorderTrigger.toggle()
        } catch {
            errorMessage = "Sortierung konnte nicht gespeichert werden."
        }
    }

    private func updateDuration(for item: PlanItem, minutes: Int?) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateDuration(itemID: item.id, minutes: minutes)
            durationFeedback.toggle()

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Dauer konnte nicht gespeichert werden."
        }
    }

    private func updateNextUp(for item: PlanItem, isNextUp: Bool) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateNextUp(itemID: item.id, isNextUp: isNextUp)
            nextUpFeedback.toggle()

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Next Up Status konnte nicht geändert werden."
        }
    }

    private func updateTask(_ task: PlanItem, title: String, priority: TaskPriority, duration: Int) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(itemID: task.id, title: title, priority: priority, duration: duration)

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Task konnte nicht aktualisiert werden."
        }
    }

    private func deleteTask(_ task: PlanItem) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.deleteTask(itemID: task.id)

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Task konnte nicht gelöscht werden."
        }
    }

    // MARK: - View Mode Switcher (Swift Liquid Glass)
    private var viewModeSwitcher: some View {
        Menu {
            ForEach(ViewMode.allCases) { mode in
                Button {
                    withAnimation(.smooth) {
                        selectedMode = mode
                    }
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.icon)
                Text(selectedMode.rawValue)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("viewModeSwitcher")
    }

    // MARK: - List View
    private var listView: some View {
        List {
            ForEach(backlogTasks) { item in
                BacklogRow(
                    item: item,
                    onDurationTap: { selectedItemForDuration = item },
                    onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                    onTap: { taskToEdit = item }
                )
            }
            .onMove(perform: moveItems)
        }
        .listStyle(.plain)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Eisenhower Matrix View
    private var eisenhowerMatrixView: some View {
        ScrollView {
            VStack(spacing: 16) {
                QuadrantCard(
                    title: "Do First",
                    subtitle: "Dringend + Wichtig",
                    color: .red,
                    icon: "exclamationmark.3",
                    tasks: doFirstTasks,
                    onDurationTap: { item in selectedItemForDuration = item },
                    onAddToNextUp: { item in updateNextUp(for: item, isNextUp: true) }
                )

                QuadrantCard(
                    title: "Schedule",
                    subtitle: "Nicht dringend + Wichtig",
                    color: .yellow,
                    icon: "calendar",
                    tasks: scheduleTasks,
                    onDurationTap: { item in selectedItemForDuration = item },
                    onAddToNextUp: { item in updateNextUp(for: item, isNextUp: true) }
                )

                QuadrantCard(
                    title: "Delegate",
                    subtitle: "Dringend + Weniger wichtig",
                    color: .orange,
                    icon: "person.2",
                    tasks: delegateTasks,
                    onDurationTap: { item in selectedItemForDuration = item },
                    onAddToNextUp: { item in updateNextUp(for: item, isNextUp: true) }
                )

                QuadrantCard(
                    title: "Eliminate",
                    subtitle: "Nicht dringend + Weniger wichtig",
                    color: .green,
                    icon: "trash",
                    tasks: eliminateTasks,
                    onDurationTap: { item in selectedItemForDuration = item },
                    onAddToNextUp: { item in updateNextUp(for: item, isNextUp: true) }
                )
            }
            .padding()
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Category View
    private var categoryView: some View {
        List {
            ForEach(tasksByCategory, id: \.category) { group in
                Section(header: Text(group.category)) {
                    ForEach(group.tasks) { item in
                        BacklogRow(
                            item: item,
                            onDurationTap: { selectedItemForDuration = item },
                            onAddToNextUp: { updateNextUp(for: item, isNextUp: true) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Duration View
    private var durationView: some View {
        List {
            ForEach(tasksByDuration, id: \.bucket) { group in
                Section(header: Text(group.bucket)) {
                    ForEach(group.tasks) { item in
                        BacklogRow(
                            item: item,
                            onDurationTap: { selectedItemForDuration = item },
                            onAddToNextUp: { updateNextUp(for: item, isNextUp: true) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Due Date View
    private var dueDateView: some View {
        List {
            ForEach(tasksByDueDate, id: \.section) { group in
                Section(header: Text(group.section)) {
                    ForEach(group.tasks) { item in
                        BacklogRow(
                            item: item,
                            onDurationTap: { selectedItemForDuration = item },
                            onAddToNextUp: { updateNextUp(for: item, isNextUp: true) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadTasks()
        }
    }
}

// MARK: - String Extension for Category Localization
private extension String {
    var localizedCategory: String {
        switch self {
        case "deep_work": return "Deep Work"
        case "shallow_work": return "Shallow Work"
        case "meetings": return "Meetings"
        case "maintenance": return "Maintenance"
        case "creative": return "Creative"
        case "strategic": return "Strategic"
        case "income": return "Geld verdienen"
        case "recharge": return "Energie aufladen"
        case "learning": return "Lernen"
        case "giving_back": return "Weitergeben"
        default: return self.capitalized
        }
    }
}

// MARK: - Quadrant Card

struct QuadrantCard: View {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
    let tasks: [PlanItem]
    let onDurationTap: (PlanItem) -> Void
    let onAddToNextUp: (PlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(color)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tasks.count)")
                    .font(.title2.bold())
                    .foregroundStyle(color)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if tasks.isEmpty {
                Text("Keine Tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(tasks.prefix(5)) { task in
                    BacklogRow(
                        item: task,
                        onDurationTap: { onDurationTap(task) },
                        onAddToNextUp: { onAddToNextUp(task) }
                    )
                    .padding(.horizontal, 8)
                }

                if tasks.count > 5 {
                    Text("+ \(tasks.count - 5) weitere")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }
}
