# Analyse: Recurring Task verschwindet nach Completion (macOS)

## Agenten-Ergebnisse (5/5 fertig)

Alle 5 Agenten zeigen dasselbe Bild: **macOS hat eigene Completion-Handler die RecurrenceService NICHT aufrufen.**

## Root Cause (BESTÄTIGT durch 4 von 5 Agenten)

macOS `ContentView.swift` hat **zwei** Completion-Pfade die direkt `isCompleted` setzen ohne RecurrenceService aufzurufen:

### 1. Checkbox-Tap (Zeile 849-851)
```swift
onToggleComplete: {
    task.isCompleted.toggle()      // Direkt toggle
    try? modelContext.save()       // Direkt save — KEIN RecurrenceService
}
```

### 2. Context Menu (Zeilen 751-761)
```swift
func markTasksCompleted(_ ids: Set<UUID>) {
    for id in ids {
        if let task = tasks.first(where: { $0.uuid == id }) {
            task.isCompleted = true
            // ... KEIN RecurrenceService.createNextInstance()
        }
    }
}
```

### Zusätzlich: MenuBarView (Zeilen 407-416)
```swift
func toggleComplete(_ task: LocalTask) {
    task.isCompleted.toggle()
    // ... KEIN RecurrenceService
}
```

## Vergleich iOS vs macOS

| Pfad | iOS | macOS | RecurrenceService |
|------|-----|-------|-------------------|
| Backlog Checkbox | SyncEngine.completeTask() | task.isCompleted.toggle() | iOS: JA, macOS: NEIN |
| Context Menu | SyncEngine.completeTask() | markTasksCompleted() | iOS: JA, macOS: NEIN |
| Focus Block | FocusBlockActionService | FocusBlockActionService | BEIDE: JA |
| TaskInspector | — | SyncEngine + RecurrenceService | macOS: JA |
| Siri/Shortcuts | CompleteTaskIntent | — | NEIN |

## Hypothesen

### H1: RecurrenceService wird nicht aufgerufen (HOCH — bestätigt)
- **Beweis dafür:** Code in ContentView.swift:849-851 hat keinen RecurrenceService-Aufruf
- **Beweis dagegen:** Keiner — alle 5 Agenten bestätigen

### H2: Neue Instanz wird erstellt aber mit falschem Pattern (NIEDRIG — ausgeschlossen)
- Es wird gar keine Instanz erstellt, also irrelevant

### H3: View refresht nicht nach Completion (NIEDRIG — ausgeschlossen)
- @Query auf macOS refresht korrekt — das Problem ist nicht der Refresh sondern die fehlende neue Instanz

## Blast Radius

- **macOS Backlog Checkbox:** BETROFFEN
- **macOS Context Menu:** BETROFFEN
- **macOS MenuBar:** BETROFFEN
- **iOS Siri/Shortcuts (CompleteTaskIntent):** BETROFFEN
- **iOS Backlog:** NICHT betroffen (nutzt SyncEngine)
- **Focus Block (beide):** NICHT betroffen (nutzt FocusBlockActionService)

## Fix-Vorschlag

Alle 4 betroffenen Stellen sollen `SyncEngine.completeTask()` nutzen statt direkte Property-Manipulation:

1. `ContentView.swift:849-851` — onToggleComplete → SyncEngine
2. `ContentView.swift:751-761` — markTasksCompleted → SyncEngine
3. `MenuBarView.swift:407-416` — toggleComplete → SyncEngine (oder RecurrenceService direkt)
4. `CompleteTaskIntent.swift:29-33` — perform → RecurrenceService hinzufügen
