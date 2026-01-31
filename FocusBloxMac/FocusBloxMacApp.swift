//
//  FocusBloxMacApp.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct FocusBloxMacApp: App {
    let container: ModelContainer
    @State private var quickCapture = QuickCaptureController.shared
    @State private var showShortcuts = false
    @FocusedValue(\.taskActions) private var taskActions

    init() {
        do {
            container = try MacModelContainer.create()
            // Setup global hotkey for Quick Capture
            QuickCaptureController.shared.setup(with: container)
            // Index Quick Capture action for Spotlight
            indexQuickCaptureAction()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Spotlight Indexing

    private func indexQuickCaptureAction() {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = "Neue Task erstellen"
        attributeSet.contentDescription = "Task schnell in FocusBlox erfassen"
        attributeSet.keywords = ["task", "todo", "aufgabe", "focusblox", "new task", "neue aufgabe"]

        let item = CSSearchableItem(
            uniqueIdentifier: "com.focusblox.quickcapture",
            domainIdentifier: "actions",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                print("Failed to index Quick Capture action: \(error)")
            }
        }
    }

    var body: some Scene {
        // Main Window
        WindowGroup {
            MainWindowView(showShortcuts: $showShortcuts)
                .onOpenURL { url in
                    handleURL(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightActivity(activity)
                }
        }
        .modelContainer(container)
        .commands {
            // File Menu - New Task
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

            // Edit Menu - Task Actions
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

            // Help Menu - Shortcuts
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    showShortcuts = true
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }

        // Menu Bar Widget
        MenuBarExtra {
            MenuBarView()
                .modelContainer(container)
        } label: {
            Label("FocusBlox", systemImage: "cube.fill")
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - URL Handling

    private func handleURL(_ url: URL) {
        guard url.scheme == "focusblox" else { return }

        if url.host == "add" {
            // Optional: Extract title from query parameter
            // focusblox://add?title=My%20Task
            quickCapture.showPanel()
        }
    }

    // MARK: - Spotlight Activity Handling

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        if identifier == "com.focusblox.quickcapture" {
            quickCapture.showPanel()
        }
    }
}

// MARK: - Main Window View

struct MainWindowView: View {
    @Binding var showShortcuts: Bool
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Label("Backlog", systemImage: "tray.full")
                }
                .tag(0)

            MacPlanningView()
                .tabItem {
                    Label("Planen", systemImage: "calendar")
                }
                .tag(1)

            MacReviewView()
                .tabItem {
                    Label("Review", systemImage: "chart.bar")
                }
                .tag(2)
        }
        .sheet(isPresented: $showShortcuts) {
            KeyboardShortcutsView()
        }
    }
}

// MARK: - Mac Model Container

/// ModelContainer for macOS that uses shared App Group with iOS app.
enum MacModelContainer {
    private static let appGroupID = "group.com.henning.focusblox"

    static func create() throws -> ModelContainer {
        let schema = Schema([LocalTask.self])

        // Check if App Group is available
        let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )

        let config: ModelConfiguration
        if appGroupURL != nil {
            // Production: Use App Group for shared data with iOS
            config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .automatic
            )
        } else {
            // Fallback for development without code signing
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(for: schema, configurations: [config])
    }
}
