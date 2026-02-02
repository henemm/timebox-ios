//
//  KeyboardShortcutsView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI

/// Keyboard shortcuts overview (⌘⇧/)
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "keyboard")
                    .font(.title)
                Text("Keyboard Shortcuts")
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Divider()

            // Shortcuts Grid
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                // Task Actions
                shortcutSection("Tasks")

                shortcutRow("⌘N", "New Task")
                shortcutRow("⌘D", "Complete Task")
                shortcutRow("⌘E", "Edit Task")
                shortcutRow("⌘⌫", "Delete Task")

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                // Navigation
                shortcutSection("Navigation")

                shortcutRow("↑ / ↓", "Navigate List")
                shortcutRow("Enter", "Open Task")

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                // Quick Actions
                shortcutSection("Quick Actions")

                shortcutRow("⌘⇧Space", "Quick Capture")
                shortcutRow("⌘⇧/", "This Overview")
            }

            Spacer()

            // Footer
            Text("Tip: Shortcuts are also shown in the menu bar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 350, height: 400)
    }

    private func shortcutSection(_ title: String) -> some View {
        GridRow {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("")
        }
    }

    private func shortcutRow(_ shortcut: String, _ description: String) -> some View {
        GridRow {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(description)
        }
    }
}

#Preview {
    KeyboardShortcutsView()
}
