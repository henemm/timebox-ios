---
entity_id: MAC-012
type: feature
created: 2026-01-31
status: done
workflow: macos-keyboard-shortcuts
---

# MAC-012: Keyboard Shortcuts

- [ ] Approved for implementation

## Purpose

Komplette Keyboard-Navigation für die macOS App, damit Power-User alles ohne Maus bedienen können. Shortcuts werden im Menü dokumentiert und eine Übersicht ist per ⌘? erreichbar.

## Scope

**Files:**
- `FocusBloxMac/FocusBloxMacApp.swift` (MODIFY)
- `FocusBloxMac/ContentView.swift` (MODIFY)
- `FocusBloxMac/KeyboardShortcutsView.swift` (CREATE)

**Estimated:** +80 / -5 LoC

## Implementation Details

### 1. Selection State (ContentView)

```swift
@State private var selectedTask: LocalTask.ID?

List(selection: $selectedTask) {
    ForEach(tasks, id: \.uuid) { task in
        TaskRow(task: task)
            .tag(task.uuid)
    }
}
```

### 2. Commands Menu (FocusBloxMacApp)

```swift
.commands {
    // File Menu
    CommandGroup(after: .newItem) {
        Button("New Task") { focusNewTaskField() }
            .keyboardShortcut("n", modifiers: .command)
    }

    // Edit Menu - Task Actions
    CommandGroup(after: .pasteboard) {
        Divider()
        Button("Complete Task") { completeSelectedTask() }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(selectedTask == nil)
        Button("Edit Task") { editSelectedTask() }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(selectedTask == nil)
        Button("Delete Task") { deleteSelectedTask() }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(selectedTask == nil)
    }

    // Help Menu
    CommandGroup(replacing: .help) {
        Button("Keyboard Shortcuts") { showShortcuts() }
            .keyboardShortcut("/", modifiers: [.command, .shift])
    }
}
```

### 3. Shortcuts-Übersicht (KeyboardShortcutsView)

Einfaches Sheet mit Liste aller verfügbaren Shortcuts:

| Shortcut | Aktion |
|----------|--------|
| ⌘N | Neue Aufgabe |
| ⌘D | Erledigt markieren |
| ⌘E | Bearbeiten |
| ⌘⌫ | Löschen |
| ⌘⇧/ | Diese Übersicht |
| ⌘⇧Space | Quick Capture |
| ↑/↓ | Navigation |

## Test Plan

### Automated Tests (TDD RED)

Da macOS UI Tests komplex sind und wir kein Test-Target haben, verwenden wir Build-Verifikation:

- [ ] Test 1: Build FocusBloxMac Target kompiliert ohne Fehler
- [ ] Test 2: iOS Build hat keine Regression

### Manual Verification (nach Implementation)

- [ ] ⌘N fokussiert das "New Task" Textfeld
- [ ] ⌘D markiert ausgewählte Aufgabe als erledigt
- [ ] ⌘E öffnet Edit-Ansicht für ausgewählte Aufgabe
- [ ] ⌘⌫ löscht ausgewählte Aufgabe
- [ ] ⌘⇧/ zeigt Shortcuts-Übersicht
- [ ] ↑/↓ navigiert durch Task-Liste
- [ ] Shortcuts erscheinen im Menü

## Acceptance Criteria

- [ ] Alle Shortcuts aus der Tabelle funktionieren
- [ ] Shortcuts sind im App-Menü sichtbar
- [ ] ⌘⇧/ zeigt Übersicht aller Shortcuts
- [ ] Keine Konflikte mit System-Shortcuts
- [ ] macOS und iOS Builds erfolgreich

## Dependencies

- MAC-001: App Foundation ✅
- MAC-010: Menu Bar Widget ✅

## Out of Scope

- Timer-Shortcuts (Space) - Timer existiert noch nicht
- Sidebar-Navigation (⌘1-5) - keine Sidebar-Tabs vorhanden
