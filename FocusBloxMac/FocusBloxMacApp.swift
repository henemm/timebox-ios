//
//  FocusBloxMacApp.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData
import CoreSpotlight
import AppKit
import UserNotifications

// MARK: - Menu Bar Controller

/// Manages the menu bar status item with autosaveName for position persistence.
/// Replaces SwiftUI MenuBarExtra to prevent Hidden Bar (and similar tools)
/// from permanently hiding the icon in an unreachable tier (Bug 58).
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventKitRepo: (any EventKitRepositoryProtocol)?
    private var container: ModelContainer?
    private var iconTimer: Timer?
    private var cachedBlock: FocusBlock?
    private var cachedTaskDurations: [(id: String, durationMinutes: Int)] = []
    private var lastFetchTime = Date.distantPast
    private static let fetchInterval: TimeInterval = 15

    private static let autosaveName = "com.focusblox.menubar"
    private static let positionKey = "NSStatusItem Preferred Position \(autosaveName)"

    private var idleImage: NSImage?

    /// Extracts the center of the app icon (the concentric circles),
    /// crops away the rounded-rect background, and renders as grayscale.
    static func makeMenuBarIcon(from source: NSImage, size: NSSize) -> NSImage {
        // Step 1: Crop inner 60% to remove rounded-rect background
        let sourceSize = source.size
        let inset = sourceSize.width * 0.2
        let cropRect = NSRect(
            x: inset, y: inset,
            width: sourceSize.width - inset * 2,
            height: sourceSize.height - inset * 2
        )

        // Step 2: Draw cropped + circular mask at target size
        let result = NSImage(size: size, flipped: false) { rect in
            // Circular clip to remove any remaining background corners
            NSBezierPath(ovalIn: rect).addClip()
            source.draw(in: rect, from: cropRect, operation: .sourceOver, fraction: 1.0)
            return true
        }

        // Step 3: Convert to grayscale
        guard let tiff = result.tiffRepresentation,
              let ciImage = CIImage(data: tiff),
              let filter = CIFilter(name: "CIColorMonochrome") else {
            return result
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIColor(color: .gray)!, forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        guard let output = filter.outputImage else { return result }
        let rep = NSCIImageRep(ciImage: output)
        let grayscale = NSImage(size: size)
        grayscale.addRepresentation(rep)
        return grayscale
    }
    private static let allDoneImage = NSImage(
        systemSymbolName: "checkmark.circle.fill",
        accessibilityDescription: "FocusBlox — alle Tasks erledigt"
    )

    func setup(container: ModelContainer, eventKitRepository: any EventKitRepositoryProtocol) {
        self.eventKitRepo = eventKitRepository
        self.container = container

        // Use app icon in grayscale for menu bar
        if let appIcon = NSApp.applicationIconImage {
            idleImage = Self.makeMenuBarIcon(from: appIcon, size: NSSize(width: 18, height: 18))
        }

        // Pre-set visible position on first launch so menu bar managers
        // (e.g. Hidden Bar) don't hide the icon in an unreachable tier.
        if UserDefaults.standard.object(forKey: Self.positionKey) == nil {
            UserDefaults.standard.set(300.0, forKey: Self.positionKey)
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = Self.autosaveName

        if let button = item.button {
            button.image = idleImage
            button.action = #selector(togglePopover)
            button.target = self
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 300, height: 450)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .modelContainer(container)
                .environment(\.eventKitRepository, eventKitRepository)
        )

        self.statusItem = item
        self.popover = pop

        // Start 1s timer for dynamic icon updates
        iconTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateIcon()
        }
        updateIcon()
    }

    private func updateIcon() {
        let now = Date()

        // Re-fetch from EventKit every 15s (not every second)
        if now.timeIntervalSince(lastFetchTime) >= Self.fetchInterval {
            lastFetchTime = now
            let blocks = try? eventKitRepo?.fetchFocusBlocks(for: now)
            cachedBlock = blocks?.first { $0.isActive }
            refreshTaskDurations()
        }

        let state = MenuBarIconState.from(block: cachedBlock, now: now, taskEndDate: currentTaskEndDate(now: now))
        guard let button = statusItem?.button else { return }

        switch state {
        case .idle:
            button.title = ""
            button.image = idleImage
        case .active(let timerText):
            button.image = nil
            button.title = timerText
        case .allDone:
            button.title = ""
            button.image = Self.allDoneImage
        }
    }

    private func refreshTaskDurations() {
        guard let block = cachedBlock, let container else {
            cachedTaskDurations = []
            return
        }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalTask>()
        guard let allTasks = try? context.fetch(descriptor) else {
            cachedTaskDurations = []
            return
        }
        cachedTaskDurations = block.taskIDs.compactMap { taskID in
            guard let task = allTasks.first(where: { $0.id == taskID }) else { return nil }
            return (id: taskID, durationMinutes: task.estimatedDuration ?? 15)
        }
    }

    private func currentTaskEndDate(now: Date) -> Date? {
        guard let block = cachedBlock, !cachedTaskDurations.isEmpty else { return nil }
        guard let currentTaskID = block.taskIDs.first(where: { !block.completedTaskIDs.contains($0) }) else {
            return nil
        }
        return TimerCalculator.plannedTaskEndDate(
            blockStartDate: block.startDate,
            blockEndDate: block.endDate,
            taskDurations: cachedTaskDurations,
            currentTaskID: currentTaskID
        )
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

// MARK: - App

@main
struct FocusBloxMacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer
    @State private var quickCapture = QuickCaptureController.shared
    @State private var showShortcuts = false
    @State private var syncMonitor = CloudKitSyncMonitor()
    @State private var deferredSort = DeferredSortController()
    @State private var deferredCompletion = DeferredCompletionController()
    @FocusedValue(\.taskActions) private var taskActions
    @State private var showUndoAlert = false
    @State private var undoResultMessage = ""
    @State private var notificationDelegate: NotificationActionDelegate?
    @State private var selectedSection: MainSection = .backlog
    @AppStorage("intentionJustSet") private var intentionJustSet: Bool = false

    /// SyncedSettings fuer iCloud KV Store Sync zwischen Geraeten
    private let syncedSettings = SyncedSettings()

    /// Shared EventKitRepository fuer alle Views (BACKLOG-002)
    private let eventKitRepository: any EventKitRepositoryProtocol = EventKitRepository()

    init() {
        // CRITICAL: Required for the app to receive keyboard and mouse events
        NSApplication.shared.setActivationPolicy(.regular)

        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

        do {
            if isUITesting {
                // In-memory store for UI tests — no CloudKit, no persistence
                let schema = Schema([LocalTask.self, TaskMetadata.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [config])
                Self.seedUITestData(into: container.mainContext)
            } else {
                container = try MacModelContainer.create()
            }
            QuickCaptureController.shared.setup(with: container)
            indexQuickCaptureAction()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Lokale Einstellungen in iCloud pushen
        if !isUITesting {
            syncedSettings.pushToCloud()
        }
    }

    private func indexQuickCaptureAction() {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = "Neue Task erstellen"
        attributeSet.contentDescription = "Task schnell in FocusBlox erfassen"
        attributeSet.keywords = ["task", "todo", "aufgabe", "focusblox"]

        let item = CSSearchableItem(
            uniqueIdentifier: "com.focusblox.quickcapture",
            domainIdentifier: "actions",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(selectedSection: $selectedSection)
                .environment(\.eventKitRepository, eventKitRepository)
                .environment(syncMonitor)
                .environment(deferredSort)
                .environment(deferredCompletion)
                .sheet(isPresented: $showShortcuts) {
                    KeyboardShortcutsView()
                }
                .onAppear {
                    syncMonitor.startRemoteChangeMonitoring(container: container)
                    // Ensure window can receive keyboard/mouse events
                    DispatchQueue.main.async {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
                    }
                    // One-time cleanup: Remove leaked test data from persistent store
                    Self.cleanupLeakedTestData(in: container.mainContext)
                    // Bug 38: Force CloudKit to sync all extended attribute fields
                    MacModelContainer.forceCloudKitFieldSync(in: container.mainContext)
                    // Repair orphaned recurring series (missing successors)
                    RecurrenceService.repairOrphanedRecurringSeries(in: container.mainContext)
                    // Migrate recurring tasks to template model (one-time)
                    RecurrenceService.migrateToTemplateModel(in: container.mainContext)
                    RecurrenceService.deduplicateTemplates(in: container.mainContext)
                    // Background title improvement + enrichment for tasks from Watch, Siri, etc.
                    let mainContext = container.mainContext
                    let titleEngine = TaskTitleEngine(modelContext: mainContext)
                    Task { await titleEngine.improveAllPendingTitles() }
                    let enrichment = SmartTaskEnrichmentService(modelContext: mainContext)
                    Task { await enrichment.enrichAllTbdTasks() }
                    // Spotlight: reindex all active tasks so they appear in system search
                    let spotlightContext = container.mainContext
                    Task { try? await SpotlightIndexingService.shared.reindexAllTasks(context: spotlightContext) }
                    // Bug 58: Menu bar icon (after app is fully initialized)
                    MenuBarController.shared.setup(
                        container: container,
                        eventKitRepository: eventKitRepository
                    )
                    // Register interactive notification actions + delegate
                    NotificationService.registerDueDateActions()
                    let delegate = NotificationActionDelegate(container: container)
                    UNUserNotificationCenter.current().delegate = delegate
                    notificationDelegate = delegate
                    // Request notification permission + schedule due date notifications
                    Task {
                        _ = await NotificationService.requestPermission()
                        rescheduleDueDateNotifications()
                    }
                }
                .onOpenURL { url in
                    handleURL(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightActivity(activity)
                }
                .alert("Rückgängig", isPresented: $showUndoAlert) {
                    Button("OK") { }
                } message: {
                    Text(undoResultMessage)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        syncMonitor.triggerSync()
                        syncedSettings.pushToCloud()
                    }
                    if newPhase == .background {
                        Task { await deferredCompletion.flushAll() }
                    }
                }
                .onChange(of: intentionJustSet) { _, newValue in
                    if newValue {
                        selectedSection = .backlog
                        intentionJustSet = false
                    }
                }
        }
        .modelContainer(container)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Task") {
                    taskActions?.focusNewTask()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Quick Capture") {
                    quickCapture.togglePanel()
                }
                .keyboardShortcut(" ", modifiers: [.command, .shift])
            }

            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Complete Task") {
                    taskActions?.completeSelected()
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(taskActions?.hasSelection != true)

                Button("Edit Task") {
                    taskActions?.editSelected()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(taskActions?.hasSelection != true)

                Button("Delete Task") {
                    taskActions?.deleteSelected()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(taskActions?.hasSelection != true)
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo Completion") {
                    undoLastCompletion()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!TaskCompletionUndoService.canUndo)
            }

            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    showShortcuts = true
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }

        // Settings window (Cmd+,)
        Settings {
            MacSettingsView()
                .environment(\.eventKitRepository, eventKitRepository)
        }
        .modelContainer(container)
    }

    private func undoLastCompletion() {
        guard TaskCompletionUndoService.canUndo else {
            undoResultMessage = "Nichts zum Rückgängigmachen"
            showUndoAlert = true
            return
        }
        do {
            if let title = try TaskCompletionUndoService.undo(in: container.mainContext) {
                undoResultMessage = "\(title) wiederhergestellt"
            }
        } catch {
            undoResultMessage = "Fehler: \(error.localizedDescription)"
        }
        showUndoAlert = true
    }

    private func rescheduleDueDateNotifications() {
        let context = container.mainContext
        do {
            let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
            let tasksWithDueDate = allTasks
                .filter { $0.dueDate != nil && !$0.isCompleted }
                .map { (id: $0.id, title: $0.title, dueDate: $0.dueDate!) }
            NotificationService.rescheduleAllDueDateNotifications(tasks: tasksWithDueDate)
        } catch {
            print("Failed to fetch tasks for due date notifications: \(error)")
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "focusblox" else { return }
        if url.host == "add" {
            quickCapture.showPanel()
        } else if FocusBlock.eventID(from: url) != nil {
            // Deep link from Calendar — app comes to foreground automatically
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }
        if identifier == "com.focusblox.quickcapture" {
            quickCapture.showPanel()
        }
        // Task tapped in Spotlight — bring app to front (deep-link navigation not in scope)
    }
}

