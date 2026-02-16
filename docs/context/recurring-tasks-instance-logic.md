# Context: Recurring Tasks - Instance Logic

## Request Summary
Recurrence-Pattern wird auf Tasks gespeichert, aber nirgends aktiv genutzt. Wenn ein wiederkehrender Task abgehakt wird, passiert nichts Besonderes - er verschwindet einfach wie ein normaler Task. Es fehlt: Instanz-Generierung bei Completion, visueller Indikator, Faelligkeits-Logik.

## Aktueller Zustand

### Was existiert bereits
1. **RecurrencePattern enum** (`Sources/Models/RecurrencePattern.swift`) - 5 Werte: none/daily/weekly/biweekly/monthly
2. **LocalTask Felder** (`Sources/Models/LocalTask.swift:42-48`):
   - `recurrencePattern: String = "none"`
   - `recurrenceWeekdays: [Int]?` (1=Mo...7=So)
   - `recurrenceMonthDay: Int?` (1-31, 32=letzter Tag)
3. **PlanItem** traegt `recurrencePattern`/`recurrenceWeekdays`/`recurrenceMonthDay` durch
4. **TaskFormSheet + CreateTaskView** haben Picker fuer Recurrence-Auswahl (funktioniert)
5. **RecurrenceUITests** testen nur den Picker (nicht die Instanz-Logik)

