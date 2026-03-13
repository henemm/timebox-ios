# Bug: Feedback-Overlay nach Reminders-Import unsichtbar auf macOS

## Root Cause (5 Agenten, parallel)

macOS `ContentView.swift` hat `@State private var importStatusMessage: String?` (Zeile 56)
und setzt den Wert mit `withAnimation` (Zeilen 606, 620, 623, 630) — aber es gibt
**keinen `.overlay()` Modifier** der den Text rendert.

iOS `BacklogView.swift` hat einen Overlay (Zeilen 274-284). macOS fehlt er komplett.

## Fix

`.overlay(alignment: .bottom)` mit opacity-basiertem Pattern nach dem letzten
`.confirmationDialog` in `backlogView` einfuegen.
