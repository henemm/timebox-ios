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

// MARK: - Menu Bar Controller

/// Manages the menu bar status item with autosaveName for position persistence.
/// Replaces SwiftUI MenuBarExtra to prevent Hidden Bar (and similar tools)
/// from permanently hiding the icon in an unreachable tier (Bug 58).
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    private static let autosaveName = "com.focusblox.menubar"
    private static let positionKey = "NSStatusItem Preferred Position \(autosaveName)"

    func setup(container: ModelContainer, eventKitRepository: any EventKitRepositoryProtocol) {
        // Pre-set visible position on first launch so menu bar managers
        // (e.g. Hidden Bar) don't hide the icon in an unreachable tier.
        if UserDefaults.standard.object(forKey: Self.positionKey) == nil {
            UserDefaults.standard.set(300.0, forKey: Self.positionKey)
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = Self.autosaveName

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "cube.fill",
                accessibilityDescription: "FocusBlox"
            )
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
    let container: ModelContainer
    @State private var quickCapture = QuickCaptureController.shared
    @State private var showShortcuts = false
    @State private var syncMonitor = CloudKitSyncMonitor()
    @FocusedValue(\.taskActions) private var taskActions
    @State private var showUndoAlert = false
    @State private var undoResultMessage = ""

    /// SyncedSettings fuer iCloud KV Store Sync zwischen Geraeten
    private let syncedSettings = SyncedSettings()

    /// Shared EventKitRepository fuer alle Views (BACKLOG-002)
    private let eventKitRepository: any EventKitRepositoryProtocol = EventKitRepository()

    init() {
        // CRITICAL: Required for the app to receive keyboard and mouse events
        NSApplication.shared.setActivationPolicy(.regular)

        do {
            container = try MacModelContainer.create()
            QuickCaptureController.shared.setup(with: container)
            indexQuickCaptureAction()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Lokale Einstellungen in iCloud pushen
        syncedSettings.pushToCloud()
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
            ContentView()
                .environment(\.eventKitRepository, eventKitRepository)
                .environment(syncMonitor)
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
                    // Bug 38: Force CloudKit to sync all extended attribute fields
                    MacModelContainer.forceCloudKitFieldSync(in: container.mainContext)
                    // Repair orphaned recurring series (missing successors)
                    RecurrenceService.repairOrphanedRecurringSeries(in: container.mainContext)
                    // Migrate recurring tasks to template model (one-time)
                    RecurrenceService.migrateToTemplateModel(in: container.mainContext)
                    RecurrenceService.deduplicateTemplates(in: container.mainContext)
                    // Bug 58: Menu bar icon (after app is fully initialized)
                    MenuBarController.shared.setup(
                        container: container,
                        eventKitRepository: eventKitRepository
                    )
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
        }
    }

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }
        if identifier == "com.focusblox.quickcapture" {
            quickCapture.showPanel()
        }
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
