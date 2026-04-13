# Context: FEATURE_215 — Proaktive Nudges

## Request Summary
Slice 3 der Backlog-Hygiene: Proaktive Benachrichtigungen wenn Tasks zu lange im Backlog liegen, plus Badge/Hinweis am Backlog-Tab.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/BacklogHealthService.swift` | Erkennt stale Tasks (Age ≥14d, Reschedule ≥3x) — liefert die Daten für Nudges |
| `Sources/Views/BacklogHygieneView.swift` | Aufräum-UI — Ziel-View auf die der Nudge hinführen soll |
| `Sources/Services/SmartNotificationEngine.swift` | Orchestrator mit Reconcile-Strategie, NotificationProfile (quiet/balanced/active), Budget-System |
| `Sources/Services/NotificationService.swift` | Scheduling für Task/FocusBlock Notifications, Badge-Count via `countOverdueBadgeTasks()` |
| `Sources/Services/NotificationContentService.swift` | AI-Content-Generierung via FoundationModels |
| `Sources/Views/MainTabView.swift` | TabBar (Classic + Coach Layout) — hier muss Badge-Hinweis hin |
| `Sources/Models/AppSettings.swift` | `backlogStaleAgeDays`, `backlogStaleRescheduleCount` — Schwellenwerte |

## Existing Patterns
- **Notification-Scheduling**: SmartNotificationEngine reconciled bei Events, NotificationService plant einzelne Notifications
- **NotificationProfile**: quiet/balanced/active steuert welche Notifications aktiv sind — Nudges müssen sich einordnen
- **Badge**: `countOverdueBadgeTasks()` setzt App-Icon-Badge für überfällige Tasks — ähnliches Pattern für Tab-Badge nutzbar
- **Stale-Erkennung**: BacklogHealthService hat die Logik bereits, muss nur abgefragt werden

## Dependencies
- **Upstream**: BacklogHealthService (stale Tasks), SmartNotificationEngine (Scheduling), NotificationProfile (Gating)
- **Downstream**: BacklogHygieneView (Deep-Link-Ziel), MainTabView (Badge-Anzeige)

## Existing Specs
- Keine dedizierte Spec für Backlog-Hygiene-Notifications vorhanden
- Parent-Issue #185 definiert Gesamt-Acceptance-Criteria

## Existing Specs (Draft)
- `docs/specs/features/smart-nudges.md` — Nudge-Budgets, "Stille bei Erfolg", Zeitfenster
- `docs/specs/features/itb-g-proactive-suggestions.md` — System-Integration (Spotlight, Widgets)

## Risks & Considerations
- **Budget**: SmartNotificationEngine hat Budget-Limits (64 total) — Hygiene-Nudges brauchen eigenes Budget-Slot
- **Frequenz**: Wöchentlicher Check darf nicht nerven — NotificationProfile muss respektiert werden
- **Tab-Badge**: Kein bestehendes Tab-Badge-System — muss neu implementiert werden
- **Deep-Link**: Notification-Tap soll zur HygieneView führen — Navigations-Logik nötig
- **macOS-Parität**: Badge muss auch in macOS-Sidebar funktionieren, `.badge()` auf macOS TabView ggf. anders

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/SmartNotificationEngine.swift` | MODIFY | `buildBacklogHygieneRequest()` + Budget + Integration in `buildAllRequests()` |
| `Sources/Services/NotificationActionDelegate.swift` | MODIFY | Deep-Link Branch für `target == "backlog"` |
| `Sources/FocusBloxApp.swift` | MODIFY | `.onReceive` Handler → Tab wechseln + Sheet öffnen |
| `Sources/Views/MainTabView.swift` | MODIFY | `.badge(staleCount)` + Fetch-Logik |
| `Sources/Models/AppSettings.swift` | MODIFY | `backlogHygieneNudgeEnabled` Property |

### Scope Assessment
- Files: 5 (+ 1 Test-Datei)
- Estimated LoC: ~+175
- Risk Level: LOW

### Technical Approach
1. `AppSettings` — neues Flag `backlogHygieneNudgeEnabled` (Default: true)
2. `SmartNotificationEngine` — `buildBacklogHygieneRequest()` mit wöchentlichem Trigger (Mo 09:00), Gating via NotificationProfile (.balanced/.active), 1 Budget-Slot
3. `NotificationActionDelegate` — Branch für `target == "backlog"`, postet `Notification.Name("NavigateToBacklogHygiene")`
4. `FocusBloxApp` — `.onReceive` → `selectedTab = .backlog`, BacklogView öffnet HygieneSheet
5. `MainTabView` — `.badge(staleCount)` auf Backlog-Tab, macOS via Overlay-Badge

### Dependencies
- Upstream: BacklogHealthService, SmartNotificationEngine, NotificationProfile, AppSettings
- Downstream: BacklogHygieneView (Deep-Link-Ziel), MainTabView (Badge)

### Open Questions
- Keine — alle Bausteine existieren bereits
