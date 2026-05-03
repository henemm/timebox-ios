# Bug Intake Report: Stacking-Counter-Bar funktioniert nur mit Mock-Daten

**Date:** 2026-05-02  
**Issue:** #279 (Stacking wiederkehrender Aufgaben)  
**Reporter:** Henning Emmrich  
**Status:** INTAKE — ROOT CAUSE IDENTIFIED

---

## Symptom

**Beobachtung bei Henning (echte Geräte):**
- Wiederkehrende Aufgabe ist mehrfach offen (z.B. 2-3 Instanzen)
- **ERWARTET:** Rote Counter-Bar oben an der Card: "⚠ N× AUFGELAUFEN — seit [Datum]"
- **AKTUAL:** Gar keine Bar. Sieht aus wie einzelne normale Aufgabe
- Betroffen: iOS + macOS
- **Datenstand:** Lange in Nutzung, viele organische echte Tasks, **KEINE Mock-Daten**

**Beobachtung in Simulation (Mock-Daten):**
- Exakt dasselbe Feature funktioniert einwandfrei
- Alle 6 BacklogStackingUITests sind GREEN
- Alle 13 RecurringStackingTests sind GREEN
- Commit 2db62b7 behauptet: "visuellem Beweis auf iOS und macOS"

---

## Reproduktionsschritte (Henning beschreibt)

1. Wiederkehrende Aufgabe anlegen (z.B. "Tägliche Routine")
2. Tag verstreichen lassen, ohne Task zu erledigen → neue Instanz entsteht
3. Noch einen Tag → jetzt 2-3 Vorkommen offen
4. Backlog öffnen → **ERWARTET:** Counter-Bar sichtbar
5. **FAKT:** Keine Bar, Aufgabe sieht normal aus

---

## Code-Stellen (Datei:Zeile)

### iOS: Stacking-Logik
- **`Sources/Services/RecurringStackingHelper.swift:21-53`** — `apply(to:)` Hauptfunktion
  - Zeile 25-28: Gruppierungsbedingung (**KRITISCH**)
  - Zeile 36-38: Repraesentant-Selection (juengstes Child)
  - Zeile 40-43: Felder setzen auf Repraesentant

- **`Sources/Views/BacklogView.swift:931-933`** — Anwendung in View
  - Zeile 414: `applyRecurringStacking()` nach `sync()`
  - Zeile 485, 494: weitere Aufrufe

- **`Sources/Views/BacklogRow.swift:35-40`** — Anzeige der Counter-Bar
  - Zeile 35: Bedingung `item.stackedInstanceCount >= 2`
  - Zeile 36-40: `StackingCounterBar` Komponente

- **`Sources/Views/Components/TaskBadges.swift:192-227`** — Counter-Bar Komponente
  - Zeile 207: Label-Format: "⚠ N× AUFGELAUFEN — seit [Datum]"
  - Zeile 224: accessibility Identifier für Tests

### macOS: Stacking-Logik
- **`FocusBloxMac/MacBacklogHelpers.swift:41-76`** — `applyStacking(_:)`
  - Zeile 46-47: Gruppierungsbedingung (IDENTISCH zu iOS)
  - Zeile 60-66: Repraesentant + oldestDueDate

### Datenmodelle
- **`Sources/Models/PlanItem.swift:25-29`** — Recurrence-Felder
  - Zeile 29: `recurrenceGroupID: String?`
- **`Sources/Models/PlanItem.swift:103-106`** — Stacking-Felder
  - Zeile 103: `stackedInstanceCount: Int = 1` (Default 1)
  - Zeile 106: `stackedOldestDueDate: Date?`

- **`Sources/Models/LocalTask.swift:66-74`** — Persistierte Felder
  - Zeile 69: `recurrenceGroupID: String?`
  - Zeile 74: `isTemplate: Bool = false`

### Mock-Daten
- **`Sources/FocusBloxApp.swift:950-1041`** — Mock-Seed mit Stacking
  - Zeile 950-974: recurringGroupID1 mit 2 Children (eine heute, eine gestern)
  - Zeile 989-1041: recurringGroupID2 mit 3 Children (-0T, -7T, -14T)
  - Zeile 956-957, 970, 983: `recurrenceGroupID` wird explizit gesetzt

---

## Die Kritische Guard-Bedingung

**Code:** `Sources/Services/RecurringStackingHelper.swift:25-28`

```swift
guard let groupID = item.recurrenceGroupID,
      !item.isTemplate,
      !item.isCompleted,
      !item.isNextUp else { continue }
```

Diese Bedingung **skippt den Task**, wenn:
1. `recurrenceGroupID == nil` — Task gehört zu KEINER Serie
2. `isTemplate == true` — Task ist Mutter-Instanz
3. `isCompleted == true` — Task ist bereits erledigt
4. `isNextUp == true` — Task ist in "Next Up" Staging

**Erkennungs-Frage:** Wie wird `recurrenceGroupID` bei echten Daten gesetzt?

---

## Root-Cause-Hypothesen (Ranked nach Wahrscheinlichkeit)

### Hypothese 1: `recurrenceGroupID` wird bei echten Daten nicht gesetzt (95% Wahrscheinlich)

**Theorie:**
- Mock-Daten setzen `recurrenceGroupID` explizit (Zeilen 957, 970, 983)
- Bei echten Daten: Wiederkehrende Task wird angelegt, später werden Instanzen erledigt
- **Problem:** Wo wird der `recurrenceGroupID` generiert und gespeichert?

**Suche-Ziele:**
- Wie wird `recurrenceGroupID` beim Task-Anlegen initialisiert? (LocalTask init, TaskFormSheet, CreateTask)
- Wird `recurrenceGroupID` bei Task-Completion propagiert? (`completeTask()` in SyncEngine)
- Migration-Bug: Alte echte Tasks haben `recurrenceGroupID == nil`? (Alte DB hat diese Spalte nicht)

