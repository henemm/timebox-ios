---
entity_id: undo-task-completion
type: feature
created: 2026-02-21
updated: 2026-02-21
status: draft
version: "1.0"
tags: [undo, completion, shake, cmd-z, cross-platform]
---

# Undo Task Completion

## Approval

- [ ] Approved

## Purpose

Ermoeglicht das Rueckgaengigmachen eines versehentlichen Task-Abhakens. iOS nutzt die Shake-Geste, macOS nutzt Cmd+Z. Der vollstaendige Vor-Completion-Zustand wird wiederhergestellt, einschliesslich der Loeschung einer ggf. erzeugten Recurring-Instanz.

## Source

- **File:** `Sources/Services/TaskCompletionUndoService.swift` (NEU)
- **Identifier:** `enum TaskCompletionUndoService`

## Anforderungen

### Funktional

1. **Snapshot vor Completion:** Vor jedem Abhaken wird der Task-Zustand gespeichert (isNextUp, assignedFocusBlockID)
2. **Undo stellt Originalzustand her:** isCompleted=false, completedAt=nil, isNextUp/assignedFocusBlockID aus Snapshot
3. **Recurring Tasks:** Undo loescht die durch Completion erzeugte neue Instanz (falls vorhanden)
4. **Nur letzte Completion:** Kein Stack, nur die letzte Aktion ist undo-bar
5. **In-Memory:** Snapshot geht bei App-Neustart verloren
6. **Kein Zeitlimit:** Undo bleibt verfuegbar bis zur naechsten Completion

### Nicht-Funktional

1. **iOS Trigger:** Device-Shake-Geste
2. **macOS Trigger:** Cmd+Z Keyboard Shortcut
3. **UI Feedback:** Haptisches Feedback (iOS) + kurze Bestaetigung

### Scope-Ausschluesse

- Kein Undo waehrend aktiver Focus-Session (EventKit-Reversal zu komplex)
- Kein Undo fuer Siri/Shortcuts Intent (bewusste Aktion, separater Prozess)
- Kein Undo-Stack (nur letzte Completion)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SyncEngine | Service | Integration: Snapshot-Capture in completeTask() |
| RecurrenceService | Service | createNextInstance() liefert ID der neuen Instanz |
| LocalTask | Model | Task-Felder die gespeichert/wiederhergestellt werden |
| BacklogView | View (iOS) | Shake-Geste Modifier |
| ContentView | View (macOS) | TaskActions um undoLastCompletion erweitern |
| FocusBloxMacApp | App (macOS) | Cmd+Z Keyboard Shortcut |

## Implementation Details

### 1. TaskCompletionUndoService (enum, static methods)

```swift
enum TaskCompletionUndoService {
    struct Snapshot {
        let taskID: String
        let wasNextUp: Bool
        let assignedFocusBlockID: String?
        let createdRecurringInstanceID: String?
    }

    private(set) static var lastSnapshot: Snapshot?

    static func capture(
        taskID: String,
        wasNextUp: Bool,
        assignedFocusBlockID: String?
    )

    static func recordCreatedInstance(id: String?)

    @MainActor
    static func undo(in modelContext: ModelContext) throws -> String?
    // Returns task title on success, nil if nothing to undo

    static var canUndo: Bool
    static func clear()
}
```

### 2. SyncEngine.completeTask() Integration

```swift
func completeTask(itemID: String) throws {
    guard let task = try findTask(byID: itemID) else { return }
    if task.isTemplate { return }

    // NEU: Snapshot VOR Completion
    TaskCompletionUndoService.capture(
        taskID: task.id,
        wasNextUp: task.isNextUp,
        assignedFocusBlockID: task.assignedFocusBlockID
    )

    task.isCompleted = true
    task.completedAt = Date()
    task.assignedFocusBlockID = nil
    task.isNextUp = false

    if task.recurrencePattern != "none" {
        let newInstance = RecurrenceService.createNextInstance(from: task, in: modelContext)
        // NEU: Instance-ID merken
        TaskCompletionUndoService.recordCreatedInstance(id: newInstance?.id)
    } else {
        TaskCompletionUndoService.recordCreatedInstance(id: nil)
    }

    try modelContext.save()
}
```

### 3. TaskCompletionUndoService.undo() Logik

```swift
@MainActor
static func undo(in modelContext: ModelContext) throws -> String? {
    guard let snapshot = lastSnapshot else { return nil }

    // 1. Task finden
    let descriptor = FetchDescriptor<LocalTask>(
        predicate: #Predicate { $0.id == snapshot.taskID }
    )
    guard let task = try modelContext.fetch(descriptor).first else {
        clear()
        return nil
    }

    // 2. Task-Zustand wiederherstellen
    task.isCompleted = false
    task.completedAt = nil
    task.isNextUp = snapshot.wasNextUp
    task.assignedFocusBlockID = snapshot.assignedFocusBlockID

    // 3. Recurring-Instanz loeschen (falls vorhanden)
    if let instanceID = snapshot.createdRecurringInstanceID {
        let instanceDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.id == instanceID }
        )
        if let instance = try modelContext.fetch(instanceDescriptor).first {
            modelContext.delete(instance)
        }
    }

    try modelContext.save()
    let title = task.title
    clear()
    return title
}
```

