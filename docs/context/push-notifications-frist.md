# Context: Push Notifications bei ablaufender Frist

## Request Summary
Tasks mit Due Date sollen konfigurierbare Push-Erinnerungen erhalten:
1. **Morgen-Erinnerung** am Faelligkeitstag (optional, Uhrzeit konfigurierbar)
2. **Vorab-Erinnerung** XX Minuten/Stunden vor Frist (optional)
Beide unabhaengig ein/ausschaltbar, auf iOS + macOS.

## Analysis

### Type
Feature

### Wichtige Erkenntnis: dueDate hat Uhrzeit
`dueDate` wird mit `displayedComponents: [.date, .hourAndMinute]` erfasst — es ist ein
vollstaendiger Zeitpunkt (Date + Time). Damit macht "XX Stunden vor Frist" Sinn.

### Technischer Ansatz: Hybrid-Scheduling

**Strategie:** Kombination aus Einzel-Scheduling + Batch-Resync

1. **Einzel-Scheduling** bei Task-Create/Edit/Delete (sofortige Reaktion)
2. **Batch-Reschedule** bei App-Foreground (faengt CloudKit-Sync, Settings-Aenderungen,
   verpasste Aenderungen auf)

**Notification-Typen:**
- `UNCalendarNotificationTrigger` fuer Morgen-Erinnerung (feste Uhrzeit am Tag)
- `UNTimeIntervalNotificationTrigger` fuer Vorab-Erinnerung (relativ zum dueDate)

**64-Notification-Limit:**
- 2 Notifications pro Task = max 32 Tasks abdeckbar
- Strategie: Nach dueDate sortieren (naechste zuerst), max 30 Tasks schedulen
- Batch-Reschedule prueft automatisch

### Code-Sharing Analyse

**Komplett Shared (Sources/):**
- NotificationService.swift — alle Scheduling-Methoden
- AppSettings.swift — alle Settings-Keys
- Scheduling-Logik — identisch auf beiden Plattformen

**Plattform-spezifisch (nur UI):**
- SettingsView.swift (iOS) — neue Section "Frist-Erinnerungen"
- MacSettingsView.swift (macOS) — neue Section im "Mitteilungen"-Tab
- FocusBloxApp.swift (iOS) — Batch-Reschedule bei Foreground
- FocusBloxMacApp.swift (macOS) — Permission + Batch-Reschedule bei Foreground

**Ergebnis:** ~80% Shared Code, nur Settings-UI und App-Entry sind plattform-spezifisch.

### Affected Files (with changes)

| File | Change Type | LoC | Description |
|------|-------------|-----|-------------|
| `Sources/Services/NotificationService.swift` | MODIFY | ~80 | Neue Methoden: schedule/cancel/batch fuer DueDate |
| `Sources/Models/AppSettings.swift` | MODIFY | ~15 | 4 neue @AppStorage Keys |
| `Sources/Views/SettingsView.swift` | MODIFY | ~30 | Neue Section "Frist-Erinnerungen" |
| `FocusBloxMac/MacSettingsView.swift` | MODIFY | ~30 | Neue Section im Mitteilungen-Tab |
| `Sources/FocusBloxApp.swift` | MODIFY | ~15 | Batch-Reschedule bei scenePhase == .active |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | ~10 | Permission request + Batch-Reschedule |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | MODIFY | ~3 | schedule nach Task-Erstellung |
| `Sources/Views/TaskFormSheet.swift` | MODIFY | ~3 | reschedule nach dueDate-Aenderung |
| `Sources/Views/BacklogView.swift` | MODIFY | ~3 | cancel bei Task-Loeschung |
| `FocusBloxTests/DueDateNotificationTests.swift` | CREATE | ~80 | Unit Tests fuer build*Request Methoden |
| `FocusBloxUITests/DueDateNotificationUITests.swift` | CREATE | ~40 | UI Tests fuer Settings |

### Scope Assessment
- **Files:** 9 MODIFY + 2 CREATE = 11 Dateien
- **Estimated LoC:** ~190 netto (davon 120 Tests)
- **Production Code:** ~70 LoC substantiell (NotificationService + AppSettings),
  ~60 LoC Settings-UI, ~20 LoC Trigger-Aufrufe = ~150 LoC
- **Risk Level:** LOW — erweitert bestehenden Service mit bewaehrtem Pattern

### Dependencies
- **Upstream:** UNUserNotificationCenter, LocalTask.dueDate, AppSettings
- **Downstream:** CreateTaskView, TaskFormSheet, BacklogView (kleine Trigger-Aufrufe)

### Bestehendes Pattern (wiederverwendbar)
- NotificationService ID-Prefix-System (`"due-date-morning-"`, `"due-date-advance-"`)
- `build*Request()` (testbar, pure) + `schedule*()` (side effect)
- `cancel*()` zum Aufraemen
- Focus-Block-Start-Notification als direktes Vorbild

### Offene Fragen
- Keine — Feature-Scope ist klar definiert im Backlog