// MARK: - Mac Model Container

enum MacModelContainer {
    private static let appGroupID = "group.com.henning.focusblox"

    static func create() throws -> ModelContainer {
        let schema = Schema([LocalTask.self, TaskMetadata.self])

        let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )

        let config: ModelConfiguration
        if appGroupURL != nil {
            print("[CloudKit] macOS: App Group verfuegbar, CloudKit .private(iCloud.com.henning.focusblox)")
            config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .private("iCloud.com.henning.focusblox")
            )
        } else {
            print("[CloudKit] macOS: App Group NICHT verfuegbar, CloudKit .private(iCloud.com.henning.focusblox) ohne Group Container")
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.henning.focusblox")
            )
        }

        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Bug 38 V2: Only touch NON-NIL fields to avoid CloudKit conflicts.
    /// V1 gave nil values fresh timestamps, causing them to win over real values.
    @discardableResult
    static func forceCloudKitFieldSync(in context: ModelContext) -> Int {
        let key = "cloudKitFieldSyncV2"
        guard !UserDefaults.standard.bool(forKey: key) else { return 0 }

        do {
            let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
            guard !allTasks.isEmpty else {
                UserDefaults.standard.set(true, forKey: key)
                return 0
            }

            var touchedFields = 0
            for task in allTasks {
                if task.importance != nil { task.importance = task.importance; touchedFields += 1 }
                if task.urgency != nil { task.urgency = task.urgency; touchedFields += 1 }
                if task.estimatedDuration != nil { task.estimatedDuration = task.estimatedDuration; touchedFields += 1 }
                if task.dueDate != nil { task.dueDate = task.dueDate; touchedFields += 1 }
                if task.taskDescription != nil { task.taskDescription = task.taskDescription; touchedFields += 1 }
                if task.recurrencePattern != nil { task.recurrencePattern = task.recurrencePattern; touchedFields += 1 }
                if task.recurrenceWeekdays != nil { task.recurrenceWeekdays = task.recurrenceWeekdays; touchedFields += 1 }
                if task.recurrenceMonthDay != nil { task.recurrenceMonthDay = task.recurrenceMonthDay; touchedFields += 1 }
                if !task.tags.isEmpty { task.tags = task.tags; touchedFields += 1 }
                if !task.taskType.isEmpty { task.taskType = task.taskType; touchedFields += 1 }
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            print("[CloudKit] macOS V2 field sync: \(allTasks.count) tasks, \(touchedFields) non-nil fields touched")
            return allTasks.count
        } catch {
            print("[CloudKit] macOS V2 field sync failed: \(error)")
            return -1
        }
    }
}

