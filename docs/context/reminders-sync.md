# Context: Reminders Sync (Optionale Apple Erinnerungen Integration)

## Request Summary

Bidirektionale Synchronisation mit Apple Erinnerungen. Felder, die Apple Reminders nicht unterstützt (Tags, Urgency, TaskType, etc.), werden lokal in der bestehenden Datenstruktur gehalten. Die Reminders-ID wird für bidirektionale Sync-Verknüpfung gespeichert.

## Aktueller Stand

### Apple Reminders Integration (READ-ONLY)

Die App hat bereits eine **Read-Only** Integration mit Apple Reminders:

| Datei | Zweck |
|-------|-------|
| `Sources/Models/ReminderData.swift` | Wrapper für EKReminder (nur 4 Felder: id, title, isCompleted, priority) |
| `Sources/Services/EventKitRepository.swift` | EventKit-Zugriff mit fetch/complete Methoden |
| `Sources/Models/TaskMetadata.swift` | Speichert sortOrder + manualDuration für Reminders |

**Limitationen von ReminderData:**
- Nur `id`, `title`, `isCompleted`, `priority`
- Keine Tags, DueDate, Notes, Urgency, TaskType

### LocalTask (Full-Featured)

`Sources/Models/LocalTask.swift` ist das vollständige SwiftData-Modell:

```swift
@Model
final class LocalTask {
    var uuid: UUID
    var title: String
    var isCompleted: Bool
    var priority: Int
    var tags: [String]          // ← Apple Reminders hat das nicht
    var dueDate: Date?
    var urgency: String         // ← Apple Reminders hat das nicht
    var taskType: String        // ← Apple Reminders hat das nicht
    var recurrencePattern: String
    var taskDescription: String?
    var isNextUp: Bool

    // Bereits vorhanden für Sync!
    var externalID: String?     // ← Für Reminders-ID nutzbar
    var sourceSystem: String    // "local" / "notion" / "todoist" / "reminders"
}
```

### TaskSource Protocol Pattern

Das Projekt nutzt bereits ein Protocol-basiertes Pattern für Task-Quellen:

| Protocol | Methoden |
|----------|----------|
| `TaskSourceData` | id, title, isCompleted, priority, tags, urgency, taskType, etc. |
| `TaskSource` | fetchIncompleteTasks(), markComplete(), markIncomplete() |
| `TaskSourceWritable` | createTask(), updateTask(), deleteTask() |

**Existierende Implementation:**
- `LocalTaskSource.swift` - Vollständige CRUD für lokale Tasks

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` | Datenmodell mit `externalID` + `sourceSystem` - Kernstruktur für Sync |
| `Sources/Models/ReminderData.swift` | Aktueller (limitierter) Reminder-Wrapper |
| `Sources/Services/EventKitRepository.swift` | EventKit-Integration (fetch, complete, incomplete) |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | Protocol für EventKit |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | TaskSource-Implementation für lokale Tasks |
| `Sources/Protocols/TaskSource.swift` | TaskSource/TaskSourceWritable Protocols |
| `Sources/Models/TaskMetadata.swift` | Metadata für externe Task-Quellen |
| `Sources/Services/SyncEngine.swift` | Sync-Logik (aktuell nur LocalTaskSource) |
| `Sources/Models/PlanItem.swift` | View-Model mit Konstruktoren für LocalTask UND ReminderData |

## Existing Patterns

### 1. External ID Pattern
`LocalTask` hat bereits:
```swift
var externalID: String?    // z.B. Apple Reminders calendarItemIdentifier
var sourceSystem: String   // "local" / "reminders" / "notion"
```

### 2. TaskMetadata für Reminder-Erweiterung
```swift
@Model
final class TaskMetadata {
    var reminderID: String = ""
    var sortOrder: Int = 0
    var manualDuration: Int?
}
```

### 3. PlanItem Dual-Constructor
```swift
init(reminder: ReminderData, metadata: TaskMetadata)  // Für Apple Reminders
init(localTask: LocalTask)                            // Für lokale Tasks
```

## Apple Reminders Felder (EKReminder)

| Feld | Vorhanden | Typ |
|------|-----------|-----|
| `calendarItemIdentifier` | ✅ | String |
| `title` | ✅ | String |
| `isCompleted` | ✅ | Bool |
| `priority` | ✅ | Int (1-9) |
| `dueDateComponents` | ✅ | DateComponents? |
| `notes` | ✅ | String? |
| `creationDate` | ✅ | Date |
| `completionDate` | ✅ | Date? |
| `calendar` | ✅ | EKCalendar |
| Tags | ❌ | - |
| Urgency | ❌ | - |
| TaskType | ❌ | - |
| Recurrence | ⚠️ | EKRecurrenceRule (komplex) |

## Dependencies

### Upstream (was unser Code nutzt)
- EventKit Framework (EKReminder, EKEventStore)
- SwiftData Framework
- LocalTask Model
- TaskSource Protocols

### Downstream (was unseren Code nutzt)
- PlanItem (View-Model)
- BacklogView, PlanningView, TaskAssignmentView
- SyncEngine
- All UI components displaying tasks

## Architectural Options

### Option A: LocalTask als Single Source of Truth
- Apple Reminders → Import als LocalTask mit `sourceSystem: "reminders"`
- Änderungen: LocalTask → Sync zurück zu Reminders (nur unterstützte Felder)
- Extra-Felder (Tags, Urgency, etc.) bleiben nur lokal

### Option B: Parallel Storage (TaskMetadata erweitern)
- ReminderData für Reminder-Daten
- TaskMetadata erweitern für extra Felder
- Komplexere Sync-Logik

**Empfehlung:** Option A - LocalTask als Single Source of Truth

## Risks & Considerations

1. **Sync-Konflikte**: Was passiert bei gleichzeitiger Änderung in App + Reminders?
2. **Deleted Reminders**: Reminder in Apple gelöscht → LocalTask verwaist?
3. **Permission-Handling**: Was wenn User Zugriff entzieht?
4. **Performance**: Bei vielen Reminders könnte Initial-Sync langsam sein
5. **Recurrence**: Apple's EKRecurrenceRule ist komplexer als unser simpler String

## Open Questions

- [ ] Sync-Intervall: Push-basiert (EventKit Notifications) oder Poll?
- [ ] Konflikt-Resolution: Wer gewinnt bei Änderungen auf beiden Seiten?
- [ ] Scope: Alle Reminder-Listen oder nur ausgewählte?
- [ ] Initial Import: Bestehende Reminders importieren oder nur neue?

---

## Analysis

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/RemindersSyncService.swift` | CREATE | Neue Sync-Logik für bidirektionale Sync |
| `Sources/Models/ReminderData.swift` | MODIFY | Erweitern um dueDate, notes aus EKReminder |
| `Sources/Services/EventKitRepository.swift` | MODIFY | +createReminder(), +updateReminder(), +deleteReminder() |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | MODIFY | Protocol-Erweiterung für CRUD |
| `Sources/Services/SyncEngine.swift` | MODIFY | Integration von RemindersSyncService |
| `Sources/Views/SettingsView.swift` | MODIFY | Toggle für Reminders-Sync |
| `FocusBloxUITests/RemindersSyncUITests.swift` | CREATE | UI Tests für Sync-Feature |

