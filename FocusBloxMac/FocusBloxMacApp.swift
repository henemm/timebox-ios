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

@main
struct FocusBloxMacApp: App {
    let container: ModelContainer
    @State private var quickCapture = QuickCaptureController.shared
    @State private var showShortcuts = false
    @FocusedValue(\.taskActions) private var taskActions

    /// SyncedSettings fuer iCloud KV Store Sync zwischen Geraeten
    private let syncedSettings = SyncedSettings()

    /// Shared EventKitRepository fuer alle Views (BACKLOG-002)
    private let eventKitRepository: any EventKitRepositoryProtocol = EventKitRepository()

    init() {
        // CRITICAL: Set activation policy to regular app (not accessory/background)
        // This ensures the app can receive keyboard and mouse events
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
                .sheet(isPresented: $showShortcuts) {
                    KeyboardShortcutsView()
                }
                .onAppear {
                    // Ensure window can receive keyboard/mouse events
                    DispatchQueue.main.async {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
                    }
                    // Bug 38: Force CloudKit to sync all extended attribute fields
                    MacModelContainer.forceCloudKitFieldSync(in: container.mainContext)
                }
                .onOpenURL { url in
                    handleURL(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightActivity(activity)
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

            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    showShortcuts = true
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarView()
                .modelContainer(container)
        } label: {
            Label("FocusBlox", systemImage: "cube.fill")
        }
        .menuBarExtraStyle(.window)

        // Settings window (Cmd+,)
        Settings {
            MacSettingsView()
                .environment(\.eventKitRepository, eventKitRepository)
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
            print("[CloudKit] macOS: App Group verfuegbar, CloudKit .automatic")
            config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .automatic
            )
        } else {
            print("[CloudKit] macOS: App Group NICHT verfuegbar, CloudKit .automatic ohne Group Container")
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
        }

        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Bug 38: Force CloudKit to sync ALL fields by touching every task once.
    /// When new optional fields are added to LocalTask, CloudKit may not push them
    /// until the record is explicitly modified. This one-time migration ensures
    /// all extended attributes (importance, urgency, duration, etc.) are synced.
    @discardableResult
    static func forceCloudKitFieldSync(in context: ModelContext) -> Int {
        let key = "cloudKitFieldSyncV1"
        guard !UserDefaults.standard.bool(forKey: key) else { return 0 }

        do {
            let allTasks = try context.fetch(FetchDescriptor<LocalTask>())
            guard !allTasks.isEmpty else {
                UserDefaults.standard.set(true, forKey: key)
                return 0
            }

            for task in allTasks {
                // Touch extended attributes to mark record as dirty for CloudKit
                task.importance = task.importance
                task.urgency = task.urgency
                task.estimatedDuration = task.estimatedDuration
                task.dueDate = task.dueDate
                task.taskDescription = task.taskDescription
                task.recurrencePattern = task.recurrencePattern
                task.recurrenceWeekdays = task.recurrenceWeekdays
                task.recurrenceMonthDay = task.recurrenceMonthDay
                task.tags = task.tags
                task.taskType = task.taskType
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            print("[CloudKit] macOS Field sync migration: \(allTasks.count) tasks touched")
            return allTasks.count
        } catch {
            print("[CloudKit] macOS Field sync migration failed: \(error)")
            return -1
        }
    }
}