// MARK: - Test Data Cleanup

extension FocusBloxMacApp {
    /// Continuous cleanup of test data that leaked into the persistent store.
    /// Runs on EVERY launch (not one-time) to catch any future leaks.
    static func cleanupLeakedTestData(in context: ModelContext) {
        let descriptor = FetchDescriptor<LocalTask>()
        guard let allTasks = try? context.fetch(descriptor) else { return }

        // Prefix patterns that identify test/mock data
        let testPrefixes = [
            "[MOCK] ",
            "Bug94 ", "Bug94Test", "Bug94Inspector", "Bug94Visible", "Bug94EmptyState",
            "Diagnose ",
            "UI Test Task ", "Badge Test Task ", "Inspector Test Task ",
            "Category Grid Test ", "Test Task ",
        ]

        var deletedCount = 0
        for task in allTasks {
            let shouldDelete =
                testPrefixes.contains(where: { task.title.hasPrefix($0) }) ||
                (task.recurrenceGroupID?.hasPrefix("uitest-") == true)

            if shouldDelete {
                context.delete(task)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try? context.save()
            print("[Cleanup] Deleted \(deletedCount) leaked test tasks from persistent store")
        }
    }
}

// MARK: - UI Test Mock Data

extension FocusBloxMacApp {
    static func seedUITestData(into context: ModelContext) {
        let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.title == "[MOCK] Task 1 #30min" })
        guard (try? context.fetch(descriptor))?.isEmpty ?? true else { return }

