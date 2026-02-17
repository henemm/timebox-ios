# Context: Recurring Tasks Phase 1B/2

## Request Summary
Wiederkehrende Tasks sollen nur im Backlog erscheinen wenn sie faellig/aktiv sind. Beim Loeschen und Bearbeiten soll ein Dialog "Nur diese Instanz / Ganze Serie" erscheinen. macOS braucht Recurrence-Badge und korrekte Completion-Integration.

## Aktueller Zustand (Phase 1A - implementiert)

### Was funktioniert
- `RecurrenceService` berechnet naechstes Datum + erstellt neue Instanz bei Completion
- `SyncEngine.completeTask()` und `FocusBlockActionService.completeTask()` rufen RecurrenceService auf
- `BacklogRow` zeigt lila Recurrence-Badge (iOS)
- RecurrencePattern enum: none/daily/weekly/biweekly/monthly

### Was NICHT funktioniert / fehlt
1. **Alle Instanzen sichtbar:** `fetchIncompleteTasks()` filtert nur `!isCompleted` - keine Pruefung auf dueDate. Erledigte Instanzen verschwinden, aber ALLE zukuenftigen Instanzen sind sofort sichtbar.
2. **Kein Serien-Konzept:** LocalTask hat kein `seriesID` oder Parent-Referenz. Jede Instanz ist ein eigenstaendiger Task. "Ganze Serie loeschen" ist architektonisch nicht moeglich.
3. **macOS Completion ohne RecurrenceService:** `TaskInspector.swift:170` togglet `task.isCompleted` direkt - kein RecurrenceService-Aufruf.
4. **macOS kein Recurrence-Badge:** `MacBacklogRow` zeigt keinen Recurrence-Indikator.
5. **Delete ist sofort:** `SyncEngine.deleteTask()` loescht ohne Rueckfrage.
6. **Edit ohne Serien-Logik:** TaskFormSheet bearbeitet immer nur die einzelne Instanz.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Services/RecurrenceService.swift` | Instanz-Generierung (Phase 1A) |
| `Sources/Models/LocalTask.swift` | Task-Model - KEIN seriesID Feld |
| `Sources/Models/RecurrencePattern.swift` | Enum mit 5 Patterns |
| `Sources/Services/SyncEngine.swift` | completeTask (mit Recurrence), deleteTask (ohne Dialog) |
| `Sources/Services/FocusBlockActionService.swift` | completeTask (mit Recurrence) |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | fetchIncompleteTasks - keine dueDate-Filterung |
| `Sources/Views/BacklogView.swift` | deleteTask(), completeTask() - keine Serien-Dialoge |
| `Sources/Views/BacklogRow.swift` | iOS Recurrence-Badge vorhanden |
| `FocusBloxMac/MacBacklogRow.swift` | KEIN Recurrence-Badge |
| `FocusBloxMac/TaskInspector.swift:170` | Direkte isCompleted-Toggle OHNE RecurrenceService |
| `Sources/Views/TaskFormSheet.swift` | Hat alle 11 recurrence-Params |

## Architektonisches Problem: Kein Serien-Konzept

**Aktuell:** Jede wiederkehrende Instanz ist ein eigenstaendiger LocalTask. Es gibt keine Verbindung zwischen Instanzen derselben Serie.

**Konsequenz:**
- "Ganze Serie loeschen" = Alle Tasks mit gleichem Title + recurrencePattern finden? Fragil.
- "Alle zukuenftigen Instanzen aendern" = Unmoeglich ohne Serien-ID.

**Loesung: `recurrenceGroupID` einfuehren:**
- Neues Feld auf LocalTask: `var recurrenceGroupID: String?`
- Bei Erstellung einer recurring Task bekommt sie eine GroupID (UUID)
- `RecurrenceService.createNextInstance()` kopiert die GroupID
- Alle Instanzen einer Serie teilen dieselbe GroupID
- "Ganze Serie loeschen" = alle Tasks mit gleicher GroupID loeschen
- "Alle zukuenftigen aendern" = alle unerledigten Tasks mit gleicher GroupID aendern

**Migration:** Bestehende recurring Tasks ohne GroupID bekommen beim naechsten Completion eine neue GroupID. Oder: einmalige Migration beim App-Start.

## Existing Patterns

### Delete mit Confirmation Dialog (Vorbild)
Aktuell gibt es KEINEN Confirmation Dialog beim Loeschen. Swipe-Delete loescht sofort. Fuer Serien-Tasks brauchen wir einen `.confirmationDialog` mit 2 Optionen.

### Apple Kalender Vorbild
Apple Kalender zeigt bei wiederkehrenden Events:
- "Dieses Ereignis" (nur diese Instanz)
- "Dieses und alle kuenftigen Ereignisse"
- "Alle Ereignisse"

Fuer unseren Fall reichen 2 Optionen:
- "Nur diese Aufgabe"
- "Alle offenen dieser Serie"

## Dependencies

### Upstream
- SwiftData ModelContext (Task-CRUD)
- RecurrenceService (Instanz-Generierung)
- RecurrencePattern enum

### Downstream
- BacklogView (iOS) - Delete/Edit Flows
- macOS ContentView/TaskInspector - Delete/Edit Flows
- CloudKit Sync - neues Feld `recurrenceGroupID` muss synchen
- FocusBlockActionService - Completion

## Risks & Considerations

1. **SwiftData Migration:** Neues `recurrenceGroupID` Feld erfordert Schema-Migration (CloudKit: Default-Wert = nil reicht)
2. **CloudKit Sync:** Neues Feld synct automatisch wenn Default vorhanden (nil OK)
3. **Scope-Explosion:** 5 Teilbereiche (A-E) zusammen sind deutlich mehr als 250 LoC
4. **Empfehlung:** In 2-3 Unter-Tickets splitten:
   - Ticket 1: recurrenceGroupID + Backlog-Sichtbarkeit (A) + macOS Badge (D partial)
   - Ticket 2: Delete-Dialog (B) + Edit-Dialog (C)
   - Ticket 3: macOS Completion-Fix + Backlog-Filter (E)

## Existing Specs
- `docs/specs/features/recurring-tasks-phase1a.md` - Phase 1A Spec (implementiert)
- `docs/context/recurring-tasks-instance-logic.md` - Analyse aller 9 Completion-Pfade
