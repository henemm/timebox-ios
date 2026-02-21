# Context: Undo Task Completion

## Request Summary
Versehentliches Abhaken eines Tasks soll rueckgaengig gemacht werden koennen. iOS via Shake-Geste, macOS via Cmd+Z. Bei Recurring Tasks wird der Originalzustand komplett wiederhergestellt (Task uncomplete + neue Instanz loeschen).

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Services/SyncEngine.swift` | `completeTask()` (L142-162) + `uncompleteTask()` (L177-184) — Kern-Logik |
| `Sources/Services/FocusBlockActionService.swift` | `completeTask()` (L20-62) — Completion waehrend Focus-Block |
| `Sources/Services/RecurrenceService.swift` | `createNextInstance()` (L76-141) — Erstellt neue Recurring-Instanz |
| `Sources/Models/LocalTask.swift` | isCompleted, completedAt, isNextUp, assignedFocusBlockID |
| `Sources/Views/BacklogView.swift` | iOS completeTask (L613), uncompleteTask (L1023), CompletedTaskRow (L1041) |
| `FocusBloxMac/ContentView.swift` | macOS Completion (L781-789, L880-886), TaskActions struct (L28-34) |
| `FocusBloxMac/FocusBloxMacApp.swift` | Keyboard Shortcuts (L159-200), Cmd+D = Complete |
| `FocusBloxMac/MenuBarView.swift` | toggleComplete (L407-417) |
| `FocusBloxMac/TaskInspector.swift` | Direkte Completion (L172-186) |
| `Sources/Intents/CompleteTaskIntent.swift` | Siri Completion (L14-44) |

## Completion-Pfade (alle 4 Stellen)

### 1. SyncEngine.completeTask() — Hauptpfad
```swift
task.isCompleted = true
task.completedAt = Date()
task.assignedFocusBlockID = nil    // WIRD GELOESCHT
task.isNextUp = false               // WIRD GELOESCHT
RecurrenceService.createNextInstance(from: task, in: modelContext)  // NEUE INSTANZ
```

### 2. FocusBlockActionService.completeTask() — Waehrend Focus-Session
- Identisch + Updates FocusBlock.completedTaskIDs + taskTimes

### 3. CompleteTaskIntent — Siri/Shortcuts
- Identisch zu SyncEngine

### 4. TaskInspector (macOS) — Direkte Toggle
- Identisch, aber via `.toggle()` statt separater Methode

## Bestehende uncompleteTask() — UNVOLLSTAENDIG
```swift
func uncompleteTask(itemID: String) throws {
    task.isCompleted = false
    task.completedAt = nil
    // FEHLT: isNextUp restore
    // FEHLT: assignedFocusBlockID restore
    // FEHLT: Recurring-Instanz loeschen
}
```

## Existing Patterns

### Service-Pattern: Enum mit Static Methods (meistverwendet)
RecurrenceService, FocusBlockActionService, NotificationService, SoundService — alle `enum` mit `static func`.

### macOS Keyboard Shortcuts: CommandGroup + FocusedValue
```swift
// FocusBloxMacApp.swift
.commands {
    CommandGroup(after: .pasteboard) {
        Button("Complete Task") { taskActions?.completeSelected() }
            .keyboardShortcut("d", modifiers: .command)
    }
}

// ContentView.swift
struct TaskActions {
    let completeSelected: () -> Void
    let hasSelection: Bool
}
```
Cmd+Z passt perfekt als neuer Button in die bestehende CommandGroup.

### iOS CompletedTaskRow — Manuelles Undo
BacklogView hat bereits einen "Wiederherstellen"-Button (Swipe-Action) der `uncompleteTask()` aufruft. Aber: nur in der Erledigt-View sichtbar, nicht global.

## Dependencies
- **Upstream:** SyncEngine, RecurrenceService, FocusBlockActionService, LocalTask Model
- **Downstream:** BacklogView (iOS), ContentView (macOS), FocusBloxMacApp (Shortcuts)

## Existing Specs
- Keine dedizierte Spec fuer Undo vorhanden
- RecurrenceService-Logik dokumentiert in ACTIVE-todos.md

## Risks & Considerations

1. **Recurring-Instanz loeschen:** `createNextInstance()` returned `LocalTask?` — wir koennen die ID speichern. Aber: Dedup-Logik koennte `nil` returnen wenn schon ein Sibling existiert. Dann gibt es nichts zu loeschen.

2. **FocusBlock-Completion:** Waehrend einer aktiven Session wird auch `FocusBlock.completedTaskIDs` aktualisiert. Undo muesste das rueckgaengig machen — aber EventKit-Updates sind schwer reversibel. **Scope-Entscheidung:** Undo waehrend aktiver Focus-Session NICHT unterstuetzen (zu komplex, Edge-Case).

3. **Siri/Shortcuts:** CompleteTaskIntent laeuft in separatem Prozess mit eigenem ModelContext. Undo hier ist nicht sinnvoll (User hat bewusst "Erledige Task X" gesagt).

4. **Nur EINE Completion undo-bar:** Kein Stack, nur die letzte. Passt zum Anwendungsfall "Ups, falschen Task abgehakt".

5. **In-Memory vs Persistent:** Snapshot nur im RAM — nach App-Neustart ist Undo weg. Reicht fuer "Ups"-Szenario.

6. **Plattform-Divergenz pruefen:** iOS und macOS haben unterschiedliche Completion-Pfade in der UI, aber gleiche Service-Schicht.
