# Bug-Analyse: Tasks mit zukuenftigen Daten in "Alle Tasks"

## Zusammenfassung der 5 Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- 9 Commits zu recurring tasks (Phase 1A, 1B Tickets 1-3, Dedup, macOS-Fix)
- Letzter Fix (880fc03): macOS zeigte zukuenftige recurring Tasks — gefixt via `isVisibleInBacklog`
- Offener Punkt: Quick-Edit Recurrence Params (Bug 48 Restwirkung, nicht blockernd)

### Agent 2: Datenfluss-Trace
- iOS: `LocalTaskSource.fetchIncompleteTasks()` -> `.filter { $0.isVisibleInBacklog }` -> `SyncEngine.sync()` -> `BacklogView.planItems`
- **ALLE iOS View-Modi** nutzen gefilterte `planItems` — kein Bypass moeglich
- macOS: `@Query` -> `visibleTasks` computed property mit `isVisibleInBacklog` — ebenfalls korrekt

### Agent 3: Alle Schreiber
- **KRITISCHER FUND:** `RemindersImportService` setzt `dueDate` aus dem Reminder, aber **NICHT `recurrencePattern`** — bleibt auf Default "none"
- D.h. importierte Reminders mit Future-Dates erscheinen IMMER in "Alle Tasks" weil `isVisibleInBacklog` bei `recurrencePattern == "none"` sofort `true` zurueckgibt

### Agent 4: Alle Szenarien
- 20 Szenarien geprueft — Filter funktioniert korrekt fuer RECURRING Tasks
- Non-recurring Tasks mit Future-Dates werden vom Filter NICHT erfasst (by design)

### Agent 5: Blast Radius
- macOS hat mehrere Views mit `@Query` ohne Filter (MacAssignView, MacReviewView, MacFocusView, MenuBarView)
- watchOS hat KEINEN `isVisibleInBacklog`-Filter

---

## Hypothesen

### Hypothese 1: Importierte Reminders haben recurrencePattern "none" trotz Future-Date (HOCH)

**Beschreibung:** `RemindersImportService.swift:57-64` erstellt Tasks mit:
- `dueDate: reminder.dueDate` (kann in der Zukunft liegen)
- `recurrencePattern` wird NICHT gesetzt → Default "none"
- `taskType` wird NICHT gesetzt → Default "tbd" (daher die "?" Icons)

`isVisibleInBacklog` gibt sofort `true` zurueck wenn `recurrencePattern == "none"`.

**Beweis DAFUER:**
- Screenshot: Tasks "Zehnagel" (01.03.26), "Fahrradkette reinigen" (15.03.26) haben alle "?" Icons = kein Kategorie/Typ = typisch fuer Import
- `ReminderData` hat kein `recurrencePattern`-Feld
- `RemindersImportService` setzt nur: title, importance, dueDate, taskDescription

**Beweis DAGEGEN:** Keiner. Code ist eindeutig.

**Wahrscheinlichkeit:** HOCH (95%)

### Hypothese 2: User erwartet dass ALLE Tasks mit Future-Date versteckt werden (MITTEL)

**Beschreibung:** Das Feature versteckt nur RECURRING Tasks mit Future-Date. Nicht-recurring Tasks mit Future-Date bleiben sichtbar. Moeglicherweise ist die Erwartung, dass "Alle Tasks" keine zukuneftigen Tasks zeigt — unabhaengig von Recurrence.

**Beweis DAFUER:**
- Screenshot zeigt mehrere Tasks mit Future-Dates die sichtbar sind
- Diese Tasks sind NICHT recurring — also funktioniert der Filter korrekt
- Aber das Ergebnis sieht fuer den User "falsch" aus

**Beweis DAGEGEN:**
- Spec sagt explizit: "Nicht-recurring Tasks sind nicht betroffen"
- "Bald faellig" Sidebar-Filter existiert fuer Tasks mit nahem Deadline

**Wahrscheinlichkeit:** MITTEL (40%) — abhaengig von Hennings Erwartung

### Hypothese 3: Apple Reminders die WIEDERKEHREND sind verlieren Recurrence beim Import (HOCH)

**Beschreibung:** Wenn ein User einen wiederkehrenden Reminder in Apple Reminders hat (z.B. "Fahrradkette reinigen" alle 2 Wochen), importiert FocusBlox ihn als normalen Task OHNE recurrencePattern. Die Recurrence-Info von `EKReminder.recurrenceRules` wird nicht uebernommen.

**Beweis DAFUER:**
- `ReminderData` hat kein Feld fuer Recurrence
- `EKReminder` hat `.recurrenceRules: [EKRecurrenceRule]?`
- Import verliert diese Info komplett
- Resultat: Task hat Future-Date (naechstes Faelligkeitsdatum) aber `recurrencePattern == "none"`

**Beweis DAGEGEN:** Wir wissen nicht ob die Tasks im Screenshot tatsaechlich wiederkehrende Reminders waren.

**Wahrscheinlichkeit:** HOCH (80%)

---

## Wahrscheinlichste Ursache

**Hypothese 1 + 3 kombiniert:** Die Tasks mit Future-Dates im Screenshot (Zehnagel, Fahrradkette reinigen, etc.) sind aus Apple Reminders importiert. Sie haben:
- `dueDate` aus dem Reminder (Zukunft)
- `recurrencePattern == "none"` (Import verliert Recurrence-Info)
- Kein Kategorie/Typ (alle "?" Icons)

Der `isVisibleInBacklog`-Filter greift nur bei `recurrencePattern != "none"` — daher sind diese Tasks sichtbar.

**Warum die anderen weniger wahrscheinlich:**
- Hypothese 2 widerspricht der Spec (nur recurring Tasks sollen gefiltert werden)
- Allerdings koennte die Spec die Import-Situation nicht beruecksichtigt haben

---

## Blast Radius

- iOS "Alle Tasks": Zeigt importierte Reminders mit Future-Dates (visuell stoerend)
- macOS: Gleiches Problem
- watchOS: Kein `isVisibleInBacklog`-Filter + gleiche importierte Tasks
- macOS weitere Views (MacAssignView, MacReviewView, MacFocusView): `@Query` ohne Filter

---

## Offene Frage an Henning

Zwei moegliche Fix-Richtungen:
1. **Import-Fix:** `RemindersImportService` soll `EKReminder.recurrenceRules` auswerten und `recurrencePattern` korrekt setzen — dann greift der bestehende Filter
2. **Breiterer Filter:** ALLE Tasks mit Future-Date aus "Alle Tasks" verstecken (nicht nur recurring) — waere eine Verhaltensaenderung

Welche Richtung ist gewuenscht?