        // Next Up tasks
        let task1 = LocalTask(title: "[MOCK] Task 1 #30min", importance: 3, estimatedDuration: 30, urgency: "urgent")
        task1.isNextUp = true
        let task2 = LocalTask(title: "[MOCK] Task 2 #15min", importance: 2, estimatedDuration: 15, urgency: "not_urgent")
        task2.isNextUp = true
        let task3 = LocalTask(title: "[MOCK] Task 3 #45min", importance: 1, estimatedDuration: 45, urgency: "not_urgent")
        task3.isNextUp = true

        // Long-title Next Up task for truncation testing (Bug 86)
        let longTitleTask = LocalTask(title: "[MOCK] Startups anschreiben wegen Kapitalerhoehung", importance: 3, estimatedDuration: 30, urgency: "urgent")
        longTitleTask.isNextUp = true
        longTitleTask.taskType = "essentials"
        longTitleTask.dueDate = Date()

        // Badge-overflow backlog task: ALL badges set for truncation testing (Bug 86)
        let backlogTask1 = LocalTask(title: "[MOCK] Lohnsteuererklaerung einreichen", importance: 2, estimatedDuration: 25, urgency: "urgent")
        backlogTask1.tags = ["work", "urgent"]
        backlogTask1.taskType = "deep_work"
        backlogTask1.dueDate = Date()
        backlogTask1.recurrencePattern = "weekly"

