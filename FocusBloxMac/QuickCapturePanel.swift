//
//  QuickCapturePanel.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData
import Carbon.HIToolbox
import Observation

/// Global Quick Capture floating panel (Spotlight-style)
@Observable
@MainActor
final class QuickCaptureController {
    static let shared = QuickCaptureController()

    var isVisible = false
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var modelContainer: ModelContainer?

    private init() {}

    func setup(with container: ModelContainer) {
        self.modelContainer = container
        setupGlobalHotkey()
    }

    // MARK: - Global Hotkey (⌘⇧Space)

    private func setupGlobalHotkey() {
        // Monitor for ⌘⇧Space globally
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for ⌘⇧Space
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 { // 49 = Space
                Task { @MainActor in
                    self?.togglePanel()
                }
            }
        }

        // Also monitor local events (when app is active)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 {
                Task { @MainActor in
                    self?.togglePanel()
                }
                return nil // Consume the event
            }
            return event
        }
    }

    func togglePanel() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let container = modelContainer else { return }

        if panel == nil {
            createPanel(with: container)
        }

        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        isVisible = true
    }

    func hidePanel() {
        panel?.orderOut(nil)
        isVisible = false
    }

    private func createPanel(with container: ModelContainer) {
        let contentView = QuickCaptureView(onDismiss: { [weak self] in
            self?.hidePanel()
        })
        .modelContainer(container)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 120)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel.frame
            let x = screenFrame.midX - panelFrame.width / 2
            let y = screenFrame.maxY - panelFrame.height - 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = panel
    }

    func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - Quick Capture View

struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var taskTitle = ""
    @State private var isNextUp = false
    @State private var importance: Int? = nil
    @State private var urgency: String? = nil
    @State private var taskType: String = "maintenance"
    @State private var estimatedDuration: Int? = nil
    @State private var showCategoryPicker = false
    @State private var showDurationPicker = false
    @FocusState private var isFocused: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(nsImage: MenuBarController.makeMenuBarIcon(from: NSApp.applicationIconImage!, size: NSSize(width: 24, height: 24)))
                    .resizable()
                    .frame(width: 24, height: 24)

                TextField("Add task...", text: $taskTitle)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit { addTask() }
                    .onExitCommand { resetAndDismiss() }

                Button(action: { isNextUp.toggle() }) {
                    Image(systemName: isNextUp ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .foregroundStyle(isNextUp ? .blue : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Next Up")
                .accessibilityIdentifier("qc_nextUpButton")

                if !taskTitle.isEmpty {
                    Button(action: addTask) {
                        Image(systemName: "return")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }

            if !taskTitle.isEmpty {
                metadataRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .animation(.spring(duration: 0.25), value: taskTitle.isEmpty)
        .onAppear { isFocused = true }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 8) {
            importanceButton
            urgencyButton
            categoryButton
            durationButton
            Spacer()
        }
    }

    private var importanceButton: some View {
        Button { cycleImportance() } label: {
            Image(systemName: ImportanceUI.icon(for: importance))
                .font(.system(size: 14))
                .foregroundStyle(ImportanceUI.color(for: importance))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(ImportanceUI.color(for: importance).opacity(0.15)))
        }
        .buttonStyle(.borderless)
        .help("Wichtigkeit: \(ImportanceUI.label(for: importance))")
        .accessibilityIdentifier("qc_importanceButton")
    }

    private func cycleImportance() {
        switch importance {
        case nil: importance = 1
        case 1: importance = 2
        case 2: importance = 3
        case 3: importance = nil
        default: importance = nil
        }
    }

    private var urgencyButton: some View {
        Button { cycleUrgency() } label: {
            Image(systemName: UrgencyUI.icon(for: urgency))
                .font(.system(size: 14))
                .foregroundStyle(UrgencyUI.color(for: urgency))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(UrgencyUI.color(for: urgency).opacity(0.15)))
        }
        .buttonStyle(.borderless)
        .help("Dringlichkeit: \(UrgencyUI.label(for: urgency))")
        .accessibilityIdentifier("qc_urgencyButton")
    }

    private func cycleUrgency() {
        switch urgency {
        case nil: urgency = "not_urgent"
        case "not_urgent": urgency = "urgent"
        case "urgent": urgency = nil
        default: urgency = nil
        }
    }

    private var categoryButton: some View {
        Button { showCategoryPicker.toggle() } label: {
            Image(systemName: TaskCategory(rawValue: taskType)?.icon ?? "folder")
                .font(.system(size: 14))
                .foregroundStyle(TaskCategory(rawValue: taskType)?.color ?? .gray)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill((TaskCategory(rawValue: taskType)?.color ?? .gray).opacity(0.15)))
        }
        .buttonStyle(.borderless)
        .help("Kategorie: \(TaskCategory(rawValue: taskType)?.displayName ?? "Kategorie")")
        .accessibilityIdentifier("qc_categoryButton")
        .popover(isPresented: $showCategoryPicker) {
            CategoryPicker(currentCategory: taskType) { selected in
                taskType = selected
                showCategoryPicker = false
            }
        }
    }

    private var durationButton: some View {
        Button { showDurationPicker.toggle() } label: {
            HStack(spacing: 2) {
                Image(systemName: estimatedDuration != nil ? "timer" : "questionmark")
                if let duration = estimatedDuration {
                    Text("\(duration)m").font(.caption)
                }
            }
            .font(.system(size: 14))
            .foregroundStyle(estimatedDuration != nil ? .blue : .gray)
            .frame(height: 32)
            .padding(.horizontal, estimatedDuration != nil ? 8 : 0)
            .frame(minWidth: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill((estimatedDuration != nil ? Color.blue : Color.gray).opacity(0.15)))
        }
        .buttonStyle(.borderless)
        .help(estimatedDuration != nil ? "Dauer: \(estimatedDuration!) Min" : "Dauer nicht gesetzt")
        .accessibilityIdentifier("qc_durationButton")
        .popover(isPresented: $showDurationPicker) {
            DurationPicker(currentDuration: estimatedDuration ?? 0) { selected in
                estimatedDuration = selected
                showDurationPicker = false
            }
        }
    }

    // MARK: - Actions

    private func addTask() {
        guard !taskTitle.isEmpty else { return }
        let title = taskTitle
        let shouldMarkNextUp = isNextUp
        let capturedImportance = importance
        let capturedUrgency = urgency
        let capturedTaskType = taskType
        let capturedDuration = estimatedDuration
        let capturedContext = modelContext

        resetState()
        onDismiss()

        Task {
            let taskSource = LocalTaskSource(modelContext: capturedContext)
            let task = try? await taskSource.createTask(
                title: title,
                importance: capturedImportance,
                estimatedDuration: capturedDuration,
                urgency: capturedUrgency,
                taskType: capturedTaskType,
                lifecycleStatus: TaskLifecycleStatus.raw.rawValue
            )
            if shouldMarkNextUp, let task {
                task.isNextUp = true
                task.nextUpSortOrder = Int.max
                try? capturedContext.save()
            }
        }
    }

    private func resetAndDismiss() {
        resetState()
        onDismiss()
    }

    private func resetState() {
        taskTitle = ""
        isNextUp = false
        importance = nil
        urgency = nil
        taskType = "maintenance"
        estimatedDuration = nil
        showCategoryPicker = false
        showDurationPicker = false
    }
}

#Preview {
    QuickCaptureView(onDismiss: {})
        .frame(width: 500)
        .padding()
}
