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
        hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 60)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 60),
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
    @FocusState private var isFocused: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            TextField("Add task...", text: $taskTitle)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isFocused)
                .onSubmit {
                    addTask()
                }
                .onExitCommand {
                    onDismiss()
                }

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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .onAppear {
            isFocused = true
        }
    }

    private func addTask() {
        guard !taskTitle.isEmpty else { return }
        let title = taskTitle
        let shouldMarkNextUp = isNextUp
        taskTitle = ""
        isNextUp = false
        onDismiss()

        Task {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let task = try? await taskSource.createTask(title: title, taskType: "")
            if shouldMarkNextUp, let task {
                task.isNextUp = true
                task.nextUpSortOrder = Int.max
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    QuickCaptureView(onDismiss: {})
        .frame(width: 500)
        .padding()
}