        let backlogTask2 = LocalTask(title: "[MOCK] Backlog Task 2", importance: 1, estimatedDuration: 15, urgency: "not_urgent")
        backlogTask2.taskType = "shallow_work"

        // Recurring: daily template + child
        let group1 = "uitest-recurring-group-1"
        let tmpl1 = LocalTask(title: "[MOCK] Taeglich lesen", importance: 2, tags: ["learning"], estimatedDuration: 15, recurrencePattern: "daily", recurrenceGroupID: group1)
        tmpl1.isTemplate = true
        let child1 = LocalTask(title: "[MOCK] Taeglich lesen", importance: 2, tags: ["learning"], dueDate: Date(), estimatedDuration: 15, recurrencePattern: "daily", recurrenceGroupID: group1)

        // Recurring: weekly template + child
        let group2 = "uitest-recurring-group-2"
        let tmpl2 = LocalTask(title: "[MOCK] Wochenreview", importance: 3, tags: ["planning"], estimatedDuration: 30, recurrencePattern: "weekly", recurrenceWeekdays: [5], recurrenceGroupID: group2)
        tmpl2.isTemplate = true
        let child2 = LocalTask(title: "[MOCK] Wochenreview", importance: 3, tags: ["planning"], dueDate: Date(), estimatedDuration: 30, recurrencePattern: "weekly", recurrenceWeekdays: [5], recurrenceGroupID: group2)

        // Recurring: biweekly template + child (for recurrence display test)
        let group3 = "uitest-recurring-group-3"
        let tmpl3 = LocalTask(title: "[MOCK] Zweiwochentlich aufraeumen", importance: 1, tags: ["maintenance"], estimatedDuration: 45, recurrencePattern: "biweekly", recurrenceGroupID: group3)
        tmpl3.isTemplate = true
        let child3 = LocalTask(title: "[MOCK] Zweiwochentlich aufraeumen", importance: 1, tags: ["maintenance"], dueDate: Date(), estimatedDuration: 45, recurrencePattern: "biweekly", recurrenceGroupID: group3)

        // Completed task
        let completed = LocalTask(title: "[MOCK] Erledigte Aufgabe", importance: 2, estimatedDuration: 20, urgency: "not_urgent")
        completed.isCompleted = true
        completed.completedAt = Date()

        for task in [task1, task2, task3, longTitleTask, backlogTask1, backlogTask2, tmpl1, child1, tmpl2, child2, tmpl3, child3, completed] {
            context.insert(task)
        }
        try? context.save()
    }
}
