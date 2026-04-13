---
entity_id: feature_215_hygiene_nudges
type: feature
created: 2026-04-13
updated: 2026-04-13
status: draft
version: "1.0"
tags: [backlog-hygiene, notifications, nudges]
---

# FEATURE_215: Proaktive Backlog-Hygiene Nudges

## Approval

- [ ] Approved

## Purpose

Proaktive Benachrichtigungen und Tab-Badge, die den User einladen seinen Backlog aufzuräumen, wenn Tasks zu lange liegen oder zu oft verschoben wurden. Teil 3 der Backlog-Hygiene-Reihe (#185).

## Source

- **Files:**
  - `Sources/Services/SmartNotificationEngine.swift` — Notification-Scheduling
  - `Sources/Services/NotificationActionDelegate.swift` — Deep-Link-Handling
  - `Sources/FocusBloxApp.swift` — Navigation-Handler
  - `Sources/Views/MainTabView.swift` — Tab-Badge
  - `Sources/Models/AppSettings.swift` — Konfiguration

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| BacklogHealthService | Service | Liefert stale Tasks (≥14d alt oder ≥3x verschoben) |
| SmartNotificationEngine | Service | Orchestriert Notifications mit Budget + Profile-Gating |
| NotificationProfile | Enum | quiet/balanced/active — steuert welche Nudges aktiv sind |
| BacklogHygieneView | View | Ziel-View für Deep-Link (Aufräum-UI aus #213) |
| AppSettings | Model | Schwellenwerte + neues Enable-Flag |

## Acceptance Criteria

### AC1: Wöchentliche Notification
- [ ] Montags um 09:00 wird eine lokale Notification geplant, wenn stale Tasks existieren
- [ ] Notification-Text ist einladend formuliert: "X Tasks warten auf eine Entscheidung"
- [ ] Notification wird NUR geplant wenn `staleCount > 0`
- [ ] Gating: nur bei NotificationProfile `.balanced` oder `.active`
- [ ] Budget: 1 Slot aus dem Review-Budget (max 14)

### AC2: Tab-Badge
- [ ] Backlog-Tab zeigt Badge mit Anzahl stale Tasks
- [ ] Badge verschwindet wenn keine stale Tasks mehr vorhanden
- [ ] Tasks die über "Behalten" in der HygieneView bestätigt wurden, zählen NICHT als stale (reviewedAt-Timestamp)
- [ ] Badge funktioniert in beiden Tab-Layouts (Classic + Coach)
- [ ] macOS: Badge in Sidebar via Overlay

### AC3: Deep-Link
- [ ] Tap auf Notification öffnet die App und navigiert zum Backlog-Tab
- [ ] BacklogHygieneView wird automatisch als Sheet geöffnet
- [ ] Wenn keine stale Tasks mehr vorhanden: leerer Zustand wird angezeigt (bereits implementiert)

### AC4: Konfiguration
- [ ] Neues Flag `backlogHygieneNudgeEnabled` in AppSettings (Default: true)
- [ ] NotificationProfile steuert ob Nudge aktiv ist (quiet = aus, balanced/active = an)

### AC5: "Behalten"-Logik (User-Advocate Insight)
- [ ] Tasks die in der HygieneView mit "Behalten" bestätigt wurden, bekommen einen `reviewedAt`-Timestamp
- [ ] BacklogHealthService filtert Tasks mit `reviewedAt` innerhalb der letzten 30 Tage aus der Stale-Liste
- [ ] Erst nach 30 Tagen ohne erneute Review tauchen behaltene Tasks wieder auf

## Implementation Details

### 1. AppSettings (MODIFY)
```swift
@AppStorage("backlogHygieneNudgeEnabled") var backlogHygieneNudgeEnabled: Bool = true
```

### 2. SmartNotificationEngine (MODIFY)
```swift
func buildBacklogHygieneRequest(staleTasks: [FocusTask]) -> [UNNotificationRequest] {
    guard settings.backlogHygieneNudgeEnabled else { return [] }
    guard settings.notificationProfile != .quiet else { return [] }
    guard !staleTasks.isEmpty else { return [] }

    // Wöchentlich Montag 09:00
    var dateComponents = DateComponents()
    dateComponents.weekday = 2  // Montag
    dateComponents.hour = 9
    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

    let content = UNMutableNotificationContent()
    content.title = "Backlog aufräumen?"
    content.body = "\(staleTasks.count) Tasks warten auf eine Entscheidung"
    content.userInfo = ["target": "backlog", "action": "hygiene"]

    return [UNNotificationRequest(
        identifier: "focusblox.backlog-hygiene",
        content: content,
        trigger: trigger
    )]
}
```
Integration in `buildAllRequests()` — Ergebnis wird dem Review-Budget zugerechnet.

### 3. NotificationActionDelegate (MODIFY)
```swift
// Neuer Branch in didReceive(_:withCompletionHandler:)
case "backlog":
    NotificationCenter.default.post(name: .navigateToBacklogHygiene, object: nil)
```

### 4. FocusBloxApp (MODIFY)
```swift
.onReceive(NotificationCenter.default.publisher(for: .navigateToBacklogHygiene)) { _ in
    selectedTab = .backlog
    showBacklogHygiene = true
}
```

### 5. MainTabView (MODIFY)
```swift
// Backlog-Tab mit Badge
BacklogView()
    .tabItem { Label("Backlog", systemImage: "tray") }
    .badge(staleTaskCount)
```
`staleTaskCount` via `BacklogHealthService.findStaleTasks()` bei `.onAppear` / `.onChange`.

### 6. BacklogHealthService (MODIFY — minor)
`findStaleTasks()` muss Tasks mit `reviewedAt` innerhalb der letzten 30 Tage ausfiltern.

## Expected Behavior

- **Input:** BacklogHealthService liefert stale Tasks basierend auf bestehenden Schwellenwerten
- **Output:** Wöchentliche Notification + Tab-Badge mit Count
- **Side effects:** Deep-Link-Navigation zur HygieneView bei Notification-Tap

## Known Limitations

- Notification wird nur 1x/Woche geplant — keine Echtzeit-Updates
- Badge-Count aktualisiert sich erst bei Tab-Wechsel / App-Start (nicht live)
- macOS: Tab-Badge via Overlay statt nativem `.badge()` (TabView-Limitation)

## Test Plan

### Unit Tests
1. `testBuildBacklogHygieneRequest_withStaleTasks` — Request wird erstellt mit korrektem Content
2. `testBuildBacklogHygieneRequest_noStaleTasks` — Leere Liste → kein Request
3. `testBuildBacklogHygieneRequest_quietProfile` — Quiet-Profil → kein Request
4. `testBuildBacklogHygieneRequest_disabledFlag` — Flag aus → kein Request
5. `testStaleTasksExcludesRecentlyReviewed` — Tasks mit reviewedAt <30d werden gefiltert

### UI Tests
1. `testBacklogTabShowsBadgeWithStaleCount` — Badge am Tab zeigt korrekte Zahl
2. `testBacklogTabBadgeDisappearsAfterCleanup` — Badge verschwindet nach Aufräumen
3. `testDeepLinkOpensHygieneView` — Navigation zur HygieneView funktioniert

## Scope

- **Files:** 6 (5 MODIFY + 1 CREATE für Tests)
- **Estimated LoC:** ~+175
- **Risk:** LOW

## Changelog

- 2026-04-13: Initial spec created
