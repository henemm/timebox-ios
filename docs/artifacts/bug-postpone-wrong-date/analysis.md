# Bug-Analyse: "Verschieben auf morgen" nimmt falsches Ursprungsdatum

## Symptom
"Verschieben auf morgen" im Kontextmenu rechnet ab dem Original-Faelligkeitsdatum statt ab heute. Eine Task die vor 5 Tagen faellig war wird auf "4 Tage ueberfaellig" statt auf "morgen" verschoben.

## Betroffene Plattformen
iOS + macOS + watchOS (alle drei)

## Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- Feature wurde GESTERN (2026-03-09) in Bug 85-C (Commit `7223da8`) implementiert
- Kein vorheriger Bug zu diesem Thema — es ist ein Implementierungsfehler ab Tag 1
- Tests existieren, aber testen NUR mit Tasks die HEUTE faellig sind (Bug wird nicht exponiert)

### Agent 2: Datenfluss-Trace
- iOS: BacklogView.postponeMenu() → BacklogView.postponeTask() → LocalTask.postpone()
- macOS: ContentView context menu → ContentView.postponeTask() → LocalTask.postpone()
- Notifications: NotificationActionDelegate → LocalTask.postpone()
- Watch: WatchNotificationDelegate → INLINE Code (gleicher Bug, andere Stelle)
- Root Cause: LocalTask.swift Zeile 183 rechnet `currentDue + days` statt `Date() + days`

### Agent 3: Alle Schreiber
- 22 dueDate-Schreibstellen gefunden
- Relevante: LocalTask.postpone() (Zeile 184) + WatchNotificationDelegate (Zeilen 92, 97)
- Alle anderen Schreibstellen (SyncEngine, TaskInspector, RecurrenceService) sind korrekt

### Agent 4: Szenarien
- **Ueberfaellige Tasks:** KRITISCH — bleibt ueberfaellig (Hauptbug)
- **Heute faellige Tasks:** Korrekt per Zufall (currentDue == heute)
- **Zukuenftige Tasks:** FALSCH — verschiebt auf zu spaetes Datum
- **Recurring Instances:** Gleicher Bug
- **"Naechste Woche" (+7 Tage):** Gleicher Bug, andere Distanz

### Agent 5: Blast Radius
- iOS + macOS nutzen shared LocalTask.postpone() — 1 Fix reicht fuer beide
- watchOS hat EIGENE inline-Implementation (gleicher Bug, separater Fix noetig)
- Keine Keyboard-Shortcuts, kein Batch-Postpone
- watchOS-Code trackt KEIN rescheduleCount (Divergenz)

## Hypothesen

### Hypothese 1: LocalTask.postpone() rechnet ab currentDue statt ab Date() (HOCH)
- **Beweis DAFUER:** Zeile 183: `Calendar.current.date(byAdding: .day, value: days, to: currentDue)` — `currentDue` ist das gespeicherte Faelligkeitsdatum, nicht heute
- **Beweis DAGEGEN:** Keiner. Code ist eindeutig.
- **Wahrscheinlichkeit:** HOCH (100%)

### Hypothese 2: WatchNotificationDelegate hat identischen Bug inline (HOCH)
- **Beweis DAFUER:** Zeile 92: `Calendar.current.date(byAdding: .day, value: 1, to: currentDue)` — gleiche Logik
- **Beweis DAGEGEN:** Keiner. Identisches Pattern.
- **Wahrscheinlichkeit:** HOCH (100%)

### Hypothese 3: Tests decken den Bug nicht auf weil sie nur "heute" testen (HOCH)
- **Beweis DAFUER:** TaskPostponeTests erstellt Tasks mit `dueDate: today` — dann ist currentDue == Date(), daher kein Unterschied
- **Beweis DAGEGEN:** Keiner.
- **Wahrscheinlichkeit:** HOCH (100%)

## Wahrscheinlichste Ursache

**Hypothese 1 + 2:** Der `postpone`-Code addiert Tage zum Original-Datum statt zum heutigen Datum. An 2 Stellen:
1. `Sources/Models/LocalTask.swift:183` (shared, iOS + macOS + Notifications)
2. `FocusBloxWatch Watch App/WatchNotificationDelegate.swift:92,97` (Watch inline)

**Warum die anderen weniger wahrscheinlich:** Es gibt keine andere Hypothese — der Code ist eindeutig.

## Debugging-Plan

Eigentlich kein Debugging noetig — der Code ist trivial und die Ursache offensichtlich:
- Zeile 183 tut `currentDue + days` statt `Date() + days`
- Ein Unit Test mit ueberfaelligem Datum wird das sofort beweisen

## Blast Radius

### Direkt betroffen (Fix noetig):
1. `LocalTask.postpone()` — shared (iOS + macOS + Notification Actions)
2. `WatchNotificationDelegate` — inline (Watch)

### Indirekt betroffen (Tests anpassen):
3. `TaskPostponeTests` — brauchen Overdue-Testcases
4. `NotificationSnoozeTests` — brauchen Overdue-Testcases

### NICHT betroffen:
- RecurrenceService (nutzt eigene Datumslogik)
- EventKitRepository (unabhaengig)
- SyncEngine (setzt Daten, verschiebt nicht)

## Fix-Vorschlag

**Zeile 183 aendern von:**
```swift
let newDue = Calendar.current.date(byAdding: .day, value: days, to: currentDue)!
```

**Zu:**
```swift
let today = Calendar.current.startOfDay(for: Date())
let newDue = Calendar.current.date(byAdding: .day, value: days, to: today)!
```

**Watch analog (Zeilen 92 + 97):**
```swift
task.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
```

**Semantik-Entscheidung:** "Morgen" = morgen ab heute, NICHT morgen ab Faelligkeitsdatum.
"Naechste Woche" = 7 Tage ab heute, NICHT 7 Tage ab Faelligkeitsdatum.

**Dateien die geaendert werden:**
1. `Sources/Models/LocalTask.swift` (1 Zeile)
2. `FocusBloxWatch Watch App/WatchNotificationDelegate.swift` (2 Zeilen)
3. `FocusBloxTests/TaskPostponeTests.swift` (neue Overdue-Tests)
