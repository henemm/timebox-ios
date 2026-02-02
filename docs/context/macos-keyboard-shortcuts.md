# Context: macOS Keyboard Shortcuts (MAC-012)

## Request Summary
Komplette Keyboard-Navigation für die macOS App - alle Aktionen per Tastatur erreichbar, Focus-Indicator sichtbar, Shortcuts im Menü dokumentiert.

## Related Files

| File | Relevance |
|------|-----------|
| `FocusBloxMac/FocusBloxMacApp.swift` | App Entry Point, bereits `.commands` Block vorhanden |
| `FocusBloxMac/ContentView.swift` | Hauptfenster, Task-Liste - braucht Keyboard-Navigation |
| `FocusBloxMac/MenuBarView.swift` | Menu Bar Popover - optional Shortcuts |
| `FocusBloxMac/QuickCapturePanel.swift` | Bereits ⌘⇧Space implementiert |
| `docs/specs/macos/BACKLOG.md` | Spec-Definition für MAC-012 |

## Existing Patterns

### Bereits implementiert
- `⌘⇧Space` - Global Quick Capture (via NSEvent.addGlobalMonitorForEvents)
- `.commands { CommandGroup }` - Standard SwiftUI Command Menu

### SwiftUI Keyboard-Patterns
```swift
// Keyboard Shortcut auf Button
Button("Action") { ... }
    .keyboardShortcut("n", modifiers: .command)

// Focus State für Navigation
@FocusState private var focusedTask: UUID?

// List Selection
@State private var selection: UUID?
List(selection: $selection) { ... }
```

## Geplante Shortcuts (aus BACKLOG.md)

| Shortcut | Aktion |
|----------|--------|
| ⌘N | Neue Aufgabe |
| ⌘D | Aufgabe erledigen |
| ⌘E | Aufgabe bearbeiten |
| Space | Timer starten/pausieren |
| ⌘1-5 | Sidebar-Navigation |
| ⌘? | Shortcuts-Übersicht |

## Dependencies

### Upstream
- SwiftUI `.commands` API
- `@FocusState` für Navigation
- `List(selection:)` für Selektion

### Downstream
- ContentView braucht Selection State
- TaskRow braucht Focus-Indicator

## Risks & Considerations

1. **Konflikt mit System-Shortcuts**
   - ⌘Space ist Spotlight - wir nutzen ⌘⇧Space
   - ⌘D könnte mit "Add to Dock" kollidieren

2. **Focus-Indicator Sichtbarkeit**
   - macOS hat subtile Focus-Rings
   - Eventuell eigenen visuellen Indicator bauen

3. **List Selection vs Focus**
   - SwiftUI List hat eingebaute Selection
   - Muss mit Keyboard-Actions verbunden werden

## Affected Files (Estimated)

```
FocusBloxMac/
├── FocusBloxMacApp.swift    (Commands erweitern)
├── ContentView.swift        (Selection, Focus, Actions)
└── KeyboardShortcutsView.swift (NEU: ⌘? Übersicht)
```

## Open Questions

1. Soll ⌘D "Delete" oder "Done" sein? → **Done** (Erledigt markieren)
2. Sidebar-Navigation - haben wir überhaupt 5 Tabs? → Erstmal weglassen
3. Timer starten - haben wir schon Timer-Logik? → Nein, später (MAC-020+)

---

## Analysis

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | Commands Menu erweitern |
| `FocusBloxMac/ContentView.swift` | MODIFY | Selection State, Keyboard Actions |
| `FocusBloxMac/KeyboardShortcutsView.swift` | CREATE | ⌘? Shortcuts-Übersicht |

### Scope Assessment

- **Files:** 3 (2 modify, 1 create)
- **Estimated LoC:** +80 / -5
- **Risk Level:** LOW

### Technical Approach

1. **Selection State in ContentView**
   - `@State private var selectedTask: LocalTask.ID?`
   - `List(selection: $selectedTask)` für native Keyboard-Navigation

2. **Commands Menu in FocusBloxMacApp**
   ```swift
   .commands {
       CommandGroup(after: .newItem) {
           Button("New Task") { ... }.keyboardShortcut("n")
       }
       CommandGroup(replacing: .pasteboard) {
           Button("Complete Task") { ... }.keyboardShortcut("d")
           Button("Edit Task") { ... }.keyboardShortcut("e")
       }
       CommandGroup(replacing: .help) {
           Button("Keyboard Shortcuts") { ... }.keyboardShortcut("?", modifiers: .command)
       }
   }
   ```

3. **Shortcuts-Übersicht (KeyboardShortcutsView)**
   - Einfache Liste aller Shortcuts
   - Als Sheet präsentiert bei ⌘?

### Implementierte Shortcuts

| Shortcut | Aktion | Implementierung |
|----------|--------|-----------------|
| ⌘N | Neue Aufgabe erstellen | Focus auf TextField |
| ⌘D | Ausgewählte Aufgabe erledigen | Toggle isCompleted |
| ⌘E | Ausgewählte Aufgabe bearbeiten | Edit Sheet öffnen |
| ⌘⌫ | Ausgewählte Aufgabe löschen | Delete mit Confirmation |
| ⌘? | Shortcuts-Übersicht | Sheet anzeigen |
| ↑/↓ | Navigation in Liste | Native List behavior |
| Enter | Aufgabe auswählen/öffnen | Detail anzeigen |

### Nicht implementiert (später)

| Shortcut | Grund |
|----------|-------|
| Space (Timer) | Timer-Logik existiert noch nicht |
| ⌘1-5 (Sidebar) | Keine Sidebar-Tabs vorhanden |

### Data Flow

```
User drückt ⌘D
    ↓
CommandGroup empfängt Event
    ↓
Action liest selectedTask
    ↓
modelContext.fetch(selectedTask)
    ↓
task.isCompleted.toggle()
```