### 4. iOS Shake-Geste

```swift
// Ansatz: NotificationCenter-basiert via UIWindow override
extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

// ViewModifier
struct ShakeDetector: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            action()
        }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeDetector(action: action))
    }
}
```

In BacklogView:
```swift
.onShake {
    undoLastCompletion()
}
```

### 5. macOS Cmd+Z

In FocusBloxMacApp.swift:
```swift
CommandGroup(after: .pasteboard) {
    // ... bestehende Buttons ...

    Button("Undo Completion") {
        taskActions?.undoLastCompletion()
    }
    .keyboardShortcut("z", modifiers: .command)
    .disabled(!TaskCompletionUndoService.canUndo)
}
```

TaskActions erweitern:
```swift
struct TaskActions {
    let focusNewTask: () -> Void
    let completeSelected: () -> Void
    let editSelected: () -> Void
    let deleteSelected: () -> Void
    let undoLastCompletion: () -> Void  // NEU
    let hasSelection: Bool
}
```

### 6. UI Feedback (beide Plattformen)

```swift
private func undoLastCompletion() {
    do {
        if let title = try TaskCompletionUndoService.undo(in: modelContext) {
            undoMessage = "'\(title)' wiederhergestellt"
            showUndoConfirmation = true
            // iOS: Haptik
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }
    } catch {
        // Silent fail - Undo ist best-effort
    }
}
```

## Expected Behavior

- **Input:** User schuettelt iPhone / drueckt Cmd+Z auf Mac
- **Output:** Letzter abgehakter Task erscheint wieder im Backlog mit Originalzustand
- **Side effects:**
  - Bei Recurring: Neue Instanz wird geloescht
  - Snapshot wird geleert (kein zweites Undo moeglich)
  - Haptisches Feedback auf iOS

## Edge Cases

| Case | Verhalten |
|------|-----------|
| Kein Snapshot vorhanden | Shake/Cmd+Z tut nichts (silent) |
| Task wurde zwischenzeitlich geloescht | Snapshot geleert, nichts passiert |
| Recurring-Instanz wurde schon bearbeitet | Instanz wird trotzdem geloescht (User hat bewusst Undo ausgeloest) |
| App-Neustart | Snapshot verloren, kein Undo moeglich |
| Zweites Shake/Cmd+Z | Kein Effekt (Snapshot bereits geleert) |
| RecurrenceService Dedup: nil returned | recordCreatedInstance(nil) — Undo loescht keine Instanz |

## Affected Files

| File | Change | LoC |
|------|--------|-----|
| `Sources/Services/TaskCompletionUndoService.swift` | CREATE | +80 |
| `Sources/Services/SyncEngine.swift` | MODIFY | +8 |
| `Sources/Views/BacklogView.swift` | MODIFY | +25 |
| `FocusBloxMac/ContentView.swift` | MODIFY | +10 |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | +8 |

**Total:** 5 Dateien, ~131 LoC netto

## Test Plan

### Unit Tests (TaskCompletionUndoServiceTests.swift)

1. `test_capture_storesSnapshot` — Snapshot wird korrekt gespeichert
2. `test_undo_restoresTaskState` — isCompleted, completedAt, isNextUp, assignedFocusBlockID
3. `test_undo_deletesRecurringInstance` — Neue Instanz wird geloescht
4. `test_undo_withoutRecurringInstance` — Undo ohne Recurring funktioniert
5. `test_undo_clearsSnapshot` — Nach Undo ist canUndo == false
6. `test_undo_withNoSnapshot_returnsNil` — Kein Snapshot = kein Effekt
7. `test_newCompletion_replacesOldSnapshot` — Nur letzte Completion gespeichert
8. `test_undo_taskDeleted_returnsNil` — Geloeschter Task = graceful nil

### UI Tests (UndoCompletionUITests.swift)

1. `test_undoButton_existsAfterCompletion` (macOS: Cmd+Z Menu-Item enabled)
2. `test_undoRestoresTaskInBacklog` — Task erscheint wieder nach Undo

## Known Limitations

- Nur letzte Completion ist undo-bar (kein Stack)
- In-Memory (verloren bei App-Neustart)
- Kein Undo waehrend aktiver Focus-Session
- Kein Undo fuer Siri/Shortcuts
- CloudKit-Sync koennte auf anderem Geraet kurzzeitig inkonsistenten Zustand zeigen

## Changelog

- 2026-02-21: Initial spec created
