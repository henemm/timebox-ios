# Bug 48: Erweiterte Attribute werden wiederholt geloescht

## Analysis

### Type
Bug (wiederkehrend, KRITISCH - Datenverlust)

### Root Causes (3 Stueck, verifiziert)

#### RC1: SyncEngine.updateTask() - "Alles-oder-nichts" Update
**Datei:** `Sources/Services/SyncEngine.swift:67-83`
- `updateTask()` ueberschreibt IMMER alle Felder, auch optionale
- Kein Unterschied zwischen "nil = nicht aendern" und "nil = loeschen"
- Wenn Caller `nil` uebergibt → existierender Wert wird geloescht
- Zusaetzlich: `recurrencePattern ?? "none"` loescht Wiederholungen bei Quick Edits

#### RC2: TaskFormSheet - Priority nil wird zu .medium
**Datei:** `Sources/Views/TaskFormSheet.swift:358`
- `let taskPriority: TaskPriority = priority.flatMap { ... } ?? .medium`
- Im EDIT-Modus: Wenn User Importance nicht aendert (nil) → wird .medium gesetzt
- onSave-Signatur erwartet `TaskPriority` (non-optional) statt `TaskPriority?`
- NUR importance betroffen (urgency/duration bleiben korrekt nil)

#### RC3: macOS Quick Capture - Direktes SwiftData ohne Service
**Dateien:** `FocusBloxMac/QuickCapturePanel.swift:175`, `FocusBloxMac/MenuBarView.swift:182`, `FocusBloxMac/ContentView.swift:486`
- 3x `LocalTask(title:)` ohne erweiterte Attribute
- Nutzen NICHT `LocalTaskSource.createTask()` aus Shared Services
- Tasks entstehen mit leeren Attributen → CloudKit-Sync kann iOS-Werte ueberschreiben

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Services/SyncEngine.swift | MODIFY | updateTask() nur geaenderte Felder setzen |
| Sources/Views/TaskFormSheet.swift | MODIFY | onSave Signatur auf TaskPriority? aendern |
| Sources/Views/BacklogView.swift | MODIFY | Callsites an neue Signatur anpassen |
| FocusBloxMac/QuickCapturePanel.swift | MODIFY | LocalTaskSource.createTask() nutzen |
| FocusBloxMac/MenuBarView.swift | MODIFY | LocalTaskSource.createTask() nutzen |
| FocusBloxMac/ContentView.swift | MODIFY | LocalTaskSource.createTask() nutzen |

### Scope Assessment
- Files: 6
- Estimated LoC: ~+80/-40
- Risk Level: MEDIUM (Aenderung am zentralen Update-Pfad)

### Technical Approach (Empfehlung)

**Fix fuer RC1 (SyncEngine):**
Die einfachste und sicherste Loesung: In `updateTask()` optionale Felder NUR setzen wenn der uebergebene Wert nicht nil ist. Bestehende Werte bleiben erhalten.

```swift
// Vorher (FALSCH):
task.importance = importance        // loescht bei nil

// Nachher (KORREKT):
if let importance { task.importance = importance }  // nil = nicht aendern
```

Fuer `recurrencePattern`: Default-Wert `"none"` entfernen, stattdessen preserve:
```swift
if let recurrencePattern { task.recurrencePattern = recurrencePattern }
```

**Fix fuer RC2 (TaskFormSheet):**
- `onSave` Signatur: `TaskPriority` → `TaskPriority?` (oder besser: `Int?`)
- Zeile 358 entfernen, direkt `priority` (Int?) uebergeben
- Alle Callsites anpassen

**Fix fuer RC3 (macOS Quick Capture):**
- Alle 3 Stellen auf `LocalTaskSource.createTask()` umstellen
- Quick Capture ist absichtlich minimal (nur Titel) - das ist OK
- Aber der Service stellt sicher, dass Defaults korrekt gesetzt werden

### Dependencies
- `LocalTaskSource` muss `createTask()` ohne ModelContext-Parameter anbieten (oder macOS muss eigenen Context uebergeben)
- Alle BacklogView-Callsites muessen geprueft werden nach Signatur-Aenderung
- TaskDetailSheet/EditTaskSheet nutzen onSave-Callback → muessen ebenfalls angepasst werden

### Open Questions
- Keine - Root Causes sind eindeutig identifiziert