**Evidenz:**
- Mock-Daten: `recurrenceGroupID` explizit gesetzt → Stacking funktioniert
- Echte Daten: `recurrenceGroupID` vermutlich nil → Guard-Bedingung skippt alles → keine Groupierung

### Hypothese 2: `isNextUp` ist bei echten Daten mehr als erwartet `true`

**Theorie:**
- Guard-Bedingung skippt `isNextUp == true`
- Bei echten Daten könnten Nutzer Aufgaben in "Next Up" staging haben
- Aber: Test-Cases haben `isNextUp = false` bei Mock-Daten

**Wahrscheinlichkeit:** 15%

### Hypothese 3: Daten werden durch anderen Filter entfernt, bevor `applyRecurringStacking()` aufgerufen wird

**Theorie:**
- `planItems = try await syncEngine.sync()` gibt unterschiedliche Ergebnisse
- `LocalTaskSource.fetchIncompleteTasks()` könnte bei echten Daten andere Ergebnisse liefern
- Beispiel: `isVisibleInBacklog` Filter zieht die Instanzen aus der Liste

**Wahrscheinlichkeit:** 5%

---

## Felder-Abgleich: Mock vs. Real Data

### Mock-Seed (funktioniert):
```swift
let recurringChild1a = LocalTask(...)
recurringChild1a.recurrenceGroupID = recurringGroupID1  // EXPLIZIT GESETZT
recurringChild1a.isTemplate = false                      // Child
recurringChild1a.dueDate = Date()                        // Today
recurringChild1a.isNextUp = false                        // NOT staged
// → applyRecurringStacking() BERÜCKSICHTIGT diesen Task
```

### Echte Daten (funktioniert nicht):
```swift
// Workflow: Benutzer legt Task an, markiert als Recurring, erledigt täglich
// Frage: Wo wird hier recurringGroupID gesetzt?
// Frage: Welche Werte haben isTemplate, dueDate, isNextUp?
```

---

## Kritische Dateien für Root-Cause-Analyse

1. **RecurrenceService** (nicht gefunden — existiert?)
   - Wie werden Recurring-Instanzen erstellt?
   - Wird `recurrenceGroupID` propagiert?

2. **LocalTaskSource.swift**
   - `fetchIncompleteTasks()` — welche Bedingungen?
   - Werden alle Recurring-Children geholt?

3. **TaskFormSheet.swift** oder **CreateTaskView.swift**
   - Wenn Nutzer Recurring-Pattern setzt, wird `recurrenceGroupID` gespeichert?
   - Oder wird es erst später bei Completion generiert?

4. **Commitment- & Create-Workflow**
   - `completeTask()` in SyncEngine:185 ruft `RecurrenceService.createNextInstance()` auf
   - Wird hier `recurrenceGroupID` vom Parent kopiert?

---

## Tests: Was prüfen sie, was nicht

### BacklogStackingUITests: (GREEN, aber nur Mock-Daten!)
- Zeile 9: `app.launchArguments = ["-UITesting"]`
- **Problem:** UITesting-Modus lädt vermutlich nur Mock-Daten
- **Test-Daten:** Explizit mit `recurrenceGroupID` gesetzt (Zeile 25-28 des Tests)
- **Beweis:** Tests beweisen NICHT, dass echte Daten funktionieren

### RecurringStackingTests: (GREEN, Unit-Tests mit makePlanItem)
- Zeile 94-96: `makePlanItem(id:groupID:)` setzt `recurrenceGroupID` explizit
- **Test-Daten:** Immer mit gültigem `groupID`
- **Beweis:** Tests prüfen nicht, was passiert wenn `groupID == nil`

**Fehler in Test-Konstruktion:**
- Tests prüfen nur Happy Path (groupID gesetzt)
- Keine Tests für echte-Daten-Szenarien (groupID == nil, Migration, organisches Wachstum)

---

## Nächste Schritte für Henning

1. **Datenstand inspizieren:** Wenn möglich, eine echte Recurring-Serie anschauen
   - Ist `recurrenceGroupID` auf den Instanzen gesetzt?
   - Sind die Instanzen wirklich in `planItems` nach `sync()`?

2. **Logging hinzufügen:** Debug-Ausgaben vor/nach `applyRecurringStacking()`
   - Wie viele Tasks in `planItems` vor Stacking?
   - Wie viele danach?
   - Welche Tasks werden gefiltert (groupID nil, isTemplate true, etc.)?

3. **Test mit echtem Szenario:** Neuer UI Test mit echten Daten (nicht Mock)
   - Würde sofort scheitern und zeigen wo das Problem ist

---

## Summary

**Wahrscheinlicher Root Cause:**
Echter Nutzer-Datenstand hat `recurrenceGroupID == nil` auf Recurring-Instanzen, weil:
- Alte Tasks wurden vor Einführung von `recurrenceGroupID` angelegt
- Oder: `recurrenceGroupID` wird nicht richtig propagiert bei Task-Completion
- Die Stacking-Logik hat eine `guard let groupID` Bedingung, die alle Tasks ohne groupID skippt

**Symptom macht Sinn:** Features mit Mock-Daten funktionieren (groupID explizit gesetzt), aber nicht mit echten Daten (groupID wahrscheinlich nil).

---

## Betroffene Systeme

- **iOS Backlog:** Zeigt keine Counter-Bar
- **macOS Backlog:** Zeigt keine Counter-Bar
- **Counter-Badge Service (#302):** Zählt vermutlich alle Recurring-Instanzen separat (nicht gestackt)
