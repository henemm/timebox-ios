# Bug Intake: Wiederkehrende Stacking-Badges fehlen

**Datum:** 2026-04-30  
**Status:** Diagnose durchgeführt  

## Symptom

Gestackte wiederkehrende Tasks zeigen **keine Nummer-Badges** (z.B. "x3", "x2") in der Backlog-Liste, obwohl Mock-Daten mit 2-3 Instanzen pro Recurring-Serie vorhanden sind.

**Beispiel vom letzten Screenshot (`/tmp/bug_vorher_ios.png`):**
- 4 Tasks in "Heute"-Section sichtbar
- Wochenreview-Stacking-Gruppe (3 Instanzen: heute, -7 Tage, -14 Tage) → **nicht sichtbar im Backlog**
- Täglich-Lesen-Stacking-Gruppe (2 Instanzen: heute, -1 Tag) → **nicht sichtbar im Backlog**

## Reproduktionsschritte

1. App starten mit Mock-Daten (`seedUITestData()` wird aufgerufen)
2. Zum Backlog-Tab navigieren
3. Suche nach "[MOCK] Wochenreview" Tasks
4. **Ergebnis:** 0 Rows gefunden (nicht 1 Row mit Badge, auch nicht 3 separate Rows)

## Root Cause Analyse

**Vorabanalyse basierend auf bisherigen Versuchen (commit `56dc58c`):**

Der Bug liegt **nicht** in der Stacking-Logik selbst (`applyRecurringStacking()` ist richtig implementiert).  
Der Bug liegt in der **Filter-Pipeline** davor, die die Recurring-Child-Instanzen GAR NICHT bis zur Render-Phase durchlässt.

**Filter-Kette im Backlog:**
```
FocusBloxApp.seedUITestData()
  ↓
MockData: 6 Recurring-Child-Instanzen eingefügt
  ↓
BacklogView.loadTasks()
  ↓
SyncEngine.sync()
  ↓
LocalTaskSource.fetchIncompleteTasks()
  ↓
Filter: filter { $0.isVisibleInBacklog && $0.lifecycleStatus != "raw" }
  ↓
❌ Problem hier: Kinder landen NICHT in der Liste
  ↓
BacklogView.planItems (leer für Recurring-Serien)
  ↓
applyRecurringStacking() (kann nicht stapeln was nicht da ist)
  ↓
BacklogRow.render (0 Rows für Wochenreview)
```

## Verdächtige Code-Stellen

1. **`Sources/Models/LocalTask.swift:85-93`** — `isVisibleInBacklog` Berechnung
   - Filterlogik scheint korrekt
   - Prüft: `isTemplate` (sollte false sein), `dueDate < startOfTomorrow` (Mock-Daten haben heute/-7/-14)
   - Könnte aber andere versteckte Bedingungen geben

2. **`Sources/Services/TaskSources/LocalTaskSource.swift:45`** — Filter-Aplikation
   - `return allIncomplete.filter { $0.isVisibleInBacklog && $0.lifecycleStatus != "raw" }`
   - Falls Mock-Daten falsche `lifecycleStatus` haben ODER `isVisibleInBacklog` falsch berechnet wird

3. **`Sources/FocusBloxApp.swift:972-1010`** — Mock-Daten-Initialisierung
   - Recurring-Children werden mit `dueDate = Date()`, `dueDate = Date() - 7 Tage`, etc.
   - Prüfe: Werden die `dueDate`-Berechnungen korrekt durchgeführt?
   - Prüfe: Wird `isTemplate = false` korrekt gesetzt? (scheint ja, nur Templates werden gelöscht)

## Plattform-Status

- **iOS:** Bug bestätigt (Screenshot zeigt 0 Recurring-Sections)
- **macOS:** Noch nicht prüft  
- **Mock-Daten:** Alle 6 Instanzen sind mit korrekten Parametern eingefügt

## Nächste Schritte

1. **Unit-Test schreiben**, der prüft:
   - Werden alle 6 Mock-Recurring-Children von `LocalTaskSource.fetchIncompleteTasks()` zurückgegeben?
   - Falls nein: Welcher Filter blockt sie? (`isVisibleInBacklog`? `lifecycleStatus`?)
   - Falls ja: Landen sie in `BacklogView.planItems` bevor `applyRecurringStacking()` läuft?

2. **Print-Debugging** in `loadTasks()` und `fetchIncompleteTasks()` um Datenverlust zu lokalisieren

3. **Nach Diagnose:** Gezielte Fix in der Filter-Pipeline implementieren (nicht in `applyRecurringStacking()`)

## Änderungen dieses Reports

- **Code-Dateien:** Nur gelesen, keine Änderungen
- **Test-Dateien:** Nur gelesen
- **Artefakte:** Dieser Report
