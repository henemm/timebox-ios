# Context: RW_0.1 — Smart Notification Engine

## Request Summary

Zentraler `SmartNotificationEngine`-Service, der alle Notifications der App verwaltet, das 64-Slot iOS-Limit respektiert, und bei jedem relevanten Event die gesamte Queue neu berechnet ("Reconcile on Event"). Drei Nutzer-Profile (Leise/Ausgeglichen/Aktiv) steuern Umfang.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Services/NotificationService.swift` | **WIRD ERSETZT/REFACTORED** — aktueller Notification-Service (432 LoC). Stateless enum mit einzelnen schedule/cancel-Methoden. Keine zentrale Queue-Verwaltung, kein Budget. |
| `Sources/Services/NotificationActionDelegate.swift` | **BLEIBT** — Handles interactive actions (NextUp, Postpone, Complete). Muss nach Reconciliation triggern statt einzelne Notifications zu reschedulen. |
| `Sources/Models/AppSettings.swift` | **ERWEITERN** — Braucht neues `notificationProfile` Setting (Leise/Ausgeglichen/Aktiv). Aktuell nur einzelne dueDateMorning/Advance Toggles. |
| `Sources/Views/SettingsView.swift` | **ERWEITERN** — Notification-Profil-Auswahl UI. Ersetzt bisherige Einzel-Toggles (Morning/Advance). |
| `Sources/FocusBloxApp.swift` | **ANPASSEN** — `rescheduleDueDateNotifications()` (Zeile 369-380) wird durch `SmartNotificationEngine.reconcile()` ersetzt. scenePhase-Handler (Zeile 314-326) wird Reconciliation-Trigger. |
| `Sources/Services/FocusBlockActionService.swift` | **TRIGGER HINZUFUEGEN** — Bei Block-Start/Ende Reconciliation triggern. |
| `Sources/Views/FocusLiveView.swift` | **VEREINFACHEN** — Aktuell 8 direkte NotificationService-Aufrufe (schedule/cancel). Werden durch Engine-Reconciliation ersetzt. |
| `Sources/Views/BlockPlanningView.swift` | **VEREINFACHEN** — 6 direkte NotificationService-Aufrufe fuer FocusBlock-Notifications. |
| `Sources/Views/BacklogView.swift` | **VEREINFACHEN** — 4 direkte NotificationService-Aufrufe bei Task-Aenderungen. |
| `Sources/Views/TaskFormSheet.swift` | **VEREINFACHEN** — 1 NotificationService-Aufruf bei Due-Date-Aenderung. |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | **VEREINFACHEN** — 1 NotificationService-Aufruf bei Task-Erstellung. |
| `Sources/Views/TaskAssignmentView.swift` | **VEREINFACHEN** — 2 NotificationService-Aufrufe bei Block-Zuweisung. |
| `FocusBloxMac/ContentView.swift` | **ANPASSEN** — 2 NotificationService-Aufrufe. |

## Existing Patterns

### Aktueller Notification-Ansatz
- **Dezentral:** Jede View/Service ruft `NotificationService.schedule...()` und `NotificationService.cancel...()` direkt auf
- **Kein Budget-Management:** Keine Kontrolle ueber Gesamtzahl pending Notifications
- **Batch-Reschedule nur fuer DueDate:** `rescheduleAllDueDateNotifications()` begrenzt auf 25 Tasks, wird bei App-Foreground aufgerufen
- **Identifier-Prefixes:** `task-timer-`, `focus-block-start-`, `focus-block-end-`, `due-date-morning-`, `due-date-advance-`

### Settings-Pattern
- `AppSettings` ist ein `@MainActor ObservableObject` Singleton mit `@AppStorage`-Properties
- Settings werden in `SettingsView.swift` per Binding angezeigt
- `SyncedSettings` synchronisiert ausgewaehlte Settings via iCloud KV Store

### Service-Pattern (laut Epic Overview)
- Services sind First-Class, keine ViewModels
- Stateless enums (wie `NotificationService`, `FocusBlockActionService`) bevorzugt

## Dependencies

### Upstream (was SmartNotificationEngine braucht)
- `SwiftData ModelContext` — Tasks mit dueDate, scheduledDate, isNextUp, isCompleted lesen
- `EventKitRepository` — FocusBlocks fuer heute/morgen lesen (Timer-Notifications)
- `AppSettings` — Notification-Profil lesen
- `UNUserNotificationCenter` — Notifications planen/entfernen

### Downstream (was SmartNotificationEngine konsumiert)
- `FocusBloxApp` — Reconciliation bei App-Start/Foreground/Background
- `NotificationActionDelegate` — Reconciliation nach Action-Handling
- `FocusBlockActionService` — Reconciliation bei Block-Start/Ende
- Views (Backlog, TaskForm, etc.) — KEINE direkten Notification-Aufrufe mehr, nur noch Reconciliation-Trigger

## Existing Specs

- `docs/specs/rework/0.1-smart-notification-engine.md` — Haupt-Spec (Akzeptanzkriterien, Budget, Profile)
- `docs/specs/rework/0.0-epic-overview.md` — Architektur-Kontext (D8: Notification-Strategie)
- `docs/specs/features/badge-overdue-notifications.md` — Badge-Logik (bleibt)
- `docs/specs/features/due-date-notifications.md` — DueDate-Notifications (wird in Engine integriert)

## Risks & Considerations

1. **Blast Radius:** 13+ Dateien referenzieren NotificationService direkt. Umstellung auf zentrale Reconciliation beruehrt viele Views. Muss in Phasen geschehen, nicht alles gleichzeitig.
2. **LoC-Limit:** Spec sagt max 4-5 Dateien, ±250 LoC. Die vollstaendige Migration aller Views uebersteigt das.
3. **Reconciliation-Performance:** Muss < 100ms sein. SwiftData-Fetch + EventKit-Fetch + 64 Notification-Requests koennte knapp werden. Async berechnen.
4. **BGAppRefreshTask:** Aktuell nicht implementiert. Spec verlangt Best-Effort-Registrierung. Nur iOS (nicht macOS).
5. **Abwaertskompatibilitaet:** Bestehende Notification-Actions (NextUp, Postpone, Complete) muessen weiterhin funktionieren. `NotificationActionDelegate` bleibt unveraendert.
6. **macOS:** Notification-Handling auf macOS ist eingeschraenkt (kein Badge, kein BGAppRefreshTask). Engine muss `#if !os(macOS)` Guards nutzen.
7. **Bestehende Settings:** `dueDateMorningReminderEnabled/Hour/Minute` und `dueDateAdvanceReminderEnabled/Minutes` bleiben bestehen — werden innerhalb des Profils "Ausgeglichen" weiterverwendet.