### Scope Assessment

- **Files:** 7 (4 MODIFY, 3 CREATE)
- **Estimated LoC:** +350 / -20
- **Risk Level:** MEDIUM
  - EventKit ist gut dokumentiert
  - Bidirektionale Sync hat Konflikt-Risiko
  - Bestehende Patterns (LocalTask, externalID) reduzieren Komplexität

### Technical Approach

**Phase 1: EventKit CRUD erweitern**
1. `ReminderData` erweitern: +dueDate, +notes
2. `EventKitRepository` erweitern: +createReminder(), +updateReminder(), +deleteReminder()
3. Protocol aktualisieren

**Phase 2: Sync-Service erstellen**
1. `RemindersSyncService` erstellt:
   - `importFromReminders()` - Apple → LocalTask
   - `exportToReminders()` - LocalTask → Apple
   - `syncBidirectional()` - Konflikt-Resolution
2. Mapping: `externalID` = `calendarItemIdentifier`
3. Mapping: `sourceSystem` = "reminders"

**Phase 3: Integration**
1. SyncEngine erweitern für Reminders-Source
2. Settings: Toggle "Mit Apple Erinnerungen synchronisieren"
3. Sync bei App-Start (wenn aktiviert)

### Sync-Strategie (Empfehlung)

**Last-Write-Wins mit lokalem Vorrang:**
- Bei Import: Apple-Felder überschreiben lokale (title, priority, dueDate, notes)
- Extra-Felder (tags, urgency, taskType) bleiben erhalten
- Bei Export: Nur unterstützte Felder zu Apple schreiben

**Sync-Trigger:**
- App-Start (Pull)
- Nach lokalem Edit (Push einzelner Task)
- Pull-to-Refresh in Backlog

### Data Flow

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│ Apple Reminders │ ←── │ RemindersSyncService │ ──→ │    LocalTask    │
│   (EventKit)    │     │                      │     │   (SwiftData)   │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
        │                         │                          │
        │  calendarItemIdentifier │                          │
        │  title                  │                          │
        │  priority               │  ←───── externalID ──────│
        │  dueDateComponents      │  ←───── sourceSystem ────│
        │  notes                  │                          │
        │  isCompleted            │                          │
        └─────────────────────────┴──────────────────────────┘
                                  │
                    Extra-Felder nur lokal:
                    tags, urgency, taskType,
                    recurrence, isNextUp
```

### Feld-Mapping

| LocalTask | EKReminder | Sync-Richtung |
|-----------|------------|---------------|
| title | title | ↔ bidirektional |
| priority | priority | ↔ bidirektional |
| isCompleted | isCompleted | ↔ bidirektional |
| dueDate | dueDateComponents | ↔ bidirektional |
| taskDescription | notes | ↔ bidirektional |
| externalID | calendarItemIdentifier | ← nur Import |
| tags | - | nur lokal |
| urgency | - | nur lokal |
| taskType | - | nur lokal |
| recurrencePattern | - | nur lokal |
| isNextUp | - | nur lokal |

### Deleted Reminders Handling

Wenn ein Apple Reminder gelöscht wird:
1. Beim nächsten Sync: LocalTask mit `externalID` nicht mehr in Apple gefunden
2. Option A: LocalTask auch löschen (gefährlich)
3. Option B: `sourceSystem` auf "local" setzen (Task bleibt lokal erhalten)
4. **Empfehlung:** Option B - User entscheidet selbst über Löschen

### Open Questions (für PO)

Keine - technische Entscheidungen können intern getroffen werden.