### Was FEHLT (das Problem)
1. **Kein visueller Indikator** - BacklogRow zeigt nicht ob ein Task wiederkehrend ist
2. **Keine Instanz-Generierung** - `completeTask()` setzt nur `isCompleted=true`, kein neuer Task
3. **Keine Faelligkeits-Berechnung** - Naechstes Datum wird nicht berechnet
4. **Keine Filterung** - Backlog unterscheidet nicht zwischen einmalig und wiederkehrend
5. **Keine Delete-Unterscheidung** - "Nur diese Instanz" vs "Ganze Serie" fehlt

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` | Task-Model mit recurrence-Feldern |
| `Sources/Models/RecurrencePattern.swift` | Enum mit 5 Patterns |
| `Sources/Models/PlanItem.swift` | DTO traegt recurrence-Daten durch |
| `Sources/Services/SyncEngine.swift:95-105` | `completeTask()` - HIER muss Instanz-Generierung rein |
| `Sources/Services/FocusBlockActionService.swift:49-52` | Completion waehrend FocusBlock - HIER auch |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | `createTask()` + `fetchIncompleteTasks()` |
| `Sources/Views/BacklogRow.swift` | Kein Recurrence-Badge vorhanden |
| `Sources/Views/BacklogView.swift:496-505` | `completeTask()` Handler |
| `Sources/Views/TaskFormSheet.swift` | Recurrence-Picker (funktioniert bereits) |
| `FocusBloxMac/` | macOS hat kein Recurrence-Handling |

## Existing Patterns

### Completion Flow (aktuell)
1. User tippt Checkbox in BacklogRow
2. → `BacklogView.completeTask()` (Zeile 496)
3. → `SyncEngine.completeTask()` (Zeile 95)
4. → `task.isCompleted = true; task.completedAt = Date()`
5. Task verschwindet aus Backlog (fetchIncompleteTasks filtert isCompleted)

### FocusBlock Completion (parallel)
1. User tippt "Erledigt" in FocusLiveView/MacFocusView
2. → `FocusBlockActionService.completeTask()` (Zeile 20)
3. → Gleich: `localTask.isCompleted = true; localTask.completedAt = Date()`

### Badge-Pattern in BacklogRow
- Importance: Icon + Farbe (immer sichtbar)
- Urgency: Icon + Farbe (immer sichtbar)
- Category: Icon + Label + Farbe
- Duration: Icon + "Xm" Text
- Due Date: Kalender-Icon + Text
- **Recurrence: FEHLT komplett**

## Dependencies

### Upstream (was wir nutzen)
- `SyncEngine.completeTask()` - muss erweitert werden
- `FocusBlockActionService.completeTask()` - muss erweitert werden
- `LocalTaskSource.createTask()` - zum Erstellen neuer Instanzen
- `RecurrencePattern` enum - fuer naechstes-Datum-Berechnung

### Downstream (was uns nutzt)
- `BacklogView` - ruft `completeTask()` auf
- `FocusLiveView` / `MacFocusView` - rufen FocusBlockActionService auf
- `BacklogRow` - zeigt Task-Metadaten an
- CloudKit Sync - neue Instanzen muessen synchen

## Risiken & Bedenken

1. **Scope ist GROSS** - ACTIVE-todos listet 3 Phasen mit insgesamt ~500 LoC
2. **Scoping-Limit** beachten: Max 4-5 Dateien, ±250 LoC pro Aenderung
3. **CloudKit-Sync**: Neue Tasks via `modelContext.insert()` synchen automatisch, aber Timing beachten
4. **FocusBlock-Completion**: Nicht nur BacklogView, auch FocusBlockActionService muss Instanzen generieren
5. **Doppelte Instanz-Generierung**: Wenn sowohl SyncEngine als auch FocusBlockActionService Instanzen erstellen, muss Dedup-Logik her
6. **macOS**: Braucht gleiche Logik - Shared Service in `Sources/` ist Pflicht

---

## Analysis (Phase 2)

### Type
Feature (Phase 1A eines groesseren Features)

### Alle Completion-Pfade (9 gefunden)

| # | Pfad | Datei | Zeile | Aufrufer |
|---|------|-------|-------|----------|
| 1 | SyncEngine.completeTask() | SyncEngine.swift | 95-105 | BacklogView:500 |
| 2 | FocusBlockActionService.completeTask() | FocusBlockActionService.swift | 20-56 | FocusLiveView:506, MacFocusView:456, MenuBarView:413 |
| 3 | LocalTaskSource.markComplete() | LocalTaskSource.swift | 59-63 | Protocol interface (nicht direkt genutzt) |
| 4 | CompleteTaskIntent.perform() | CompleteTaskIntent.swift | 29 | Siri/Shortcuts |
| 5 | EventKitRepository.markReminderComplete() | EventKitRepository.swift | 145 | Reminders Sync (nur EKReminder, nicht LocalTask) |
| 6 | macOS TaskInspector toggle | TaskInspector.swift | 170 | Direkte UI-Toggle |
| 7 | macOS ContentView toggle | ContentView.swift | 530/599 | Direkte UI-Toggle |
| 8 | macOS MenuBarView | MenuBarView.swift | 408 | Via SyncEngine (bereits abgedeckt durch #1) |
| 9 | EventKitRepository.updateReminder() | EventKitRepository.swift | 214 | Generisches Update (nur EKReminder) |

### Phase 1A Scope (dieses Ticket)

**Strategie:** Zentralen `RecurrenceService` erstellen, der von den 2 Haupt-Completion-Pfaden aufgerufen wird.

| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Services/RecurrenceService.swift | CREATE | Naechstes-Datum-Berechnung + Instanz-Generierung |
| Sources/Services/SyncEngine.swift | MODIFY | completeTask() ruft RecurrenceService auf |
| Sources/Services/FocusBlockActionService.swift | MODIFY | completeTask() ruft RecurrenceService auf |
| Sources/Views/BacklogRow.swift | MODIFY | Recurrence-Badge in metadataRow |
| FocusBloxTests/RecurrenceServiceTests.swift | CREATE | Unit Tests fuer Datums-Berechnung |

### Scope Assessment
- Files: 5 (3 MODIFY, 2 CREATE)
- Estimated LoC: +~180 (Service ~70, Badge ~20, Integration ~15, Tests ~75)
- Risk Level: MEDIUM (Aenderung an Completion-Pfaden)

### Technical Approach

1. **RecurrenceService** (enum, stateless):
   - `nextDueDate(pattern:weekdays:monthDay:from:)` → Date
   - `createNextInstance(from:in:)` → LocalTask (kopiert Attribute, setzt neues dueDate, isCompleted=false)

2. **Integration in SyncEngine.completeTask():**
   - Nach `task.isCompleted = true` pruefen ob `recurrencePattern != "none"`
   - Wenn ja: `RecurrenceService.createNextInstance(from: task, in: modelContext)`

3. **Integration in FocusBlockActionService.completeTask():**
   - Gleiche Logik nach dem localTask-Completion-Block

4. **BacklogRow Recurrence-Badge:**
   - Zwischen categoryBadge und tags einfuegen
   - Icon: `arrow.triangle.2.circlepath`
   - Label: Pattern displayName (z.B. "Taeglich")
   - Farbe: .purple
   - Nur sichtbar wenn recurrencePattern != "none"

### Nicht in Phase 1A (spaeter)
- macOS direkte Toggles (TaskInspector, ContentView) → Phase 1B
- Siri/Shortcuts CompleteTaskIntent → Phase 1B
- Delete-Dialog "Nur diese/Ganze Serie" → Phase 2
- Backlog-Filterung recurring vs einmalig → Phase 2
- macOS MacBacklogRow Badge → Phase 1B
