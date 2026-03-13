# Bug-Analyse: Enrichment funktioniert nicht in der Praxis

## Zusammenfassung der Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- Enrichment-Code (recurrencePattern Mapping, Enrichment-Logik) existiert in Working Changes
- Code ist **NICHT COMMITTED** — nur in `git diff HEAD`
- Commit `c0029e9` enthielt nur markedComplete/markCompleteFailures
- 26 Tests passen, aber Tests laufen gegen Working Changes, nicht gegen committed Code

### Agent 2: Datenfluss-Trace
- EKReminder.recurrenceRules → ReminderData.mapRecurrenceRules() → importAll() enrichment → LocalTask.recurrencePattern
- Jeder Schritt ist korrekt implementiert
- mapRecurrenceRules() deckt daily, weekly, biweekly, monthly ab
- EventKit SOLLTE recurrenceRules populieren bei fetchIncompleteReminders

### Agent 3: Enrichment-Logik-Analyse
- Bedingung: `existing.recurrencePattern == "none" && reminder.recurrencePattern != "none"`
- Logik ist korrekt, Tests beweisen es
- Aber: **Kein Logging im Enrichment-Pfad** — wir koennen nicht sehen ob es laeuft

### Agent 4: macOS Import-Pfad
- macOS ContentView nutzt den GLEICHEN RemindersImportService aus Sources/
- Selber Code-Pfad wie iOS
- Kein separater macOS-Import-Service

### Agent 5: Feedback-Message
- `enrichedRecurrence` wird NIRGENDS angezeigt
- iOS BacklogView: nur imported, skippedDuplicates, markCompleteFailures
- macOS ContentView: identisch — kein enrichedRecurrence
- Logger-Zeile (ContentView:628): auch OHNE enrichedRecurrence

## Hypothesen

### Hypothese 1: App laeuft mit altem Build (HOHE Wahrscheinlichkeit)
- **Beweis DAFUER:**
  - `git diff HEAD` zeigt: GESAMTER Enrichment-Code ist uncommitted
  - Commit c0029e9 hat nur markedComplete/markCompleteFailures
  - Wenn macOS-App von altem Build laeuft → kein Enrichment-Code vorhanden
  - Console-Output zeigt markedComplete (committed) aber nicht enrichedRecurrence (uncommitted)
- **Beweis DAGEGEN:**
  - Xcode baut aus Working Directory → sollte uncommitted Changes inkludieren
  - Aber: Nur wenn User explizit Cmd+R in Xcode drueckt (nicht alte Binary startet)
- **Wahrscheinlichkeit: HOCH**

### Hypothese 2: EKReminder.recurrenceRules ist nil (MITTLERE Wahrscheinlichkeit)
- **Beweis DAFUER:**
  - Kein Debug-Logging → wir wissen nicht was EKReminder zurueckgibt
  - Apple-API kann subtile Eigenheiten haben
  - "Alle 3 Tage" und "Alle 4 Wochen" sind non-standard Intervalle
- **Beweis DAGEGEN:**
  - Apple-Dokumentation sagt recurrenceRules wird populiert
  - fetchIncompleteReminders gibt vollstaendige EKReminder-Objekte zurueck
  - Unit Tests mit echten EKRecurrenceRule-Objekten beweisen Mapping-Korrektheit
- **Wahrscheinlichkeit: MITTEL** (nicht testbar ohne echtes Device/Logging)

### Hypothese 3: Title-Mismatch (NIEDRIGE Wahrscheinlichkeit)
- **Beweis DAFUER:**
  - Exact String Match (case-sensitive, whitespace-sensitive)
  - Apple Reminders koennte unsichtbare Zeichen/Whitespace haben
- **Beweis DAGEGEN:**
  - "4 skipped" zeigt: Titel-Matching FUNKTIONIERT fuer alle 4 Reminders
  - Wenn Titles nicht matchen, waeren Reminders als NEU importiert worden
- **Wahrscheinlichkeit: NIEDRIG** (widerlegt durch "4 skipped")

## Wahrscheinlichste Ursache

**Hypothese 1 + fehlende Sichtbarkeit:** Die macOS-App laeuft moeglicherweise
mit einem alten Build OHNE den uncommitted Enrichment-Code. ABER selbst wenn der
Code laeuft, koennen wir es nicht verifizieren weil:
1. enrichedRecurrence NICHT im Logger-Output erscheint
2. enrichedRecurrence NICHT in der Feedback-Message steht

## Empfohlenes Vorgehen

1. **Debug-Logging hinzufuegen** in der Enrichment-Schleife
2. **Enrichment-Count in Feedback-Message einbauen** (beide Plattformen)
3. **App explizit neu bauen** (Clean Build) und testen
4. **Erst dann**: Falls enrichedRecurrence immer noch 0, nach EKReminder.recurrenceRules debuggen

## Blast Radius
- Kein Risiko fuer andere Features — Enrichment aendert nur recurrencePattern
- isVisibleInBacklog ist eine computed property, kein persistierter Wert
- Wenn Enrichment funktioniert, werden Tasks sofort korrekt gefiltert