---

## Analysis

### Type
Feature (Infrastruktur-Rework)

### Strategie: Additive Wrapper in 3 Phasen

`NotificationService` wird NICHT ersetzt, sondern `SmartNotificationEngine` als orchestrierender Layer darueber gebaut. Die bestehenden `build*Request`-Methoden werden intern weiterverwendet. Das bewahrt alle bestehenden Tests und vermeidet Big-Bang-Migration.

### Phase A: Foundation (Engine Core) — DIESES TICKET

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/SmartNotificationEngine.swift` | CREATE | Engine-Skeleton: Reconcile-Methode, Budget-Enum, Profil-Logik, BGAppRefreshTask |
| `Sources/Models/AppSettings.swift` | MODIFY | + `NotificationProfile` Enum + `@AppStorage("notificationProfile")` |
| `Sources/FocusBloxApp.swift` | MODIFY | scenePhase-Handler ruft `SmartNotificationEngine.reconcile()` statt `rescheduleDueDateNotifications()` |

**Scope:** 3 Files, ~195 LoC
**Risk:** LOW — Additive Aenderung, bestehende Tests bleiben gruen

### Phase B: FocusBlock-Flow Migration (separates Ticket)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/FocusLiveView.swift` | MODIFY | 7 direkte Calls → Engine-Trigger |
| `Sources/Views/BlockPlanningView.swift` | MODIFY | 5 Calls → Engine-Trigger |
| `Sources/Views/TaskAssignmentView.swift` | MODIFY | 3 Calls → Engine-Trigger |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | 3 Calls → Engine-Trigger |

**Scope:** 4 Files, ~85 LoC delta

### Phase C: DueDate-Flow + Settings UI (separates Ticket)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/BacklogView.swift` | MODIFY | 5 Calls → Engine |
| `Sources/Views/TaskFormSheet.swift` | MODIFY | 1 Call → Engine |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | MODIFY | 1 Call → Engine |
| `FocusBloxMac/ContentView.swift` | MODIFY | 2 Calls → Engine |
| `Sources/Views/SettingsView.swift` | MODIFY | Profil-Picker UI |

**Scope:** 5 Files, ~75 LoC delta

### Scope Assessment (Phase A — dieses Ticket)
- Files: 3
- Estimated LoC: +195
- Risk Level: LOW

### Dependencies
- **Upstream:** SwiftData ModelContext, EventKitRepository (FocusBlocks lesen), AppSettings, UNUserNotificationCenter
- **Downstream:** FocusBloxApp (Trigger), spaeter Views (Phase B+C)
- **Keine zirkulaeren Dependencies** im bestehenden Code

### Abhaengigkeiten zwischen Phasen
- Phase A muss zuerst (Engine existieren)
- Phase B + C sind unabhaengig voneinander, aber sequenziell wegen LoC-Limit
- `NotificationActionDelegate` bleibt in ALLEN Phasen unveraendert
- `NotificationService.swift` bleibt erhalten — Engine nutzt `build*Request`-Methoden intern

### Open Questions
- Keine — Spec ist vollstaendig, Strategie klar
