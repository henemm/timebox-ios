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
import Security
import EventKit

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

    /// Draws concentric rings with dark gaps as a template image.
    /// Matches the app icon style: distinct rings separated by visible gaps.
    /// Template images adapt automatically to Dark/Light Mode.
    static func makeMenuBarIcon(size: NSSize) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let maxRadius = min(rect.width, rect.height) / 2
            let outerRingWidth = maxRadius * 0.28
            let midRingWidth = maxRadius * 0.22

            // Outer ring (stroked, brightest)
            NSColor.black.withAlphaComponent(1.0).setStroke()
            let outerPath = NSBezierPath()
            outerPath.appendOval(in: rect.insetBy(dx: outerRingWidth / 2, dy: outerRingWidth / 2))
            outerPath.lineWidth = outerRingWidth
            outerPath.stroke()

            // Middle ring
            NSColor.black.withAlphaComponent(0.75).setStroke()
            let midRadius = maxRadius * 0.54
            let midRect = NSRect(
                x: center.x - midRadius, y: center.y - midRadius,
                width: midRadius * 2, height: midRadius * 2
            )
            let midPath = NSBezierPath()
            midPath.appendOval(in: midRect.insetBy(dx: midRingWidth / 2, dy: midRingWidth / 2))
            midPath.lineWidth = midRingWidth
            midPath.stroke()

            // Inner core
            NSColor.black.withAlphaComponent(0.60).setFill()
            let coreRadius = maxRadius * 0.13
            let coreRect = NSRect(
                x: center.x - coreRadius, y: center.y - coreRadius,
                width: coreRadius * 2, height: coreRadius * 2
            )
            NSBezierPath(ovalIn: coreRect).fill()

            return true
        }
        image.isTemplate = true
        return image
    }

    private static let allDoneImage = NSImage(
        systemSymbolName: "checkmark.circle.fill",
        accessibilityDescription: "FocusBlox — alle Tasks erledigt"
    )

    func setup(container: ModelContainer, eventKitRepository: any EventKitRepositoryProtocol) {
        self.eventKitRepo = eventKitRepository
        self.container = container

        // Programmatic concentric circles as template image
        idleImage = Self.makeMenuBarIcon(size: NSSize(width: 18, height: 18))

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
        // Bug #290: Width fixed, height intrinsic (`.fixedSize` on MenuBarView).
        // NSHostingController computes the height from the SwiftUI content; we
        // only seed an initial size so the popover is sized before first display.
        pop.contentSize = NSSize(width: 300, height: 300)
        pop.behavior = .transient
        let hosting = NSHostingController(
            rootView: MenuBarView()
                .modelContainer(container)
                .environment(\.eventKitRepository, eventKitRepository)
        )
        hosting.sizingOptions = [.intrinsicContentSize]
        pop.contentViewController = hosting

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
    @State private var dayViewForcedPhase: DayPhase?
    @AppStorage("intentionJustSet") private var intentionJustSet: Bool = false

    /// SyncedSettings für iCloud KV Store Sync zwischen Geräten
    private let syncedSettings = SyncedSettings()

    /// Shared EventKitRepository für alle Views (BACKLOG-002)
    /// Uses MockEventKitRepository with pre-seeded data during UI testing
    private let eventKitRepository: any EventKitRepositoryProtocol = {
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            let mock = MockEventKitRepository()
            mock.mockCalendarAuthStatus = .fullAccess
            mock.mockReminderAuthStatus = .fullAccess

            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)

            // Mock Calendar Events for timeline testing
            let meeting1Start = calendar.date(byAdding: .hour, value: 8, to: startOfDay)!
            let meeting1End = calendar.date(byAdding: .minute, value: 30, to: meeting1Start)!
            let meeting1 = CalendarEvent(
                id: "mock-event-1",
                title: "Team Meeting",
                startDate: meeting1Start,
                endDate: meeting1End,
                isAllDay: false,
                calendarColor: nil,
                notes: nil
            )

            let meeting2Start = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
            let meeting2End = calendar.date(byAdding: .minute, value: 60, to: meeting2Start)!
            let meeting2 = CalendarEvent(
                id: "mock-event-2",
                title: "Lunch Meeting",
                startDate: meeting2Start,
                endDate: meeting2End,
                isAllDay: false,
                calendarColor: nil,
                notes: nil
            )

            mock.mockEvents = [meeting1, meeting2]

            // Mock Focus Blocks for timeline testing
            let block1Start = calendar.date(byAdding: .hour, value: 9, to: startOfDay)!
            let block1End = calendar.date(byAdding: .hour, value: 11, to: startOfDay)!
            let focusBlock1 = FocusBlock(
                id: "mock-block-1",
                title: "Focus Block 09:00",
                startDate: block1Start,
                endDate: block1End,
                taskIDs: [],
                completedTaskIDs: []
            )

            let block2Start = calendar.date(byAdding: .hour, value: 14, to: startOfDay)!
            let block2End = calendar.date(byAdding: .hour, value: 16, to: startOfDay)!
            let focusBlock2 = FocusBlock(
                id: "mock-block-2",
                title: "Deep Work 14:00",
                startDate: block2Start,
                endDate: block2End,
                taskIDs: [],
                completedTaskIDs: []
            )

            if !ProcessInfo.processInfo.arguments.contains("--empty-morning") {
                mock.mockFocusBlocks = [focusBlock1, focusBlock2]
            }

            return mock
        }
        return EventKitRepository()
    }()

    init() {
        // CRITICAL: Required for the app to receive keyboard and mouse events
        NSApplication.shared.setActivationPolicy(.regular)

        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

        do {
            if isUITesting {
                // In-memory store for UI tests — no CloudKit, no persistence
                let schema = Schema([LocalTask.self, TaskMetadata.self])
                let config = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                container = try ModelContainer(for: schema, configurations: [config])
                Self.seedUITestData(into: container.mainContext)
            } else {
                container = try MacModelContainer.create()
            }
            QuickCaptureController.shared.setup(with: container)
            if !isUITesting && !ProcessInfo.processInfo.environment.keys.contains("XCTestBundlePath") {
                indexQuickCaptureAction()
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Bug 102: Pull BEFORE push — verhindert dass leere lokale Werte Remote ueberschreiben
        if !isUITesting {
            syncedSettings.pullFromCloud()
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
            ContentView(selectedSection: $selectedSection, dayViewForcedPhase: dayViewForcedPhase)
                .environment(\.eventKitRepository, eventKitRepository)
                .environment(syncMonitor)
                .environment(deferredSort)
                .environment(deferredCompletion)
                .sheet(isPresented: $showShortcuts) {
                    KeyboardShortcutsView()
                }
                .onAppear {
                    let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

                    // Ensure window can receive keyboard/mouse events
                    DispatchQueue.main.async {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
                    }

                    // Skip production-only startup tasks in UI testing mode
                    if !isUITesting {
                        syncMonitor.startRemoteChangeMonitoring(container: container)
                        // One-time cleanup: Remove leaked test data from persistent store
                        Self.cleanupLeakedTestData(in: container.mainContext)
                        // MAC_025b: Migrate reminders-sourced tasks to local (idempotent, same as iOS)
                        RemindersImportService.migrateRemindersToLocal(in: container.mainContext)
                        // Bug 38: Force CloudKit to sync all extended attribute fields
                        MacModelContainer.forceCloudKitFieldSync(in: container.mainContext)
                        // BUG_108: Order matters — migrate + dedup first to ensure clean state, then repair
                        RecurrenceService.migrateToTemplateModel(in: container.mainContext)
                        RecurrenceService.deduplicateTemplates(in: container.mainContext)
                        RecurrenceService.deduplicateChildInstances(in: container.mainContext)
                        RecurrenceService.repairOrphanedRecurringSeries(in: container.mainContext)
                        // Background title improvement + enrichment for tasks from Watch, Siri, etc.
                        let mainContext = container.mainContext
                        let titleEngine = TaskTitleEngine(modelContext: mainContext)
                        Task { await titleEngine.improveAllPendingTitles() }
                        // RW 1.5: Migrate any leftover "raw" tasks to "active" (Refiner removed)
                        let rawPredicate = #Predicate<LocalTask> { $0.lifecycleStatus == "raw" }
                        if let rawTasks = try? mainContext.fetch(
                            FetchDescriptor<LocalTask>(predicate: rawPredicate)
                        ), !rawTasks.isEmpty {
                            for task in rawTasks {
                                task.confirmSuggestions()
                            }
                            try? mainContext.save()
                        }
                        let enrichment = SmartTaskEnrichmentService(modelContext: mainContext)
                        Task { await enrichment.enrichAllTbdTasks() }
                        // Spotlight: reindex all active tasks so they appear in system search
                        let spotlightContext = container.mainContext
                        Task { try? await SpotlightIndexingService.shared.reindexAllTasks(context: spotlightContext) }
                        // RW_4.1: Soft Evening Reset — clear unfinished Next-Up on new day
                        let resetCount = (try? EveningResetService.performResetIfNeeded(
                            context: container.mainContext
                        )) ?? 0
                        if resetCount > 0 {
                            Task {
                                await SmartNotificationEngine.reconcile(
                                    reason: .taskChanged,
                                    container: container,
                                    eventKitRepo: eventKitRepository
                                )
                            }
                        }
                    }
                    // Bug 58: Menu bar icon (after app is fully initialized)
                    MenuBarController.shared.setup(
                        container: container,
                        eventKitRepository: eventKitRepository
                    )
                    // Register interactive notification actions + delegate
                    NotificationService.registerDueDateActions()
                    let delegate = NotificationActionDelegate(container: container, eventKitRepository: eventKitRepository)
                    UNUserNotificationCenter.current().delegate = delegate
                    notificationDelegate = delegate
                    // Request notification permission + schedule due date notifications
                    Task {
                        _ = await NotificationService.requestPermission()
                        await SmartNotificationEngine.reconcile(
                            reason: .appForeground,
                            container: container,
                            eventKitRepo: eventKitRepository
                        )
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
                        syncedSettings.pullFromCloud()  // Bug 102: Pull BEFORE push
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
                .onReceive(NotificationCenter.default.publisher(for: NotificationActionDelegate.navigateToDayViewNotification)) { notification in
                    selectedSection = .day
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let phaseStr = notification.userInfo?["phase"] as? String {
                        switch phaseStr {
                        case "morning": dayViewForcedPhase = .morning
                        case "evening": dayViewForcedPhase = .evening
                        default: dayViewForcedPhase = nil
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .navigateToBacklog)) { _ in
                    selectedSection = .backlog
                }
                .onChange(of: selectedSection) { _, newSection in
                    if newSection != .day { dayViewForcedPhase = nil }
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

    // rescheduleDueDateNotifications removed — replaced by SmartNotificationEngine.reconcile()

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

    /// Runtime check: verify CloudKit entitlement is embedded in the running binary.
    /// Debug builds launched by launchd (auto-launch at login) may lack proper entitlements,
    /// causing a SIGTRAP in PFCloudKitContainerProvider that cannot be caught.
    private static func hasCloudKitEntitlement() -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            Bundle.main.bundleURL as CFURL, [], &staticCode
        ) == errSecSuccess, let code = staticCode else {
            print("[CloudKit] macOS: Code-Signatur nicht pruefbar")
            return false
        }

        var signingInfo: CFDictionary?
        guard SecCodeCopySigningInformation(
            code, SecCSFlags(rawValue: kSecCSSigningInformation), &signingInfo
        ) == errSecSuccess,
              let info = signingInfo as? [String: Any],
              let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
              let services = entitlements["com.apple.developer.icloud-services"] as? [String]
        else {
            print("[CloudKit] macOS: CloudKit-Entitlement nicht gefunden in Code-Signatur")
            return false
        }
        return services.contains("CloudKit")
    }

    static func create() throws -> ModelContainer {
        let schema = Schema([LocalTask.self, TaskMetadata.self])
        let hasICloud = FileManager.default.ubiquityIdentityToken != nil
        let hasEntitlement = hasCloudKitEntitlement()

        let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )

        let config: ModelConfiguration
        if !hasICloud || !hasEntitlement {
            print("[CloudKit] macOS: iCloud=\(hasICloud), Entitlement=\(hasEntitlement) — lokaler Speicher ohne CloudKit")
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        } else if appGroupURL != nil {
            print("[CloudKit] macOS: App Group verfügbar, CloudKit .private(iCloud.com.henning.focusblox)")
            config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .private("iCloud.com.henning.focusblox")
            )
        } else {
            print("[CloudKit] macOS: App Group NICHT verfügbar, CloudKit .private(iCloud.com.henning.focusblox) ohne Group Container")
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
                if !(task.tags ?? []).isEmpty { task.tags = task.tags; touchedFields += 1 }
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

        // Recurring: daily template + 3 children (MAC_028: stacking needs 2+ children)
        // All children use today's date so they land in the SAME tier section (not split across overdue)
        let group1 = "uitest-recurring-group-1"
        let tmpl1 = LocalTask(title: "[MOCK] Taeglich lesen", importance: 2, tags: ["learning"], estimatedDuration: 15, recurrencePattern: "daily", recurrenceGroupID: group1)
        tmpl1.isTemplate = true
        let child1 = LocalTask(title: "[MOCK] Taeglich lesen", importance: 2, tags: ["learning"], dueDate: Date(), estimatedDuration: 15, recurrencePattern: "daily", recurrenceGroupID: group1)
        let child1b = LocalTask(title: "[MOCK] Taeglich lesen", importance: 2, tags: ["learning"], dueDate: Date(), estimatedDuration: 15, recurrencePattern: "daily", recurrenceGroupID: group1)
        let child1c = LocalTask(title: "[MOCK] Taeglich lesen", importance: 2, tags: ["learning"], dueDate: Date(), estimatedDuration: 15, recurrencePattern: "daily", recurrenceGroupID: group1)

        // Recurring: weekly template + 2 children (MAC_028: stacking needs 2+ children)
        let group2 = "uitest-recurring-group-2"
        let tmpl2 = LocalTask(title: "[MOCK] Wochenreview", importance: 3, tags: ["planning"], estimatedDuration: 30, recurrencePattern: "weekly", recurrenceWeekdays: [5], recurrenceGroupID: group2)
        tmpl2.isTemplate = true
        let child2 = LocalTask(title: "[MOCK] Wochenreview", importance: 3, tags: ["planning"], dueDate: Date(), estimatedDuration: 30, recurrencePattern: "weekly", recurrenceWeekdays: [5], recurrenceGroupID: group2)
        let child2b = LocalTask(title: "[MOCK] Wochenreview", importance: 3, tags: ["planning"], dueDate: Date(), estimatedDuration: 30, recurrencePattern: "weekly", recurrenceWeekdays: [5], recurrenceGroupID: group2)

        // Recurring: biweekly template + child (for recurrence display test)
        let group3 = "uitest-recurring-group-3"
        let tmpl3 = LocalTask(title: "[MOCK] Zweiwochentlich aufraeumen", importance: 1, tags: ["maintenance"], estimatedDuration: 45, recurrencePattern: "biweekly", recurrenceGroupID: group3)
        tmpl3.isTemplate = true
        let child3 = LocalTask(title: "[MOCK] Zweiwochentlich aufraeumen", importance: 1, tags: ["maintenance"], dueDate: Date(), estimatedDuration: 45, recurrencePattern: "biweekly", recurrenceGroupID: group3)

        // Completed task
        let completed = LocalTask(title: "[MOCK] Erledigte Aufgabe", importance: 2, estimatedDuration: 20, urgency: "not_urgent")
        completed.isCompleted = true
        completed.completedAt = Date()

        // FEATURE_012: DEP-Blocker task pair (fixed UUID for UI test targeting)
        // depBlocker has 1 dependent → DEP boost +3: score = 25 (without fix) or 28 (with fix)
        let depBlockerUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        let depBlocker = LocalTask(
            uuid: depBlockerUUID,
            title: "[MOCK] DEP-Blocker Task",
            importance: 2,
            estimatedDuration: 30,
            urgency: "not_urgent",
            taskType: "shallow_work"
        )
        let depDependent = LocalTask(title: "[MOCK] DEP-Dependent Task", importance: 1, estimatedDuration: 15, urgency: "not_urgent")
        depDependent.blockerTaskID = depBlocker.id

        for task in [task1, task2, task3, longTitleTask, backlogTask1, backlogTask2, tmpl1, child1, child1b, child1c, tmpl2, child2, child2b, tmpl3, child3, completed, depBlocker, depDependent] {
            context.insert(task)
        }
        try? context.save()

    }
}
