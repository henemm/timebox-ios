# FEATURE_024: Sprint Follow-up-Aktion

**Modus:** NEU
**Status:** Geplant — SPEC READY
**Prioritaet:** Medium
**Aufwand:** Mittel
**Kategorie:** Primary Feature

---

## Problem / Nutzen

Waehrend eines Sprints kommt es oft vor, dass ein Task *angefangen* wurde —
z.B. eine E-Mail geschickt, ein Anruf hinterlassen, ein PR eroeffnet — aber
noch kein abschliessendes Ergebnis vorliegt. Die aktuellen Optionen passen
nicht:

- **Erledigt** ist falsch: Der Task ist nicht wirklich fertig.
- **Ueberspringen** verschiebt ihn nur ans Ende der Queue, markiert ihn nicht
  und macht ihn nicht bearbeitbar.

**Follow-up** loest dieses Muster: Den Task als erledigt schliessen (er ist
"done for now"), aber sofort eine editierbare Kopie anlegen, damit der User
den Folgeschritt (z.B. Ergebnis abwarten, Feedback einholen) als neuen Task
definieren kann.

---

## Gewuenschtes Verhalten

### Ausloeser

Dritter Button in `FocusLiveView.currentTaskView()`, neben "Ueberspringen" und
"Erledigt". Label: "Follow-up", Icon: `arrow.uturn.right.circle.fill`,
Farbe: `.blue`.

### Schrittfolge beim Antippen

1. Aktuellen Task per `FocusBlockActionService.completeTask()` als erledigt markieren.
   (Identisches Verhalten wie "Erledigt": completedTaskIDs, taskTimes, SwiftData.)
2. Neuen `LocalTask` als Kopie des aktuellen anlegen:
   - `title` = Originalname (unveraendert)
   - Alle Metadaten uebernehmen: `importance`, `urgency`, `estimatedDuration`,
     `taskType`, `tags`, `dueDate`
   - `isCompleted = false`, `completedAt = nil`, `assignedFocusBlockID = nil`,
     `isNextUp = false`
   - `recurrencePattern = "none"` (Kopie ist keine wiederkehrende Aufgabe)
   - `blockerTaskID = nil` (kein Blocker uebernehmen)
3. `TaskFormSheet` im Edit-Modus mit dem neuen Task oeffnen, damit der User
   den Titel und Felder anpassen kann, bevor der Task gespeichert wird.
4. Nach "Speichern" im Sheet: Task wird in SwiftData persistiert. Sprint laeuft
   normal weiter (naechster Task wird aktuell).
5. Nach "Abbrechen" im Sheet: Kopie wird verworfen (nicht gespeichert).

### Edge Cases

- **Letzter verbleibender Task wird mit Follow-up beendet:** Wie bei "Erledigt"
  endet der Sprint — Sprint Review oeffnet sich nach dem Sheet.
- **Follow-up im Sheet: Benutzer aendert nichts:** Task wird mit Originaldaten
  gespeichert. Das ist valides Verhalten.
- **TaskFormSheet oeffnet sich NACH dem completeTask-Call:** Der Sprint laeuft
  weiter. Das Sheet ist modal und blockiert nicht den Sprint-Timer.

---

## Abgrenzung: Was Follow-up NICHT tut

- Kein Wiederkehrend-Muster setzen (das ist Sache des Users im Sheet).
- Kein automatisches "isNextUp = true" setzen (der User entscheidet im Sheet
  oder spaeter im Backlog).
- Keine Verknuepfung (Blocker/Dependent) zwischen Original und Kopie.

---

## Betroffene Systeme

| System | Datei | Rolle |
|--------|-------|-------|
| Sprint-View (UI) | `Sources/Views/FocusLiveView.swift` | Neuer Button + Handler |
| Action-Service | `Sources/Services/FocusBlockActionService.swift` | Neue `followUpTask()`-Methode |
| Task-Formular | `Sources/Views/TaskFormSheet.swift` | Wird im Edit-Modus wiederverwendet |
| Task-Modell | `Sources/Models/LocalTask.swift` | Keine Aenderung noetig |
| Test-Datei | `FocusBloxTests/FocusBlockActionServiceTests.swift` | Neue Unit Tests |
| UI-Test-Datei | `FocusBloxUITests/SprintFollowUpUITests.swift` | Neue UI Tests (TDD RED) |

---

## Scoping

| Metrik | Wert |
|--------|------|
| Dateien geaendert | 3 (FocusLiveView, FocusBlockActionService, Tests) |
| Neue Dateien | 1 (SprintFollowUpUITests.swift) |
| Gesamt LoC (+-) | ~120 |

Scoping eingehalten: 4 Dateien, deutlich unter 250 LoC.

---

## Seiteneffekte

- `FocusBlockActionService.followUpTask()` ruft intern `completeTask()` auf —
  alle bestehenden Effekte (Recurring-Instanz, DEP-4b, Spotlight) laufen wie
  gehabt.
- `TaskFormSheet` im Edit-Modus benoetigt einen neuen Initialisierungs-Pfad:
  Task wird VOR dem Sheet-Oeffnen in SwiftData eingefuegt, aber noch NICHT
  committed — oder alternativ: Task wird temporaer gehalten und erst bei
  "Speichern" wirklich committed.
  **Entscheidung:** Task wird SOFORT inserted + saved, "Abbrechen" loescht ihn
  wieder. Das ist das einfachste, robusteste Muster ohne temporaeren State.

---

## Nicht betroffene Systeme

- `SprintReviewSheet` — keine Aenderung
- `FocusBlock`-Modell — keine Aenderung
- macOS `MacFocusView` — MVP nur iOS, macOS als Folge-Ticket moeglich
