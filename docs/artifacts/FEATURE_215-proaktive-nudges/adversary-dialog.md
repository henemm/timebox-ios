# Adversary Dialog: FEATURE_215 — Proaktive Nudges

## Checkliste

- [x] AC1: Wöchentliche Notification (Mo 09:00, einladend, staleCount > 0, Profile-Gating, Budget)
- [x] AC2: Tab-Badge (stale count, beide Layouts, macOS Sidebar)
- [x] AC3: Deep-Link (Tap → Backlog-Tab → HygieneSheet)
- [x] AC4: Konfiguration (backlogHygieneNudgeEnabled Flag)
- [x] AC5: "Behalten"-Logik (hygieneReviewedAt, 30-Tage-Filter)

### Runde 1: Adversary findet 2 Defekte + 1 Unbewiesenes

**Adversary-Befunde:**
1. DEFEKT: Deep-Link-Navigation (NotificationActionDelegate, FocusBloxApp, BacklogView) fehlte komplett
2. DEFEKT: macOS Sidebar-Badge fehlte (SidebarView + ContentView)
3. UNBEWIESEN: Unit Test für `disabledFlag`-Szenario fehlte

**Implementierer-Aktion:**
- Fix 1: `NotificationActionDelegate` — neuer Branch für `target == "backlog"` + neue Notification.Name
- Fix 2: `FocusBloxApp` — `.onReceive` navigiert zu Backlog-Tab
- Fix 3: `BacklogView` — `.onReceive` öffnet HygieneSheet
- Fix 4: `SidebarView` — staleTaskCount-Badge (orange) in Sidebar
- Fix 5: `ContentView` — berechnet staleTaskCount und übergibt an SidebarView

### Runde 2: Verifikation nach Fixes

**Beweise:**
- iOS Build: erfolgreich
- macOS Build: erfolgreich
- Unit Tests: 7/7 PASSED (BacklogHygieneNudgeTests)
- Regression: 10/10 PASSED (BacklogHealthServiceTests)
- UI Tests: 3/3 PASSED (BacklogHygieneNudgeUITests)
- Screenshot: /tmp/adversary_screenshot.png

**Code-Pfade verifiziert:**
- NotificationActionDelegate.swift:23 — `navigateToBacklogHygieneNotification` Notification.Name
- NotificationActionDelegate.swift:32-39 — Branch für `target == "backlog"`
- FocusBloxApp.swift:468-470 — `.onReceive` navigiert zu `.backlog`
- BacklogView.swift:280-282 — `.onReceive` öffnet HygieneSheet
- SidebarView.swift:55-66 — staleTaskCount Badge (orange)
- ContentView.swift:162-165 — staleTaskCount Berechnung

## Verdict

**VERIFIED** — Alle 5 Acceptance Criteria bewiesen. 2 Defekte gefunden und gefixt.
